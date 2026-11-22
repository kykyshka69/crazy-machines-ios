#!/usr/bin/env python3
"""Validate original Win32 goal-counter callchain, without copying game bytes.

Read-only, PE32-aware instruction and string verification against the user's
original CrazyMachines.exe. Evidence belongs to this exact EXE build, not an
assumed generic Crazy Machines version or a substitute engine.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path

SUPPORTED_SHA256 = "51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6"

# Address, instruction bytes, and what is proven by their immediate/offset.
# Short instruction signatures are evidence pointers, not reusable game code.
SITES = [
    (0x422E80, "6810954e00", "parse GOAL field name"),
    (0x422ECC, "898160010000", "GOAL integer -> tmo object +0x160"),
    (0x422FE2, "68f0954e00", "parse CONNECTED_TO field name"),
    (0x42302E, "898174010000", "CONNECTED_TO index -> object +0x174"),
    (0x44AC46, "898270010000", "resolved CONNECTED_TO object pointer -> +0x170"),
    (0x454E1F, "83b86001000000", "count nonzero GOAL channel"),
    (0x454E34, "83ba7001000000", "count nonzero CONNECTED_TO channel"),
    (0x44B4C6, "c7816401000001000000", "latch GOAL event once"),
    (0x44B509, "c7816801000001000000", "latch linked-contact event once"),
    (0x44B4DF, "8981ac000000", "credit GOAL event to per-run count"),
    (0x44B522, "8981ac000000", "credit linked event to per-run count"),
    (0x44B54B, "3b88a8000000", "compare delivered against required"),
    (0x44B592, "c682d400000001", "latch completed level state"),
]
EXPECTED_STRINGS = {
    0x4E9510: b"GOAL\0",
    0x4E95F0: b"CONNECTED_TO\0",
    0x4EC470: b"task_solved\0",
    0x4EC47C: b"level_done_0\0",
    0x4EC48C: b"level_done_1\0",
    0x4EC49C: b"level_done_2\0",
}


def verify(path: Path) -> dict:
    data = path.read_bytes()
    sha = hashlib.sha256(data).hexdigest()
    if sha != SUPPORTED_SHA256:
        raise ValueError("unsupported original CrazyMachines.exe SHA-256; x86 offsets not verified")
    if data[:2] != b"MZ":
        raise ValueError("not a Windows executable")
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe:pe + 4] != b"PE\x00\x00":
        raise ValueError("missing PE signature")
    if struct.unpack_from("<H", data, pe + 4)[0] != 0x14C:
        raise ValueError("not a 32-bit x86 EXE")
    count = struct.unpack_from("<H", data, pe + 6)[0]
    opt = struct.unpack_from("<H", data, pe + 20)[0]
    base = struct.unpack_from("<I", data, pe + 24 + 28)[0]
    sections = []
    for i in range(count):
        off = pe + 24 + opt + i * 40
        sections.append((
            struct.unpack_from("<I", data, off + 12)[0],  # RVA
            struct.unpack_from("<I", data, off + 20)[0],  # raw offset
            struct.unpack_from("<I", data, off + 16)[0],  # raw size
        ))

    def at(virtual_address: int, size: int) -> bytes:
        rel = virtual_address - base
        for rva, offset, length in sections:
            if rva <= rel and rel + size <= rva + length:
                start = offset + rel - rva
                return data[start:start + size]
        raise ValueError(f"VA 0x{virtual_address:X} not in mapped PE data")

    for address, hexbytes, description in SITES:
        expected = bytes.fromhex(hexbytes)
        if at(address, len(expected)) != expected:
            raise ValueError(f"Win32 evidence changed at 0x{address:X}: {description}")
    for address, label in EXPECTED_STRINGS.items():
        if at(address, len(label)) != label:
            raise ValueError(f"Windows event name mismatch at 0x{address:X}")
    return {
        "exe_sha256": sha,
        "verified_instructions": len(SITES),
        "verified_strings": len(EXPECTED_STRINGS),
        "recovered_chain": {
            "goal_flag": "per-object +0x160 from GOAL; once-only event latch +0x164",
            "link_target": "CONNECTED_TO index +0x174 -> pointer +0x170; once-only event latch +0x168",
            "required": "sum of all nonzero GOAL and connected-pointer channels (+0xA8)",
            "credited": "per-run +0xAC, incremented once per channel",
            "complete": "counter equality at 0x44B54B, completion latch at 0x44B592",
            "events": ["task_solved", "level_done_0", "level_done_1", "level_done_2"],
        },
        "limits": "mechanism event conditions and original solver still require reconstruction",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("exe", type=Path, help="user-owned original CrazyMachines.exe")
    args = parser.parse_args()
    print(json.dumps(verify(args.exe), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()