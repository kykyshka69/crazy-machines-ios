#!/usr/bin/env python3
"""Validate every original CML frame; original assets stay outside the repo."""
import argparse
import hashlib
import json
from pathlib import Path

from cml_byte_transforms import ORIGINAL_LAB_KEY, decode_original_lab_field
from decode_professor_records import PROFESSOR_SHA256, read_professor_records

EMPTY_SHA256 = "0b43d45a6dff72c4ce599787b13fedfd6a802d81e0bf405c8d3267dadc068be7"


def validate_original_files(empty: bytes, professor: bytes) -> dict:
    if hashlib.sha256(empty).hexdigest() != EMPTY_SHA256:
        raise ValueError("empty laboratory SHA-256 mismatch")
    if hashlib.sha256(professor).hexdigest() != PROFESSOR_SHA256:
        raise ValueError("Professor laboratory SHA-256 mismatch")

    def first_count(data: bytes) -> int:
        frame = data[:4 + len(ORIGINAL_LAB_KEY)]
        return int.from_bytes(decode_original_lab_field(frame, payload_length=4), "little")

    if first_count(empty) != 0:
        raise ValueError("empty laboratory must contain zero records")
    if first_count(professor) != 102:
        raise ValueError("Professor laboratory must contain 102 records")
    records = read_professor_records(professor, expected_count=102)
    if len(records) != 102 or records[0]["start"] != 256:
        raise ValueError("invalid record count or start")
    for previous, following in zip(records, records[1:]):
        if previous["end_exclusive"] != following["start"]:
            raise ValueError("gap or overlap in original records")
    if records[-1]["end_exclusive"] != len(professor):
        raise ValueError("last record does not reach file end")
    return {
        "verified": True,
        "empty_record_count": 0,
        "professor_record_count": len(records),
        "first_original_title": records[0]["name"],
        "last_original_title": records[-1]["name"],
        "last_offset": records[-1]["end_exclusive"],
        "authenticated_record_fields": len(records) * 4,
        "note": "object coordinates and gameplay logic are not yet parsed",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("empty_cml", type=Path)
    parser.add_argument("professor_cml", type=Path)
    args = parser.parse_args()
    try:
        report = validate_original_files(
            args.empty_cml.read_bytes(), args.professor_cml.read_bytes()
        )
    except (ValueError, OSError) as error:
        parser.error(str(error))
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
