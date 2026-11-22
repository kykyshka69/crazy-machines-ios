#!/usr/bin/env python3
"""Proof of original Win32 source-click physics and GOAL: private EXE required.

Audits 22 x86 sites and 4 Windows strings in the owner's one SHA-gated
CrazyMachines.exe; does not distribute the game binary or its assets.
"""
import argparse
import hashlib
import struct
from pathlib import Path

SHA256 = "51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6"
INSTRUCTIONS = {
    0x4226DE:"68 ec 91 4e 00",                 # VALF loader
    0x42272A:"d9 98 ec 00 00 00",              # scene VALF -> +0xEC
    0x45523B:"8b 88 ec 00 00 00",              # read original source state
    0x455241:"89 8a f0 00 00 00",              # start snapshot +0xF0
    0x43490D:"83 e1 10",                       # user interactable bit
    0x4349A0:"68 50 a4 4e 00",                 # candle selector
    0x4349B8:"68 5c a4 4e 00",                 # blowtorch selector
    0x434A07:"c7 81 ec 00 00 00 00 00 80 3f", # heat on
    0x434A16:"c7 82 ec 00 00 00 00 00 00 00", # heat off
    0x434A50:"d9 80 ec 00 00 00",              # heat actual
    0x434A56:"d9 82 f0 00 00 00",              # heat initial
    0x434A60:"f6 c4 44",                       # x87 compare
    0x434A63:"7b 16",                          # equal => no GOAL
    0x434A76:"e8 e5 69 01 00",                 # native GOAL dispatcher
    0x434A9A:"68 70 a4 4e 00",                 # pocketlamp selector
    0x434ACD:"c7 81 ec 00 00 00 00 00 80 3f", # pocketlamp on
    0x434ADC:"c7 82 ec 00 00 00 00 00 00 00", # pocketlamp off
    0x434AEC:"d9 81 ec 00 00 00",              # pocketlamp actual
    0x434AF2:"d9 80 f0 00 00 00",              # pocketlamp initial
    0x434AFC:"f6 c4 44",                       # x87 compare
    0x434AFF:"7b 16",                          # equal => no GOAL
    0x434B12:"e8 49 69 01 00",                 # native GOAL dispatcher
}
ORIGINAL_STRINGS = {
    0x4E91EC: b"VALF\x00",
    0x4EA450: b"tmo_candle\x00",
    0x4EA45C: b"tmo_heat_blowtorch\x00",
    0x4EA470: b"tmo_light_pocketlamp\x00",
}

def verify(exe: bytes) -> dict:
    if hashlib.sha256(exe).hexdigest() != SHA256:
        raise ValueError("Original CrazyMachines.exe SHA-256 mismatch")
    if exe[:2] != b"MZ":
        raise ValueError("Missing MZ signature")
    pe = struct.unpack_from("<I", exe, 0x3C)[0]
    if exe[pe:pe+4] != b"PE\x00\x00":
        raise ValueError("Missing original PE32 header")
    count = struct.unpack_from("<H", exe, pe+6)[0]
    opt_len = struct.unpack_from("<H", exe, pe+20)[0]
    opt = pe+24
    if struct.unpack_from("<H", exe, opt)[0] != 0x10B:
        raise ValueError("Expected original x86 PE32")
    base = struct.unpack_from("<I", exe, opt+28)[0]
    segments = []
    for index in range(count):
        row = opt + opt_len + 40*index
        _, virtual_size, rva, raw_size, offset = struct.unpack_from("<8sIIII", exe, row)
        segments.append((base+rva, max(virtual_size,raw_size), offset))
    def read(va: int, length: int) -> bytes:
        for start, size, offset in segments:
            if start <= va and va+length <= start+size:
                raw = offset+va-start
                if raw+length <= len(exe):
                    return exe[raw:raw+length]
        raise ValueError("Invalid original PE address: "+hex(va))
    for addr, instruction in INSTRUCTIONS.items():
        expected = bytes.fromhex(instruction)
        if read(addr, len(expected)) != expected:
            raise ValueError("Original x86 source-click mismatch: "+hex(addr))
    for addr, value in ORIGINAL_STRINGS.items():
        if read(addr, len(value)) != value:
            raise ValueError("Original selector mismatch: "+hex(addr))
    return {"x86_instruction_sites": len(INSTRUCTIONS),
            "original_type_strings": len(ORIGINAL_STRINGS),
            "original_sha256":SHA256}

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original_exe", type=Path)
    print(verify(parser.parse_args().original_exe.read_bytes()))
