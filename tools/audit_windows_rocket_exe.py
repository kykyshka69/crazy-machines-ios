#!/usr/bin/env python3
"""Original native rocket x86 source SHA gate; no game bytes in GitHub."""
import argparse
import hashlib
import struct
from pathlib import Path
SHA="51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6"
SITES={
    0x44F03B:"d9 05 ac 74 4e 00",
    0x44F041:"d9 80 ec 00 00 00",
    0x44F04B:"f6 c4 44",
    0x44F04E:"0f 8a 58 03 00 00",
    0x44F1A2:"68 98 ca 4e 00",
    0x44F288:"8b 91 24 01 00 00",
    0x44F28E:"dd 02",
    0x44F296:"dc a0 30 01 00 00",
    0x44F29C:"dc 1d c8 9b 4e 00",
    0x44F2A4:"f6 c4 41",
    0x44F2A7:"0f 85 ff 00 00 00",
    0x44F33C:"c7 80 ec 00 00 00 00 00 40 40",
    0x44F354:"e8 07 c1 ff ff",
}
def verify(exe: bytes) -> dict:
    if hashlib.sha256(exe).hexdigest()!=SHA:
        raise ValueError("Original CrazyMachines.exe SHA-256 mismatch")
    if exe[:2]!=b"MZ":raise ValueError("Missing original PE32 header")
    pe=struct.unpack_from("<I",exe,0x3c)[0]
    if exe[pe:pe+4]!=b"PE\0\0":raise ValueError("Invalid PE32 signature")
    count=struct.unpack_from("<H",exe,pe+6)[0]
    optlen=struct.unpack_from("<H",exe,pe+20)[0]
    opt=pe+24
    if struct.unpack_from("<H",exe,opt)[0]!=0x10b:
        raise ValueError("Expected original x86 PE32")
    base=struct.unpack_from("<I",exe,opt+28)[0]
    sections=[]
    for i in range(count):
        row=opt+optlen+40*i
        _,vs,rva,rs,raw=struct.unpack_from("<8sIIII",exe,row)
        sections.append((base+rva,max(vs,rs),raw))
    def read(va,n):
        for start,sz,raw in sections:
            if start<=va and va+n<=start+sz:
                pos=raw+va-start
                if pos+n<=len(exe):return exe[pos:pos+n]
        raise ValueError("Native original rocket address not mapped")
    for address,code in SITES.items():
        expected=bytes.fromhex(code)
        if read(address,len(expected))!=expected:
            raise ValueError("Native original rocket x86 mismatch at "+hex(address))
    if read(0x4ECA98,16)!=b"tmo_heat_rocket\0":
        raise ValueError("Original rocket type selector mismatch")
    if struct.unpack("<f",read(0x4E74AC,4))[0]!=2.0:
        raise ValueError("Native rocket flying state mismatch")
    if struct.unpack("<d",read(0x4E9BC8,8))[0]!=3.0:
        raise ValueError("Native original rocket fuse mismatch")
    return {"x86_sites":len(SITES),"flying_state":2,
            "strict_fuse_seconds":3,"exploded_state":3}
if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original_exe",type=Path)
    print(verify(parser.parse_args().original_exe.read_bytes()))
