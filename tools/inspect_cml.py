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
    windows = []
    for offset in range(0, len(data), 4096):
        chunk = data[offset:offset + 4096]
        frequency = collections.Counter(chunk)
        e = -sum((n / len(chunk)) * math.log2(n / len(chunk)) for n in frequency.values())
        windows.append({
            "offset": offset,
            "length": len(chunk),
            "entropy_bits": round(e, 4),
            "zero_fraction": round(frequency[0] / len(chunk), 4),
        })
    return {
        "name": path.name,
        "bytes": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "first_64_bytes_hex": data[:64].hex(),
        "byte_entropy_bits": round(entropy, 4),
        "zero_bytes": counts[0],
        "windows_4k": windows,
        "known_signature_offsets": markers,
        "aligned_u32_first_32": [
            int.from_bytes(data[i:i + 4], "little")
            for i in range(0, min(len(data) - len(data) % 4, 128), 4)
        ],
    }



def compare(files: list[Path]) -> dict:
    """Locate byte-identical ranges shared by independent original CML files.

    Offsets are evidence of common headers/sections, not decoded level records.
    """
    if len(files) < 2:
        return {"shared_prefix_bytes": None, "shared_suffix_bytes": None,
                "equal_length": None, "differing_byte_ranges": []}
    blobs = [p.read_bytes() for p in files]
    minimum = min(map(len, blobs))
    prefix = 0
    while prefix < minimum and all(blob[prefix] == blobs[0][prefix] for blob in blobs[1:]):
        prefix += 1
    suffix = 0
    while suffix < minimum - prefix and all(
        blob[-1 - suffix] == blobs[0][-1 - suffix] for blob in blobs[1:]
    ):
        suffix += 1
    ranges = []
    start = None
    for offset in range(minimum):
        different = any(blob[offset] != blobs[0][offset] for blob in blobs[1:])
        if different and start is None:
            start = offset
        elif not different and start is not None:
            ranges.append({"start": start, "end_exclusive": offset})
            start = None
    if start is not None:
        ranges.append({"start": start, "end_exclusive": minimum})
    return {"shared_prefix_bytes": prefix, "shared_suffix_bytes": suffix,
            "equal_length": len(set(map(len, blobs))) == 1,
            "differing_byte_ranges": ranges}

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", type=Path, help="Original .cml files")
    parser.add_argument("--output", type=Path, help="Optional JSON report path")
    args = parser.parse_args()
    for path in args.files:
        if not path.is_file() or path.suffix.lower() != ".cml":
            parser.error(f"expected existing .cml file: {path}")
    report = {"format": "unresolved", "files": [inspect(p) for p in args.files],
              "cross_file_comparison": compare(args.files)}
    result = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(result + "\n", encoding="utf-8")
    else:
        print(result)


if __name__ == "__main__":
    main()
