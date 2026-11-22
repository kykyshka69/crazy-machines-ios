#!/usr/bin/env python3
"""Read-only x86 instruction proof for the original power-switch pair gate."""
import argparse
import hashlib
import struct
from pathlib import Path

SHA256 = '51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6'
SITES = {
    0x44C98B: '68 10 c6 4e 00',
    0x44C9A7: '6a 00',
    0x44C9AC: 'e8 0f 2e fd ff', # choose contact source
    0x44C9B9: 'e8 12 2b fd ff', # choose mating part
    0x44C9C4: 'd9 05 18 3c 4f 00', # +1 contact value
    0x44C9CA: 'd9 82 ec 00 00 00', # selected +0xEC
    0x44C9D0: 'da e9',
    0x44C9D4: 'f6 c4 44',
    0x44C9D7: '7a 18', # if first !=+1, branch to -1 test
    0x44C9DC: 'd9 05 18 3c 4f 00',
    0x44C9E2: 'd9 80 c8 00 00 00', # mating +0xC8
    0x44C9EC: 'f6 c4 44',
    0x44C9EF: '7a 30', # if mate not +1, block
    0x44C9F4: 'd9 05 3c 76 4e 00', # -1 contact value
    0x44C9FA: 'd9 81 ec 00 00 00',
    0x44CA04: 'f6 c4 44',
    0x44CA07: '7a 22', # not -1: no write
    0x44CA0C: 'd9 05 3c 76 4e 00',
    0x44CA12: 'd9 82 c8 00 00 00',
    0x44CA1C: 'f6 c4 44',
    0x44CA1F: '7b 0a', # matches -1: no write
    0x44CA24: 'c7 40 40 00 00 00 00', # mismatch zeroes +0x40
    0x44CA2B: 'e9 9c 01 00 00',
}
CONSTANTS={0x4F3C18:1.0,0x4E763C:-1.0}
STRINGS={0x4EC610:b'tmo_power_switch\0'}

def verify(data:bytes):
    if hashlib.sha256(data).hexdigest()!=SHA256:
        raise ValueError('Wrong original CrazyMachines.exe SHA-256')
    pe=struct.unpack_from('<I',data,0x3c)[0]
    if data[:2]!=b'MZ' or data[pe:pe+4]!=b'PE\0\0':
        raise ValueError('Invalid PE')
    n=struct.unpack_from('<H',data,pe+6)[0]
    olen=struct.unpack_from('<H',data,pe+20)[0]
    opt=pe+24
    if struct.unpack_from('<H',data,opt)[0]!=0x10b:raise ValueError('Requires PE32')
    base=struct.unpack_from('<I',data,opt+28)[0]
    segments=[]
    for i in range(n):
        row=opt+olen+i*40
        _,vsize,rva,rsize,raw=struct.unpack_from('<8sIIII',data,row)
        segments.append((base+rva,max(vsize,rsize),raw))
    def read(va,n):
        for start,size,raw in segments:
            if start<=va and va+n<=start+size:
                return data[raw+va-start:raw+va-start+n]
        raise ValueError('Missing address '+hex(va))
    for va,pattern in SITES.items():
        expected=bytes.fromhex(pattern)
        if read(va,len(expected))!=expected:
            raise ValueError('Original switch opcode changed at '+hex(va))
    for va,expected in CONSTANTS.items():
        if struct.unpack('<f',read(va,4))[0]!=expected:
            raise ValueError('Win32 switch constant mismatch at '+hex(va))
    for va,expected in STRINGS.items():
        if read(va,len(expected))!=expected:
            raise ValueError('Original switch type mismatch at '+hex(va))
    return {'instruction_sites':len(SITES),'floats':len(CONSTANTS),'selectors':len(STRINGS)}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('original_exe',type=Path)
    print('Verified original switch contact pair:',verify(p.parse_args().original_exe.read_bytes()))