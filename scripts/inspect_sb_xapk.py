#!/usr/bin/env python3
"""Inventory the supplied XAPK and extract only packages, data and native code.

This uses ordinary ZIP/ELF parsing; its output is not REA Evidence.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import struct
import subprocess
import zipfile


def sha(data):
    return hashlib.sha256(data).hexdigest()


def safe_write(root, name, data):
    parts = PurePosixPath(name).parts
    if not parts or name.startswith('/') or '..' in parts:
        raise ValueError(f'Unsafe member: {name}')
    dest = root.joinpath(*parts)
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and sha(dest.read_bytes()) != sha(data):
        raise ValueError(f'Refusing to overwrite different bytes: {dest}')
    dest.write_bytes(data)
    return str(dest)


def elf_symbols(data):
    if data[:6] != b'\x7fELF\x02\x01':
        raise ValueError('Expected a little-endian ELF64 library')
    h = struct.unpack_from('<16sHHIQQQIHHHHHH', data)
    sections = [struct.unpack_from('<IIQQQQIIQQ', data, h[6] + i*h[11])
                for i in range(h[12])]
    result = []
    for section in sections:
        if section[1] != 11:
            continue
        st = sections[section[6]]
        names = data[st[4]:st[4]+st[5]]
        for off in range(section[4], section[4]+section[5], section[9]):
            name, info, other, index, value, size = struct.unpack_from('<IBBHQQ', data, off)
            name = names[name:].split(b'\0', 1)[0].decode(errors='replace')
            if name:
                result.append({'name': name, 'address': hex(value), 'size': size,
                               'type': info & 15, 'binding': info >> 4,
                               'defined': index != 0})
    raw = '\n'.join(x['name'] for x in result) + '\n'
    proc = subprocess.run(['/usr/bin/c++filt'], input=raw, text=True,
                          capture_output=True, check=True)
    readable = proc.stdout.splitlines()
    if len(readable) != len(result):
        raise ValueError('Demangled symbol count mismatch')
    for symbol, name in zip(result, readable):
        symbol['demangled'] = name
    return {'machine': h[2], 'sections': h[12], 'symbols': result}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    raw = args.input.read_bytes()
    report = {'method': 'Python standard-library ZIP/ELF inventory; not REA Evidence',
              'source': str(args.input), 'source_size': len(raw), 'source_sha256': sha(raw),
              'artifact_directory': str(args.output), 'packages': []}
    with zipfile.ZipFile(io.BytesIO(raw)) as outer:
        report['xapk_manifest'] = json.loads(outer.read('manifest.json'))
        if sum(x.file_size for x in outer.infolist()) > 500*1024*1024:
            raise ValueError('Unexpected outer extraction size')
        for member in outer.infolist():
            if not member.filename.endswith('.apk'):
                continue
            data = outer.read(member)
            path = safe_write(args.output/'packages', member.filename, data)
            package = {'name': member.filename, 'path': path, 'size': len(data),
                       'sha256': sha(data), 'members': []}
            with zipfile.ZipFile(io.BytesIO(data)) as apk:
                if sum(x.file_size for x in apk.infolist()) > 500*1024*1024:
                    raise ValueError('Unexpected APK expanded size')
                for item in apk.infolist():
                    package['members'].append({'path': item.filename, 'bytes': item.file_size})
                    if item.filename.startswith('assets/data/') and not item.is_dir():
                        contents = apk.read(item)
                        dest = safe_write(args.output/'extracted', item.filename, contents)
                        package.setdefault('data_files', []).append(
                            {'path': item.filename, 'extracted_path': dest, 'sha256': sha(contents)})
                    elif item.filename.startswith('lib/') and item.filename.endswith('.so'):
                        contents = apk.read(item)
                        dest = safe_write(args.output/'extracted', item.filename, contents)
                        elf = elf_symbols(contents)
                        sym_path = Path(dest + '.symbols.json')
                        sym_path.write_text(json.dumps(elf, indent=2))
                        package.setdefault('libraries', []).append(
                            {'path': item.filename, 'extracted_path': dest, 'sha256': sha(contents),
                             'machine': elf['machine'], 'dynamic_symbol_count': len(elf['symbols']),
                             'symbol_inventory': str(sym_path)})
            report['packages'].append(package)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
    print(json.dumps({'report': str(args.report), 'artifact_directory': str(args.output),
                      'packages': len(report['packages']),
                      'data_files': sum(len(p.get('data_files', [])) for p in report['packages']),
                      'libraries': [lib for p in report['packages'] for lib in p.get('libraries', [])]},
                     indent=2, ensure_ascii=False))


if __name__ == '__main__':
    main()
