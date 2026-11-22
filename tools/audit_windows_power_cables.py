#!/usr/bin/env python3
"""Verify original Win32 power-cable creation, without bundling PC resources.

This identifies the cable-construction path, not electrical conductivity or
voltage semantics. The game creates a `power_cable` from TWO physical ends;
VALF of `tmo_power_plug` is not evidence of which two ends connect.
"""
import hashlib
import json
import struct
import sys
from pathlib import Path

SUPPORTED_SHA256 = "51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6"
SITES = [
    (0x42FCB9, "68489c4e00", "look up original power_cable source"),
    (0x42FCDA, "6a016a00", "request first endpoint of power cable"),
    (0x42FCF0, "6a016a01", "request second endpoint of power cable"),
    (0x42FD06, "68549c4e00", "look up original Power material"),
    (0x42FD27, "894144", "attach Power material to first end"),
    (0x42FD33, "894a44", "attach same material to second end"),
    (0x42FD42, "8b55e8", "construct between two retrieved endpoints"),
    (0x42FD4B, "e810d1ffff", "create physical cable from endpoint pair"),
]
STRINGS = [
    (0x4E9C48, b"power_cable\0"),
    (0x4E9C54, b"Power\0"),
]


def verify(path: Path) -> dict:
    b = path.read_bytes()
    sha = hashlib.sha256(b).hexdigest()
    if sha != SUPPORTED_SHA256:
        raise ValueError("Unsupported original Windows CrazyMachines.exe")
    if b[:2] != b"MZ":
        raise ValueError("Missing MZ header")
    pe = struct.unpack_from("<I", b, 0x3C)[0]
    if b[pe:pe+4] != b"PE\0\0":
        raise ValueError("Missing PE header")
    count = struct.unpack_from("<H", b, pe + 6)[0]
    opt = struct.unpack_from("<H", b, pe + 20)[0]
    base = struct.unpack_from("<I", b, pe + 24 + 28)[0]
    sections = []
    for i in range(count):
        o = pe + 24 + opt + i * 40
        rva, raw_len, raw_off = struct.unpack_from("<III", b, o + 12)[0], struct.unpack_from("<I", b, o + 16)[0], struct.unpack_from("<I", b, o + 20)[0]
        sections.append((rva, raw_len, raw_off))
    def at(va, size):
        rel = va - base
        for rva, n, off in sections:
            if rva <= rel and rel + size <= rva + n:
                start = off + rel - rva
                return b[start:start+size]
        raise ValueError("VA outside original PE sections")
    for va, hx, desc in SITES:
        if at(va, len(bytes.fromhex(hx))) != bytes.fromhex(hx):
            raise ValueError(f"Unexpected x86 instruction {desc} at {va:#x}")
    for va, expected in STRINGS:
        if at(va, len(expected)) != expected:
            raise ValueError(f"Unexpected power resource string at {va:#x}")
    return {
        "sha256": sha,
        "sites": len(SITES), "source_strings": len(STRINGS),
        "source_endpoint_fetches": ["0x42FCDA first end", "0x42FCF0 second end"],
        "constructor": "0x42FD4B",
        "inference_prohibited": "Do not pair ports from VALF alone; original wire topology is distinct data",
        "scope": "Cable creation confirmed; Windows current simulation still unrecovered"
    }

if __name__ == "__main__":
    print(json.dumps(verify(Path(sys.argv[1])), indent=2))