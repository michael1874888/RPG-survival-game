#!/usr/bin/env python3
"""Read-only derived data decoder; repeating-key transform inferred from data and statically corroborated by native decoder.
Does not execute the game. Outputs must be a new directory; original files unchanged.
"""
import argparse
import hashlib
import json
from pathlib import Path

KEYS = {'wave.txt': b'BEwareTheFisH', 'items.txt': b'F0rk1tA3ll'}
SKILL_KEY = b'FORASUMMERSDAY'


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('input', type=Path)
    ap.add_argument('output', type=Path)
    args = ap.parse_args()
    if not args.input.is_dir():
        ap.error('input must be existing extracted assets/data directory')
    if args.output.exists():
        ap.error('output must not exist; use a new derived directory')
    rows = []
    decoded = []
    for path in sorted(args.input.glob('*.txt')):
        original = path.read_bytes()
        key = KEYS.get(path.name, SKILL_KEY)
        is_buffer = path.name in KEYS
        result = bytes(value ^ key[index % len(key)] if is_buffer or value != key[index % len(key)]
                       else value for index, value in enumerate(original))
        transform = ('pure repeating XOR' if is_buffer else
                     'if ciphertext == keybyte preserve; otherwise XOR; repeated key; reset per file')
        authority = ('IOBuffer caller/key/loop statically corroborated; runtime unverified' if is_buffer else
                     'skill key initialization and String decoder statically corroborated; complete loader/runtime unverified')
        result.decode('ascii')
        invalid = [value for value in result if value < 32 and value not in (9, 10, 13)]
        if invalid:
            ap.error(f'{path.name}: unexpected control bytes; no output written')
        decoded.append((path.name, result))
        rows.append({'name': path.name, 'source_path': str(path.resolve()),
                     'transform': transform,
                     'candidate_key': key.decode(), 'bytes': len(original),
                     'source_sha256': hashlib.sha256(original).hexdigest(),
                     'derived_sha256': hashlib.sha256(result).hexdigest(),
                     'lines': len(result.splitlines()),
                     'authority': authority})
    args.output.mkdir(parents=True)
    for name, result in decoded:
        (args.output / name).write_bytes(result)
    (args.output / 'manifest.json').write_text(json.dumps(rows, indent=2) + '\n')
    print(json.dumps({'files': len(rows), 'decoded_bytes': sum(row['bytes'] for row in rows),
                      'output': str(args.output.resolve())}, ensure_ascii=False))


if __name__ == '__main__':
    main()
