#!/usr/bin/env python3
"""Read all authentic Professor Laboratory records (no copyrighted data bundled).

The original Windows reader 0x47F9E0 reads a 1-byte flag, a 4-byte
payload length, an 80-byte CP1251 name and a variable-length payload.
Each field is individually framed with the recovered 20-byte key.
"""
import argparse
import hashlib
import json
from pathlib import Path

from cml_byte_transforms import ORIGINAL_LAB_KEY, decode_original_lab_field

PROFESSOR_SHA256 = "bd05d755d62a28abf7656d125fd6eec73c496ba6427d30341516da4f42124cc6"


def read_professor_records(data: bytes, *, expected_count: int = 102) -> list[dict]:
    offset = 256
    records = []

    def read_field(size: int) -> bytes:
        nonlocal offset
        if size < 0 or size > len(data) - offset - len(ORIGINAL_LAB_KEY):
            raise ValueError(f"truncated original CML field at offset {offset}")
        end = offset + size + len(ORIGINAL_LAB_KEY)
        decoded = decode_original_lab_field(data[offset:end], payload_length=size)
        offset = end
        return decoded

    for index in range(expected_count):
        start = offset
        flag = read_field(1)[0]
        payload_length = int.from_bytes(read_field(4), "little")
        name_bytes = read_field(80)
        name = name_bytes.split(b"\0", 1)[0].decode("cp1251")
        payload = read_field(payload_length)
        records.append({
            "index": index + 1,
            "name": name,
            "flag": flag,
            "start": start,
            "end_exclusive": offset,
            "payload_length": payload_length,
            "payload_sha256": hashlib.sha256(payload).hexdigest(),
        })
    if offset != len(data):
        raise ValueError(f"trailing bytes after {expected_count} records: {len(data)-offset}")
    return records


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("professor_cml", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    data = args.professor_cml.read_bytes()
    if hashlib.sha256(data).hexdigest() != PROFESSOR_SHA256:
        parser.error("not the verified original Professor Laboratory CML")
    records = read_professor_records(data)
    if args.json:
        print(json.dumps(records, ensure_ascii=False, indent=2))
    else:
        for record in records:
            print(f"{record['index']:3d}. {record['name']} ({record['payload_length']} bytes)")


if __name__ == "__main__":
    main()
