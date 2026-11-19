#!/usr/bin/env python3
"""Fail-closed validation of the proposed CML decoder on original files.

A successful parse is not sufficient: require the original key prefix
for every framed field. Do not claim real levels decoded unless this
tool exits successfully with a user-owned original file.
"""
import argparse
import hashlib
from pathlib import Path

from cml_byte_transforms import ORIGINAL_LAB_KEY, decode_original_lab_field

ORIGINAL_HASHES = {
    "empty": "0b43d45a6dff72c4ce599787b13fedfd6a802d81e0bf405c8d3267dadc068be7",
    "professor": "bd05d755d62a28abf7656d125fd6eec73c496ba6427d30341516da4f42124cc6",
}


def verify_first_field(data: bytes, kind: str) -> int:
    actual = hashlib.sha256(data).hexdigest()
    if actual != ORIGINAL_HASHES[kind]:
        raise ValueError(f"{kind}: original SHA-256 mismatch")
    expected_size = 4 + len(ORIGINAL_LAB_KEY)
    if len(data) < expected_size:
        raise ValueError(f"{kind}: truncated first frame")
    payload = decode_original_lab_field(data[:expected_size], payload_length=4)
    count = int.from_bytes(payload, "little")
    expected_count = 0 if kind == "empty" else 102
    if count != expected_count:
        raise ValueError(f"{kind}: decoded count {count} != expected {expected_count}")
    return count


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("empty_cml", type=Path)
    parser.add_argument("professor_cml", type=Path)
    args = parser.parse_args()
    for kind, path in (("empty", args.empty_cml), ("professor", args.professor_cml)):
        try:
            count = verify_first_field(path.read_bytes(), kind)
        except (OSError, ValueError) as error:
            parser.error(str(error))
        print(f"{kind}: authenticated first field, record count={count}")


if __name__ == "__main__":
    main()
