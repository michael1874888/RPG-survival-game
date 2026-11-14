#!/usr/bin/env python3
"""Read binary manifest identity and APK Signing Block certificate identities.

Does not validate APK signatures or establish official publisher provenance.
Requires cryptography. Never loads or executes target code.
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile
from cryptography import x509


def u32(b, o=0):
    return struct.unpack_from('<I', b, o)[0]


def lp(b, off):
    n = u32(b, off)
    end = off+4+n
    if end > len(b):
        raise ValueError('Invalid length-prefixed record')
    return b[off+4:end], end


def manifest_identity(data):
    strings = []
    tags = []
    off = 8
    while off+8 <= len(data):
        kind, header, size = struct.unpack_from('<HHI', data, off)
        if size < header or off+size > len(data):
            raise ValueError('Invalid Android resource chunk')
        chunk = data[off:off+size]
        if kind == 1:
            count, styles, flags, start, style_start = struct.unpack_from('<IIIII', chunk, 8)
            utf8 = bool(flags & 0x100)
            def length8(pos):
                n = chunk[pos]; pos += 1
                if n & 0x80:
                    n = ((n & 0x7f) << 8) | chunk[pos]; pos += 1
                return n, pos
            for i in range(count):
                pos = start+u32(chunk, header+4*i)
                if utf8:
                    _, pos = length8(pos)
                    n, pos = length8(pos)
                    strings.append(chunk[pos:pos+n].decode('utf-8'))
                else:
                    n = struct.unpack_from('<H', chunk, pos)[0]; pos += 2
                    if n & 0x8000:
                        n = ((n & 0x7fff) << 16) | struct.unpack_from('<H', chunk, pos)[0]; pos += 2
                    strings.append(chunk[pos:pos+2*n].decode('utf-16le'))
        elif kind == 0x102:
            name = strings[u32(chunk, 20)]
            if name in {'manifest', 'uses-sdk', 'application'}:
                start, stride, count = struct.unpack_from('<HHH', chunk, 24)
                attrs = {}
                for i in range(count):
                    pos = 16+start+i*stride
                    namespace, attr_name, raw, val_size, reserved, val_type, val = struct.unpack_from('<IIIHBBI', chunk, pos)
                    attrs[strings[attr_name]] = strings[raw] if raw != 0xffffffff else (strings[val] if val_type == 3 else val)
                tags.append({'tag': name, 'attributes': attrs})
        off += size
    return tags


def certificates(data):
    eocd = data.rfind(b'PK\x05\x06', max(0, len(data)-65557))
    if eocd < 0:
        raise ValueError('No ZIP EOCD')
    cd = u32(data, eocd+16)
    if data[cd-16:cd] != b'APK Sig Block 42':
        return []
    block_size = struct.unpack_from('<Q', data, cd-24)[0]
    start = cd-block_size-8
    if struct.unpack_from('<Q', data, start)[0] != block_size:
        raise ValueError('APK signing block sizes disagree')
    result = []
    pos = start+8
    while pos < cd-24:
        pair_size = struct.unpack_from('<Q', data, pos)[0]
        scheme_id = u32(data, pos+8)
        value = data[pos+12:pos+8+pair_size]
        if scheme_id in {0x7109871a, 0xf05368c0, 0x1b93ad61}:
            signers, _ = lp(value, 0)
            signer_pos = 0
            while signer_pos < len(signers):
                signer, signer_pos = lp(signers, signer_pos)
                signed, _ = lp(signer, 0)
                _, cursor = lp(signed, 0)
                certs, _ = lp(signed, cursor)
                cert_pos = 0
                while cert_pos < len(certs):
                    der, cert_pos = lp(certs, cert_pos)
                    x509.load_der_x509_certificate(der)
                    result.append({'scheme_block_id': hex(scheme_id),
                                   'certificate_sha256': hashlib.sha256(der).hexdigest()})
        pos += 8+pair_size
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--packages', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = {'method': 'Python binary XML / APK Signing Block certificate parsing; not REA Evidence',
              'signature_verified': False, 'official_publisher_provenance_verified': False, 'packages': []}
    for path in sorted(args.packages.glob('*.apk')):
        data = path.read_bytes()
        with zipfile.ZipFile(path) as apk:
            manifest = manifest_identity(apk.read('AndroidManifest.xml'))
        result['packages'].append({'name': path.name, 'sha256': hashlib.sha256(data).hexdigest(),
                                   'manifest': manifest, 'certificates': certificates(data)})
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
