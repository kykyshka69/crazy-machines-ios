#!/usr/bin/env python3
"""Inventory original Professor puzzle binary sections without exporting assets."""
import argparse
import hashlib
import json
from pathlib import Path

from decode_professor_records import PROFESSOR_SHA256, read_professor_records
from analyze_puzzle_binary import shared_binary_structure, extract_binary_section
from inspect_puzzle_section_windows import analyze_sections
from classify_puzzle_prefixes import classify_binary_prefixes


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
    parser.add_argument("--shared-structure", action="store_true", help="report common binary section structure only")
    parser.add_argument("--window-analysis", action="store_true", help="compare first varying binary bytes without exporting game assets")
    parser.add_argument("--prefix-groups", action="store_true", help="group levels by eight bytes following shared header")
    args = parser.parse_args()
    data = args.professor_cml.read_bytes()
    if hashlib.sha256(data).hexdigest() != PROFESSOR_SHA256:
        parser.error("not the verified original Professor Laboratory file")
    if args.prefix_groups:
        result = classify_binary_prefixes([extract_binary_section(r["payload"]) for r in read_professor_records(data, include_payload=True)])
    elif args.window_analysis:
        result = analyze_sections([extract_binary_section(r["payload"]) for r in read_professor_records(data, include_payload=True)])
    elif args.shared_structure:
        result = shared_binary_structure([r["payload"] for r in read_professor_records(data, include_payload=True)])
    else:
        result = inventory(data)
    output = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        args.output.write_text(output + "\n", encoding="utf-8")
    else:
        print(output)


if __name__ == "__main__":
    main()
