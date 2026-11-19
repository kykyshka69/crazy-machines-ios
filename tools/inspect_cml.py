#!/usr/bin/env python3
"""Read-only structural inventory of original Crazy Machines CML files.

No proprietary level fields are guessed. Output contains offsets and statistics,
not game assets. Use with locally extracted, lawfully held installation files.
"""
import argparse
import collections
import hashlib
import json
import math
from pathlib import Path


def inspect(path: Path) -> dict:
    data = path.read_bytes()
    counts = collections.Counter(data)
    entropy = -sum((n / len(data)) * math.log2(n / len(data)) for n in counts.values()) if data else 0
    markers = {}
    for magic in (b"UCM1", b"OggS", b"RIFF", b"PK\x03\x04", b"MSCF"):
        found = []
        offset = 0
        while len(found) < 32:
            i = data.find(magic, offset)
            if i < 0:
                break
            found.append(i)
            offset = i + 1
        markers[magic.hex()] = found
    return {
        "name": path.name,
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "first_64_bytes_hex": data[:64].hex(),
        "byte_entropy_bits": round(entropy, 4),
        "zero_bytes": counts[0],
        "known_signature_offsets": markers,
        "aligned_u32_first_32": [
            int.from_bytes(data[i:i + 4], "little")
            for i in range(0, min(len(data) - len(data) % 4, 128), 4)
        ],
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", type=Path, help="Original .cml files")
    parser.add_argument("--output", type=Path, help="Optional JSON report path")
    args = parser.parse_args()
    for path in args.files:
        if not path.is_file() or path.suffix.lower() != ".cml":
            parser.error(f"expected existing .cml file: {path}")
    report = {"format": "unresolved", "files": [inspect(p) for p in args.files]}
    result = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(result + "\n", encoding="utf-8")
    else:
        print(result)


if __name__ == "__main__":
    main()
