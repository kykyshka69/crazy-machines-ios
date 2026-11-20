#!/usr/bin/env python3
"""Extract an evidence-only object manifest for one authentic puzzle.

Run locally against a user-owned original Professor Laboratory CML.
No original level contents are committed to this repository.
"""
import argparse
import hashlib
import json
from pathlib import Path

from decode_professor_records import PROFESSOR_SHA256, read_professor_records
from decompress_original_level import decode_level_scene
from parse_original_scene import parse_scene


def manifest_for_record(record):
    root = parse_scene(decode_level_scene(record["payload"]))
    objects = []
    def visit(node, path):
        current = path + [node.name]
        if node.name.startswith("tmo_"):
            objects.append({
                "path": current,
                "type": node.name,
                "fields": list(node.fields),
                "models": [child.name[4:] for child in node.children
                           if child.name.startswith("3DO ")],
                "children": [child.name for child in node.children
                             if child.name.startswith("tmo_")],
                "goal_marker": node.first_field("GOAL"),
            })
        for child in node.children:
            visit(child, current)
    visit(root, [])
    return {
        "level": record["index"],
        "title": record["name"],
        "object_count": len(objects),
        "objects": objects,
        "note": "GOAL is an original annotation; its completion semantics are not inferred.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("professor_cml", type=Path)
    parser.add_argument("--level", type=int, default=1)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if not 1 <= args.level <= 102:
        parser.error("level must be in 1..102")
    data = args.professor_cml.read_bytes()
    if hashlib.sha256(data).hexdigest() != PROFESSOR_SHA256:
        parser.error("not the verified original Professor Laboratory CML")
    records = read_professor_records(data, include_payload=True)
    report = json.dumps(manifest_for_record(records[args.level - 1]),
                        ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(report, encoding="utf-8")
    else:
        print(report)


if __name__ == "__main__":
    main()
