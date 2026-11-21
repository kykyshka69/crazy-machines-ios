#!/usr/bin/env python3
"""Generate a tiny ORIGINAL-ASSET-PIPELINE TEST pack without PC copyrighted data.

Only used in CI. The single triangle and the scene are synthetic fixtures;
this is NOT an authentic Crazy Machines level. It checks app import and 3D
render/navigation paths without publishing the user's proprietary files.
"""
import argparse
import hashlib
import json
import struct
from pathlib import Path


def triangle_ucm() -> bytes:
    header = bytearray(92)
    header[:4] = b"UCM1"
    struct.pack_into("<I", header, 4, 1)
    struct.pack_into("<4I", header, 72, 1, 1, 3, 0)
    indices = struct.pack("<3I", 0, 1, 2)
    vertices = b"".join(
        struct.pack("<8f", x, y, z, 0, 0, -1, u, v)
        for (x, y, z, u, v) in [
            (-0.8, -0.8, 0.0, 0.0, 0.0),
            (0.8, -0.8, 0.0, 1.0, 0.0),
            (0.0, 0.8, 0.0, 0.5, 1.0),
        ]
    )
    return bytes(header) + indices + vertices


def scene() -> bytes:
    doc = {
        "schema": "crazy-machines-original-scene-v1",
        "index": 1,
        "title": "CI synthetic 3D import smoke test",
        "scene_sha256": hashlib.sha256(b"ci-synthetic-scene-v1").hexdigest(),
        "root": {
            "name": "level",
            "fields": [],
            "children": [
                {
                    "name": "tmo_board",
                    "fields": ["POS 0, 0, 0"],
                    "position": [0.0, 0.0, 0.0],
                    "models": ["ci_test_triangle"],
                    "children": [],
                }
            ],
        },
    }
    return (json.dumps(doc, ensure_ascii=False, separators=(",", ":")) + "\n").encode()


def make_pack(output: Path) -> None:
    entries = {"ci_test_triangle.ucm": triangle_ucm(), "level-001.json": scene()}
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as out:
        out.write(b"CMASSET1")
        out.write(struct.pack("<I", len(entries)))
        for name, content in sorted(entries.items()):
            encoded = name.encode("utf-8")
            out.write(struct.pack("<H", len(encoded)))
            out.write(encoded)
            out.write(struct.pack("<I", len(content)))
            out.write(hashlib.sha256(content).digest())
            out.write(content)
    print(f"Generated non-proprietary CI fixture: {output} ({output.stat().st_size} bytes)")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    make_pack(args.output)


if __name__ == "__main__":
    main()
