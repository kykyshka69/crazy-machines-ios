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



def text_candidates(data: bytes, minimum: int = 5, limit: int = 200) -> list[dict]:
    """Find offset-bearing printable ASCII and UTF-16LE strings, bounded in output."""
    results = []
    for stride, encoding, alignment in ((1, "ascii", 0), (2, "utf-16le", 0),
                                        (2, "utf-16le", 1)):
        start = None
        offset = alignment
        while offset + stride <= len(data):
            if stride == 1:
                value = data[offset]
                printable = 32 <= value <= 126
            else:
                value = data[offset]
                printable = 32 <= value <= 126 and data[offset + 1] == 0
            if printable and start is None:
                start = offset
            if not printable and start is not None:
                if (offset - start) // stride >= minimum:
                    results.append({"offset": start, "encoding": encoding,
                                    "text": data[start:offset].decode(encoding)})
                start = None
            offset += stride
        if start is not None and (offset - start) // stride >= minimum:
            results.append({"offset": start, "encoding": encoding,
                            "text": data[start:offset].decode(encoding)})
    unique = {(entry["offset"], entry["encoding"], entry["text"]): entry for entry in results}
    return sorted(unique.values(), key=lambda entry: (entry["offset"], entry["encoding"]))[:limit]



def repeated_signatures(data: bytes, width: int = 16, minimum_count: int = 3,
                        limit: int = 12) -> list[dict]:
    """Find frequent repeated fixed-width signatures with byte-exact offsets.

    Adjacent overlapping windows from the same repeated run are grouped by
    their offset tuples; only the earliest representative is reported.
    """
    from collections import defaultdict
    positions = defaultdict(list)
    for offset in range(max(0, len(data) - width + 1)):
        positions[data[offset:offset + width]].append(offset)
    groups = {}
    for signature, offsets in positions.items():
        if len(offsets) < minimum_count:
            continue
        key = tuple(offsets)
        candidate = {"signature_hex": signature.hex(), "count": len(offsets),
                     "offsets": offsets,
                     "min_gap": min(b - a for a, b in zip(offsets, offsets[1:])),
                     "max_gap": max(b - a for a, b in zip(offsets, offsets[1:]))}
        if key not in groups or candidate["signature_hex"] < groups[key]["signature_hex"]:
            groups[key] = candidate
    return sorted(groups.values(), key=lambda item: (-item["count"], item["offsets"][0]))[:limit]


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
        "text_candidates": text_candidates(data),
        "repeated_16_byte_signatures": repeated_signatures(data),
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


def discover(inputs: list[Path]) -> list[Path]:
    """Find original CML files in extracted installation trees, deterministically."""
    found = set()
    for item in inputs:
        if item.is_dir():
            for candidate in item.rglob("*"):
                if candidate.is_file() and candidate.suffix.lower() == ".cml":
                    found.add(candidate.resolve())
        elif item.is_file() and item.suffix.lower() == ".cml":
            found.add(item.resolve())
        else:
            raise ValueError(f"not a CML file or readable directory: {item}")
    if not found:
        raise ValueError("no CML files found in supplied paths")
    return sorted(found, key=str)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="+", type=Path, help="Original .cml files or extracted game directories")
    parser.add_argument("--output", type=Path, help="Optional JSON report path")
    args = parser.parse_args()
    try:
        files = discover(args.files)
    except ValueError as error:
        parser.error(str(error))
    report = {"format": "unresolved", "files": [inspect(p) for p in files],
              "cross_file_comparison": compare(files)}
    result = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(result + "\n", encoding="utf-8")
    else:
        print(result)


if __name__ == "__main__":
    main()
