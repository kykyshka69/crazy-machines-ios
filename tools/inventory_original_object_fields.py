#!/usr/bin/env python3
"""Inventory original scene object fields to prioritize faithful mechanics.

Requires the user's own Professor CML. Reports field names and frequencies,
not proprietary values, source scenes, or guessed gameplay behavior.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path

from decode_professor_records import PROFESSOR_SHA256, read_professor_records
from decompress_original_level import decode_level_scene
from parse_original_scene import parse_scene


def field_keyword(line):
    return line.split(None, 1)[0] if line.strip() else ""


def inventory(records):
    by_type = {}
    per_level = []
    for record in records:
        root = parse_scene(decode_level_scene(record["payload"]))
        level_fields = collections.Counter()
        for node in root.walk():
            if not node.name.startswith("tmo_"):
                continue
            item = by_type.setdefault(node.name, {
                "instances": 0, "levels": set(), "fields": collections.Counter(),
                "child_types": collections.Counter(),
            })
            item["instances"] += 1
            item["levels"].add(record["index"])
            for line in node.fields:
                key = field_keyword(line)
                if key:
                    item["fields"][key] += 1
                    level_fields[key] += 1
            for child in node.children:
                item["child_types"][child.name] += 1
        per_level.append({
            "index": record["index"],
            "object_field_frequencies": dict(sorted(level_fields.items())),
        })
    types = []
    for name, info in by_type.items():
        types.append({
            "object_type": name,
            "instances": info["instances"],
            "level_count": len(info["levels"]),
            "first_level": min(info["levels"]),
            "field_frequencies": dict(sorted(info["fields"].items())),
            "child_type_frequencies": dict(sorted(info["child_types"].items())),
        })
    types.sort(key=lambda item: (-item["instances"], item["object_type"]))
    return {"object_types": types, "level_fields": per_level}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("professor_cml", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    data = args.professor_cml.read_bytes()
    if hashlib.sha256(data).hexdigest() != PROFESSOR_SHA256:
        parser.error("not the verified original Professor Laboratory CML")
    result = inventory(read_professor_records(data, include_payload=True))
    report = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(report, encoding="utf-8")
    else:
        print(report)


if __name__ == "__main__":
    main()
