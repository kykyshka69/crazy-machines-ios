#!/usr/bin/env python3
"""Read-only verification of genuine Windows solar-ray scalar path.

Requires the user's one known original CrazyMachines.exe. Nothing copyrighted
is copied to public outputs. Reproducible PE32 VA -> raw offset verification.
"""
import argparse
import hashlib
import struct
from pathlib import Path

SHA256 = '51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6'
SITES = {
    0x44FB90: '68 b0 cb 4e 00',  # select tmo_light_flower as photometric receiver
    0x44FBA8: '68 c4 cb 4e 00',  # or solarcell
    0x44FBC0: '68 d8 cb 4e 00',  # or magnifier
    0x44FC53: '68 ec cb 4e 00',  # emitting tmo_power_lamp
    0x44FD77: '8b 85 28 fd ff ff',
    0x44FD7D: 'd9 40 40',           # receiver physical power +0x40
    0x44FD80: 'd8 35 8c 7a 4e 00', # divide 10.0
    0x44FD86: 'd8 8d 14 fd ff ff', # multiply measured ray-hit weight
    0x44FD8C: 'd9 85 24 fd ff ff', # load geometric ray distance
    0x44FD92: 'd8 0d 38 81 4e 00', # multiply path length by 5.0
    0x44FD98: 'de f9',             # divide light by geometric attenuation
    0x44FDCF: '8b 8d 28 fd ff ff',
    0x44FDD5: 'd9 41 40',
    0x44FDD8: 'd8 35 8c 7a 4e 00',
    0x44FF35: 'd9 85 40 fd ff ff', # accumulated incident light
    0x44FF3B: 'd8 1d 18 3c 4f 00', # compare with cap 1.0
    0x44FF48: 'c7 85 40 fd ff ff 00 00 80 3f', # saturate at 1
    0x450043: '68 50 cc 4e 00', # tmo_power_solarcell branch
    0x45005F: 'd9 85 40 fd ff ff',
    0x450065: 'd8 0d 8c 7a 4e 00', # 10x scale
    0x450092: '89 48 40',       # write +0x40
    0x45009B: 'd9 42 40',
    0x45009E: 'd8 1d 18 3c 4f 00', # compare power>1 for GOAL
    0x4500B9: 'e8 a2 b3 ff ff', # original GOAL dispatcher
    0x45010F: '8b 8d 14 fb ff ff', # set context for power propagation
    0x450115: 'e8 86 c7 ff ff', # call 0x44C8A0
}
CONSTANTS = {0x4E7A8C: 10.0, 0x4E8138: 5.0, 0x4F3C18: 1.0}
STRINGS = {0x4ECBB0: b'tmo_light_flower\0',
           0x4ECBC4: b'tmo_power_solarcell\0',
           0x4ECBD8: b'tmo_light_magnifier\0',
           0x4ECC50: b'tmo_power_solarcell\0'}

def verify(data: bytes):
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise ValueError('The original CrazyMachines.exe SHA-256 differs')
    if data[:2] != b'MZ':
        raise ValueError('Expected PE32')
    pe = struct.unpack_from('<I', data, 0x3C)[0]
    if data[pe:pe+4] != b'PE\0\0':
        raise ValueError('PE signature invalid')
    nsections = struct.unpack_from('<H', data, pe+6)[0]
    optlen = struct.unpack_from('<H', data, pe+20)[0]
    opt = pe+24
    if struct.unpack_from('<H', data, opt)[0] != 0x10B:
        raise ValueError('Not PE32')
    image_base = struct.unpack_from('<I', data, opt+28)[0]
    segments = []
    for i in range(nsections):
        row = opt+optlen+i*40
        _, vsize, rva, rawsize, raw = struct.unpack_from('<8sIIII', data, row)
        segments.append((image_base+rva, max(vsize, rawsize), raw))
    def read(va, n):
        for start, size, raw in segments:
            if start <= va and va+n <= start+size:
                return data[raw+va-start:raw+va-start+n]
        raise ValueError('Address outside original PE section: '+hex(va))
    for va, pat in SITES.items():
        expected = bytes.fromhex(pat)
        if read(va, len(expected)) != expected:
            raise ValueError('Solar x86 instruction changed at '+hex(va))
    for va, expected in CONSTANTS.items():
        if struct.unpack('<f', read(va, 4))[0] != expected:
            raise ValueError('Solar float constant mismatch at '+hex(va))
    for va, expected in STRINGS.items():
        if read(va, len(expected)) != expected:
            raise ValueError('Solar branch type selector changed at '+hex(va))
    return {'instruction_sites':len(SITES), 'constants':len(CONSTANTS),
            'original_type_strings':len(STRINGS)}

if __name__ == '__main__':
    arg=argparse.ArgumentParser(description=__doc__)
    arg.add_argument('original_exe',type=Path)
    print('Verified original solar path:',verify(arg.parse_args().original_exe.read_bytes()))