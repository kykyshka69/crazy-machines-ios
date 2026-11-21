#!/usr/bin/env python3
"""Recover the four CAB volumes embedded in the user-owned Smart Install Maker
Crazy Machines installer. Does NOT execute the Windows installer or decompress
CAB/LZX payloads. Requires Python 3 standard library only.

Usage: python3 tools/recover_sim_cabs.py installer.exe output_directory
The extracted cabinets remain copyrighted game data; do not commit them.
"""
import hashlib
import pathlib
import struct
import sys

OFFSETS = (396348, 8784956, 17173564, 25562172)
EXPECTED_LENGTHS = (8388612, 8388612, 8388612, 1052446)
EXPECTED_SHA256 = "8a36dd25e131e5541a8eca71cb7ded32ff93473cef28befaf914a40b9264fe19"


def recover(installer: pathlib.Path, output: pathlib.Path) -> None:
    raw = installer.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != EXPECTED_SHA256:
        raise ValueError(f"Installer SHA256 mismatch: {digest}")
    output.mkdir(parents=True, exist_ok=True)
    for number, (start, length) in enumerate(zip(OFFSETS, EXPECTED_LENGTHS)):
        if struct.unpack_from("<I", raw, start + 4)[0] != length:
            raise ValueError(f"Unexpected CAB size at offset {start}")
        cabinet = b"MSCF" + raw[start:start + length - 4]
        if len(cabinet) != length or cabinet[24] != 3:
            raise ValueError(f"Invalid reconstructed CAB {number}")
        path = output / f"{number:04d}.tmp"
        path.write_bytes(cabinet)
        print(f"{path}: {length} bytes; sha256={hashlib.sha256(cabinet).hexdigest()}")
    print("Four CAB containers recovered; LZX decompression is a separate step.")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: recover_sim_cabs.py installer.exe output_directory")
    recover(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]))
