#!/usr/bin/env python3
"""Report candidate CML record spans from an observed repeated header.

No level data is decoded, copied or published. This tool is read-only.
"""
import argparse
import hashlib
import json
from pathlib import Path

# Identical at all 102 observed candidate boundaries in the original
# Professor laboratory. The marker is evidence, not a proven record schema.
OBSERVED_HEADER = bytes.fromhex(
    "73ad8ff2aa7e34d120ed1170f36ebab831d09036b6"
)


def candidate_spans(data: bytes, marker: bytes = OBSERVED_HEADER) -> dict:
    if not marker:
        raise ValueError("marker must not be empty")
    offsets = []
    start = 0
    while True:
        offset = data.find(marker, start)
        if offset < 0:
            break
        offsets.append(offset)
        start = offset + 1
    spans = []
    for index, offset in enumerate(offsets):
        end = offsets[index + 1] if index + 1 < len(offsets) else len(data)
        span = data[offset:end]
        spans.append({
            "index": index,
            "start": offset,
            "end_exclusive": end,
            "length": len(span),
            "sha256": hashlib.sha256(span).hexdigest(),
        })
    return {
        "bytes": len(data),
        "file_sha256": hashlib.sha256(data).hexdigest(),
        "marker_hex": marker.hex(),
        "prologue_bytes": offsets[0] if offsets else None,
        "candidate_count": len(spans),
        "candidate_spans": spans,
        "interpretation": "opaque candidate spans, NOT decoded levels",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path, help="Locally extracted original CML")
    parser.add_argument("--output", type=Path, help="Optional JSON output")
    args = parser.parse_args()
    if not args.file.is_file() or args.file.suffix.lower() != ".cml":
        parser.error("expected an existing .cml file")
    report = json.dumps(candidate_spans(args.file.read_bytes()), indent=2)
    if args.output:
        args.output.write_text(report + "\n", encoding="utf-8")
    else:
        print(report)


if __name__ == "__main__":
    main()
