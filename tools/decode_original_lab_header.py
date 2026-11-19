#!/usr/bin/env python3
"""Verify actual first decoded fields from original user-owned CML files.

Does not embed, export, or redistribute original game data.
"""
import argparse
import hashlib
import json
from pathlib import Path

from cml_byte_transforms import ORIGINAL_LAB_KEY, decode_original_lab_field

KNOWN_SHA256 = {
    "empty": "0b43d45a6dff72c4ce599787b13fedfd6a802d81e0bf405c8d3267dadc068be7",
    "professor": "bd05d755d62a28abf7656d125fd6eec73c496ba6427d30341516da4f42124cc6",
}


def inspect_first_fields(data: bytes) -> dict:
    cursor = 0
    lengths = (4, 80, 4)
    fields = []
    for length in lengths:
        encoded_length = length + len(ORIGINAL_LAB_KEY)
        end = cursor + encoded_length
        if end > len(data):
            raise ValueError("truncated original laboratory header")
        decoded = decode_original_lab_field(data[cursor:end], payload_length=length)
        fields.append({
            "payload_bytes": length,
            "encoded_start": cursor,
            "encoded_end_exclusive": end,
            "decoded_hex": decoded.hex() if length == 4 else None,
            "decoded_sha256": hashlib.sha256(decoded).hexdigest(),
        })
        cursor = end
    return {
        "fields": fields,
        "record_count": int.from_bytes(
            decode_original_lab_field(data[:4 + len(ORIGINAL_LAB_KEY)], payload_length=4),
            "little",
        ),
        "next_encoded_offset": cursor,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("empty_cml", type=Path)
    parser.add_argument("professor_cml", type=Path)
    args = parser.parse_args()
    reports = {}
    for name, path in (("empty", args.empty_cml), ("professor", args.professor_cml)):
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != KNOWN_SHA256[name]:
            parser.error(f"{name} does not match the verified original file")
        reports[name] = inspect_first_fields(data)
    if reports["empty"]["record_count"] != 0:
        parser.error("empty laboratory record count must be zero")
    if reports["professor"]["record_count"] != 102:
        parser.error("professor laboratory expected 102 original records")
    print(json.dumps(reports, indent=2))


if __name__ == "__main__":
    main()
