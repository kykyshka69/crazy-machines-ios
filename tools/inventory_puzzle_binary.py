#!/usr/bin/env python3
"""Inventory original Professor puzzle binary sections without exporting assets."""
import argparse
import hashlib
import json
from pathlib import Path

from decode_professor_records import PROFESSOR_SHA256, read_professor_records


def inventory(data: bytes) -> list[dict]:
    result = []
    for record in read_professor_records(data, include_payload=True):
        payload = record.pop("payload")
        if len(payload) < 12:
            raise ValueError(f"record {record['index']}: truncated puzzle")
        binary_length = int.from_bytes(payload[:4], "little")
        if binary_length > len(payload) - 12:
            raise ValueError(f"record {record['index']}: invalid binary length")
        binary_end = 4 + binary_length
        # This metadata is not yet interpreted as objects or coordinates.
        record["binary_section_start"] = 4
        record["binary_section_end_exclusive"] = binary_end
        record["binary_section_bytes"] = binary_length
        record["binary_section_sha256"] = hashlib.sha256(payload[4:binary_end]).hexdigest()
        record["following_section_bytes"] = len(payload) - binary_end
        record["following_section_prefix_hex"] = payload[binary_end:binary_end + 12].hex()
        result.append(record)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("professor_cml", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    data = args.professor_cml.read_bytes()
    if hashlib.sha256(data).hexdigest() != PROFESSOR_SHA256:
        parser.error("not the verified original Professor Laboratory file")
    result = inventory(data)
    output = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(output + "\n", encoding="utf-8")
    else:
        print(output)


if __name__ == "__main__":
    main()
