#!/usr/bin/env python3
"""Reproduce observed CML structural anchors from user-owned original files.

No game data is emitted; only hashes, sizes, offsets and consistency checks.
"""
import argparse
import hashlib
import json
from pathlib import Path

EMPTY_SHA256 = "0b43d45a6dff72c4ce599787b13fedfd6a802d81e0bf405c8d3267dadc068be7"
PROFESSOR_SHA256 = "bd05d755d62a28abf7656d125fd6eec73c496ba6427d30341516da4f42124cc6"
PROLOGUE_TOKEN = bytes.fromhex("eb09478ab292fc01783929385b726218690c082e7eaa3ec4")
RECORD_CANDIDATE = bytes.fromhex("73ad8ff2aa7e34d120ed1170f36ebab831d09036b6")


def positions(data: bytes, token: bytes) -> list[int]:
    result = []
    start = 0
    while True:
        offset = data.find(token, start)
        if offset < 0:
            return result
        result.append(offset)
        start = offset + 1


def verify(empty: bytes, professor: bytes) -> dict:
    hashes = [hashlib.sha256(x).hexdigest() for x in (empty, professor)]
    if hashes != [EMPTY_SHA256, PROFESSOR_SHA256]:
        raise ValueError("input files do not match the two verified original CML hashes")
    empty_token = positions(empty, PROLOGUE_TOKEN)
    professor_token = positions(professor, PROLOGUE_TOKEN)
    boundaries = positions(professor, RECORD_CANDIDATE)
    checks = {
        "empty_bytes": len(empty) == 256,
        "professor_bytes": len(professor) == 330971,
        "prologue_token_empty": empty_token == [0, 124, 232],
        "prologue_token_professor": professor_token[:2] == [124, 232],
        "common_prologue_24_148": empty[24:148] == professor[24:148],
        "common_prologue_232_256": empty[232:256] == professor[232:256],
        "candidate_count": len(boundaries) == 102,
        "first_candidate_at_256": bool(boundaries) and boundaries[0] == 256,
        "last_candidate_at_327426": bool(boundaries) and boundaries[-1] == 327426,
    }
    return {
        "verified": all(checks.values()),
        "checks": checks,
        "empty_prologue_token_offsets": empty_token,
        "professor_prologue_token_offsets": professor_token,
        "professor_candidate_offsets": boundaries,
        "candidate_span_lengths": [
            end - start for start, end in
            zip(boundaries, boundaries[1:] + [len(professor)])
        ],
        "note": "candidate boundaries are not confirmed playable level records",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("empty_cml", type=Path)
    parser.add_argument("professor_cml", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        report = verify(args.empty_cml.read_bytes(), args.professor_cml.read_bytes())
    except (ValueError, OSError) as error:
        parser.error(str(error))
    serialized = json.dumps(report, indent=2)
    if args.output:
        args.output.write_text(serialized + "\n", encoding="utf-8")
    else:
        print(serialized)
    if not report["verified"]:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
