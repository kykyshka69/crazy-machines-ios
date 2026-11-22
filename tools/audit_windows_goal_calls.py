#!/usr/bin/env python3
"""SHA-gated Windows CrazyMachines.exe 42 native GOAL callback inventory.

The authentic x86 game dispatches GOAL/CONNECTED_TO events through 0x44B460.
This read-only audit confirms every REL32 call and refuses any different EXE.
Public CI checks invalid-executable rejection, not the private Windows bytes.
"""
import argparse
import hashlib
import struct
from pathlib import Path

SHA256="51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6"
DISPATCHER=0x44B460
CALL_SITES=(
 0x434A76,0x434B12,0x443FE5,0x444024,0x444D22,
 0x44BCE5,0x44BFA5,0x44C0D5,0x44C1DC,0x44C76D,0x44C7EF,
 0x44CF98,0x44D19E,0x44D3E0,0x44D9A2,0x44D9E5,
 0x44DE56,0x44DFEE,0x44E438,0x44E6F6,0x44E9CA,
 0x44ED6D,0x44F354,0x44F4D2,0x44F7C0,
 0x44FA58,0x44FAA1,0x450039,0x4500B9,0x450627,0x45086E,
 0x450A71,0x450C7C,0x450E90,0x450FED,0x4514AF,
 0x456F33,0x456FA4,0x4571B1,0x457A5B,0x457C16,0x4583AF
)

def verify(exe: bytes):
    if hashlib.sha256(exe).hexdigest()!=SHA256:
        raise ValueError("Original CrazyMachines.exe SHA-256 differs")
    if exe[:2]!=b"MZ":
        raise ValueError("Original PE32 MZ header absent")
    pe=struct.unpack_from("<I",exe,0x3c)[0]
    if exe[pe:pe+4]!=b"PE\0\0":
        raise ValueError("Original PE32 signature absent")
    count=struct.unpack_from("<H",exe,pe+6)[0]
    optlength=struct.unpack_from("<H",exe,pe+20)[0]
    opt=pe+24
    if struct.unpack_from("<H",exe,opt)[0]!=0x10b:
        raise ValueError("Expected x86 PE32")
    base=struct.unpack_from("<I",exe,opt+28)[0]
    calls=[]
    for section_index in range(count):
        row=opt+optlength+section_index*40
        name,vsize,rva,rsize,raw=struct.unpack_from("<8sIIII",exe,row)
        if name.split(b"\0")[0]!=b".text":
            continue
        if raw+rsize>len(exe):
            raise ValueError("Truncated original PE32 section")
        for offset in range(raw,raw+rsize-4):
            if exe[offset]!=0xe8:
                continue
            va=base+rva+(offset-raw)
            target=va+5+struct.unpack_from("<i",exe,offset+1)[0]
            if target==DISPATCHER:
                calls.append(va)
    if tuple(calls)!=CALL_SITES:
        raise ValueError("Original Win32 GOAL call site set differs")
    return {"dispatcher":hex(DISPATCHER), "native_callbacks":len(calls)}

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original_exe",type=Path)
    print(verify(parser.parse_args().original_exe.read_bytes()))
