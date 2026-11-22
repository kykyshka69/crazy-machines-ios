#!/usr/bin/env python3
"""Verify the original Win32 x87 optical beam kernel using the owner's EXE."""
import argparse
import hashlib
import struct
from pathlib import Path

SHA = "51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6"
SITES = {
    0x40966D: "c7 45 f8 00 00 00 00",
    0x409688: "c7 45 d4 00 00 00 00",
    0x40969B: "83 c0 18",
    0x4096BC: "e8 1f f5 ff ff",
    0x4096C5: "e8 36 06 00 00",
    0x4096D6: "d8 59 34",
    0x4096DE: "7a 07",
    0x4096ED: "d8 5a 38",
    0x4096F5: "75 07",
    0x409709: "e8 02 99 ff ff",
    0x409718: "e8 93 98 ff ff",
    0x40972A: "e8 81 98 ff ff",
    0x409735: "d8 7d fc",
    0x40974B: "c7 45 fc 00 00 80 bf",
    0x409762: "c7 45 fc 00 00 80 3f",
    0x40976D: "e8 1e 05 00 00",
    0x40977E: "d8 5a 40",
    0x409786: "75 07",
    0x409795: "d8 48 44",
    0x4097A3: "d8 2d 18 3c 4f 00",
    0x4097AF: "d8 62 34",
    0x4097B5: "d8 48 3c",
    0x4097BE: "de c9",
    0x4097C3: "d9 19",
    0x4097D0: "e8 db 04 00 00",
    0x4097FD: "c7 02 00 00 00 00",
    0x409818: "c7 01 00 00 80 3f",
    0x409853: "b8 01 00 00 00",
    0x40985B: "c2 0c 00",
    0x44FD6E: "e8 dd 98 fb ff",
    0x44FDC6: "e8 85 98 fb ff",
    0x44FEC3: "e8 88 97 fb ff",
}
CONSTANTS = {0x4F3B9C: 0.0, 0x4F3C18: 1.0, 0x4E763C: -1.0}

def verify(data: bytes):
    if hashlib.sha256(data).hexdigest() != SHA:
        raise ValueError("Original CrazyMachines.exe SHA-256 mismatch")
    if data[:2] != b"MZ":
        raise ValueError("Invalid PE32 header")
    pe = struct.unpack_from("<I", data, 0x3c)[0]
    if data[pe:pe+4] != b"PE\0\0":
        raise ValueError("Missing PE signature")
    sections = struct.unpack_from("<H", data, pe+6)[0]
    optlen = struct.unpack_from("<H", data, pe+20)[0]
    opt = pe+24
    if struct.unpack_from("<H", data, opt)[0] != 0x10b:
        raise ValueError("Not x86 PE32")
    base = struct.unpack_from("<I", data, opt+28)[0]
    mapping = []
    for i in range(sections):
        row = opt+optlen+i*40
        _,virtual_size,rva,raw_size,raw = struct.unpack_from("<8sIIII", data, row)
        mapping.append((base+rva,max(virtual_size,raw_size),raw))
    def read(va,n):
        for v,size,offset in mapping:
            if v<=va and va+n<=v+size:
                start=offset+va-v
                if start+n<=len(data):
                    return data[start:start+n]
        raise ValueError("PE32 virtual address not mapped")
    for va,instruction in SITES.items():
        expected=bytes.fromhex(instruction)
        if read(va,len(expected)) != expected:
            raise ValueError("Win32 optical x86 site mismatch at "+hex(va))
    for va,value in CONSTANTS.items():
        if struct.unpack("<f",read(va,4))[0] != value:
            raise ValueError("Win32 optical float mismatch at "+hex(va))
    return {"instruction_sites":len(SITES),"native_constants":len(CONSTANTS),"hash":SHA}

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original_exe",type=Path)
    print(verify(parser.parse_args().original_exe.read_bytes()))
