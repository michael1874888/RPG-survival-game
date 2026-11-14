#!/usr/bin/env python3
"""Read selected ARM64 functions without loading or executing the target.

Requires capstone==5.0.6 and pyelftools==0.32. This is not REA Evidence.
"""
import argparse
import bisect
from collections import deque
import hashlib
import io
import json
from pathlib import Path
import re

from capstone import Cs, CS_ARCH_ARM64, CS_MODE_LITTLE_ENDIAN
from capstone.arm64 import ARM64_OP_IMM
from elftools.elf.elffile import ELFFile


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--library', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    data = args.library.read_bytes()
    elf = ELFFile(io.BytesIO(data))
    symbols = json.loads(Path(str(args.library)+'.symbols.json').read_text())['symbols']
    functions = [s for s in symbols if s['defined'] and s['type'] == 2 and s['size']]
    functions.sort(key=lambda s: int(s['address'], 16))
    direct = {int(s['address'], 16): s['demangled'] for s in functions}
    reloc = elf.get_section_by_name('.rela.plt')
    dynsym = elf.get_section(reloc['sh_link'])
    plt = elf.get_section_by_name('.plt')
    # AArch64 ABI: 32-byte PLT header followed by 16-byte entries.
    targets = dict(direct)
    for i, r in enumerate(reloc.iter_relocations()):
        name = dynsym.get_symbol(r['r_info_sym']).name
        match = next((s for s in symbols if s['name'] == name), None)
        targets[plt['sh_addr'] + 32 + 16*i] = (match or {}).get('demangled', name) + ' [PLT]'

    def read_at(address, size):
        for segment in elf.iter_segments():
            if segment['p_type'] == 'PT_LOAD' and segment['p_vaddr'] <= address < segment['p_vaddr']+segment['p_filesz']:
                offset = segment['p_offset']+address-segment['p_vaddr']
                return data[offset:offset+size], offset
        raise ValueError(f'No file-backed bytes at {address:#x}')

    names = {'String::Decrypt(char*)', 'IOBuffer::Decrypt(char*, bool)',
             'Stats::HurtMana(float)', 'Stats::Rest()',
             'Stats::Meditate()', 'Stats::GetSkillManaCost(int, int)',
             'Stats::GetSkillValue(int, int, String)', 'Stats::Update()',
             'Stats::PrimeSkill(bool)', 'Stats::UpSkill(int, bool)',
             'MagicMissile::Init()', 'MagicMissile::Update()',
             'Formations::Init()', 'Formations::Update()'}
    literals = []
    for key in [b'FORASUMMERSDAY', b'BEwareTheFisH', b'F0rk1tA3ll']:
        offset = data.find(key)
        address = None
        for seg in elf.iter_segments():
            if seg['p_type'] == 'PT_LOAD' and seg['p_offset'] <= offset < seg['p_offset']+seg['p_filesz']:
                address = seg['p_vaddr'] + offset-seg['p_offset']
                break
        literals.append({'text': key.decode(), 'file_offset': hex(offset),
                         'virtual_address': None if address is None else hex(address)})
    key_addresses = {int(x['virtual_address'], 16): x['text'] for x in literals if x['virtual_address']}
    addresses = [int(s['address'], 16) for s in functions]
    recent = deque(maxlen=10)
    literal_references = []
    scanner = Cs(CS_ARCH_ARM64, CS_MODE_LITTLE_ENDIAN)
    scanner.skipdata = True
    text = elf.get_section_by_name('.text')
    for address, size, mnemonic, operands in scanner.disasm_lite(text.data(), text['sh_addr']):
        add = re.fullmatch(r'(x\d+), (x\d+), #0x([0-9a-f]+)', operands) if mnemonic == 'add' else None
        if add:
            for prev in reversed(recent):
                page = re.fullmatch(r'(x\d+), #0x([0-9a-f]+)', prev[3]) if prev[2] == 'adrp' else None
                if page and page[1] == add[2]:
                    target = int(page[2], 16)+int(add[3], 16)
                    if target in key_addresses:
                        index = bisect.bisect_right(addresses, address)-1
                        owner = functions[index] if index >= 0 else None
                        if owner and address < int(owner['address'], 16)+owner['size']:
                            names.add(owner['demangled'])
                        else:
                            owner = None
                        literal_references.append({'key': key_addresses[target],
                            'address': hex(address), 'adrp_address': hex(prev[0]),
                            'function': None if owner is None else owner['demangled'],
                            'scope': 'static ADRP/ADD reference candidate; no target execution'})
                    break
        recent.append((address, size, mnemonic, operands))
    decoder = Cs(CS_ARCH_ARM64, CS_MODE_LITTLE_ENDIAN)
    decoder.detail = True
    decrypt_callers = []
    selected = []
    seen = set()
    for symbol in functions:
        address = int(symbol['address'], 16)
        if address in seen:
            continue
        seen.add(address)
        body, offset = read_at(address, symbol['size'])
        lines = []
        for ins in decoder.disasm(body, address):
            suffix = ''
            if ins.mnemonic in {'bl', 'b'} and ins.operands and ins.operands[0].type == ARM64_OP_IMM:
                target = ins.operands[0].imm
                suffix = ' ; ' + targets.get(target, f'{target:#x}')
                if targets.get(target, '').startswith('String::Decrypt('):
                    decrypt_callers.append({'caller': symbol['demangled'], 'caller_address': symbol['address'],
                                            'call_address': hex(ins.address), 'target': targets[target]})
                    names.add(symbol['demangled'])
            lines.append(f'{ins.address:#010x}: {ins.mnemonic:9} {ins.op_str}{suffix}')
        if symbol['demangled'] in names:
            selected.append({'name': symbol['demangled'], 'address': symbol['address'],
                             'file_offset': hex(offset), 'size': symbol['size'], 'instructions': lines})
    report = {'method': 'Capstone static disassembly; not REA Evidence; target not executed',
              'library': str(args.library), 'sha256': hashlib.sha256(data).hexdigest(),
              'decoder': 'capstone 5.0.6 ARM64 little endian', 'literal_keys': literals,
              'literal_references': literal_references,
              'decrypt_callers': decrypt_callers, 'selected_functions': selected}
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output/'native-static.json').write_text(json.dumps(report, indent=2)+'\n')
    (args.output/'selected-functions.asm').write_text('\n\n'.join(
        f"; {s['name']} VA {s['address']} file offset {s['file_offset']} size {s['size']}\n"+
        '\n'.join(s['instructions']) for s in selected)+'\n')
    print(json.dumps({'keys': literals, 'literal_references': literal_references, 'decrypt_callers': decrypt_callers,
                      'selected_functions': len(selected), 'output': str(args.output)}, indent=2))


if __name__ == '__main__':
    main()
