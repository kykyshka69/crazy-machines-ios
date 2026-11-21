#!/usr/bin/env python3
"""Build CMASSET1 import pack from a user's own original Crazy Machines files.

Usage:
    python tools/build_original_asset_pack.py EXTRACTED_INSTALLATION EXPORTED_SCENES OUTPUT.cmassets

EXTRACTED_INSTALLATION must contain data/models, data/textures, data/labs.
EXPORTED_SCENES should contain the 102 private level-###.json exports.
Never commit or publicly redistribute the generated proprietary resource pack.
"""
import argparse
import hashlib
import struct
from collections import Counter
from pathlib import Path

EXTENSIONS = {".ucm", ".tga", ".cml"}


def build(installed: Path, scenes: Path, output: Path) -> dict:
    files = [
        p for p in installed.rglob("*")
        if p.is_file() and p.suffix.lower() in EXTENSIONS
    ]
    levels = sorted(scenes.glob("level-*.json"))
    if len(files) != 343 or len(levels) != 102:
        raise ValueError(
            f"Unexpected resource count: {len(files)} game files, "
            f"{len(levels)} scenes; expected 343 and 102"
        )
    entries = sorted(files, key=lambda p: p.name.lower()) + levels
    names = [p.name.lower() for p in entries]
    if len(set(names)) != len(entries):
        raise ValueError("Duplicate original asset basenames; pack would be ambiguous")
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as stream:
        stream.write(b"CMASSET1")
        stream.write(struct.pack("<I", len(entries)))
        for path in entries:
            name = path.name.encode("utf-8")
            payload = path.read_bytes()
            if not (0 < len(name) <= 255 and 0 < len(payload) <= 64 * 1024 * 1024):
                raise ValueError(f"Invalid original entry: {path}")
            stream.write(struct.pack("<H", len(name)))
            stream.write(name)
            stream.write(struct.pack("<I", len(payload)))
            stream.write(hashlib.sha256(payload).digest())
            stream.write(payload)
    verify(output)
    return {
        "entries": len(entries),
        "types": dict(Counter(p.suffix.lower() for p in entries)),
        "size": output.stat().st_size,
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
    }


def verify(path: Path) -> None:
    payload = path.read_bytes()
    if payload[:8] != b"CMASSET1":
        raise ValueError("Bad pack magic")
    offset = 8
    count = int.from_bytes(payload[offset:offset + 4], "little")
    offset += 4
    if not 1 <= count <= 1024:
        raise ValueError("Invalid count")
    for number in range(count):
        if len(payload) - offset < 2:
            raise ValueError("Truncated name length")
        name_length = int.from_bytes(payload[offset:offset + 2], "little")
        offset += 2
        if not 1 <= name_length <= 255 or offset + name_length + 36 > len(payload):
            raise ValueError("Invalid name length")
        name = payload[offset:offset + name_length].decode("utf-8")
        offset += name_length
        size = int.from_bytes(payload[offset:offset + 4], "little")
        offset += 4
        digest = payload[offset:offset + 32]
        offset += 32
        if not size or offset + size > len(payload):
            raise ValueError(f"Truncated entry {number}: {name}")
        data = payload[offset:offset + size]
        offset += size
        if hashlib.sha256(data).digest() != digest:
            raise ValueError(f"Invalid entry checksum: {name}")
    if offset != len(payload):
        raise ValueError("Trailing bytes")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original_installation", type=Path)
    parser.add_argument("scene_json_directory", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    print(build(args.original_installation, args.scene_json_directory, args.output))


if __name__ == "__main__":
    main()
