#!/usr/bin/env python3
"""Report authentic object types, transforms and goals from original levels.

Requires the user's own original Professor Laboratory CML. No original
scene text, model data, or level binaries are committed to the repo.
"""
import argparse
import collections
import hashlib
import json
import re
from pathlib import Path

from decode_professor_records import PROFESSOR_SHA256, read_professor_records
from decompress_original_level import decode_level_scene

OBJECT_RE = re.compile(r"^\s*(tmo_[A-Za-z0-9_]+)\s*$", re.MULTILINE)
POSITION_RE = re.compile(
    r"^\s*POS\s+([-+\d.eE]+),\s*([-+\d.eE]+),\s*([-+\d.eE]+)\s*$",
    re.MULTILINE,
)


def inspect_levels(data: bytes) -> dict:
    if hashlib.sha256(data).hexdigest() != PROFESSOR_SHA256:
        raise ValueError("not the verified original Professor Laboratory")
    records = read_professor_records(data, include_payload=True)
    types = collections.Counter()
    levels = []
    for record in records:
        scene = decode_level_scene(record["payload"])
        objects = OBJECT_RE.findall(scene)
        positions = POSITION_RE.findall(scene)
        types.update(objects)
        levels.append({
            "index": record["index"],
            "name": record["name"],
            "scene_text_bytes": len(scene.encode("cp1251")),
            "object_nodes": len(objects),
            "position_entries": len(positions),
            "goal_markers": scene.count("GOAL 1"),
            "scene_sha256": hashlib.sha256(scene.encode("cp1251")).hexdigest(),
        })
    return {
        "level_count": len(levels),
        "total_object_nodes": sum(level["object_nodes"] for level in levels),
        "total_position_entries": sum(level["position_entries"] for level in levels),
        "distinct_object_types": len(types),
        "object_type_frequencies": dict(types.most_common()),
        "levels": levels,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("professor_cml", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = inspect_levels(args.professor_cml.read_bytes())
    output = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(output, encoding="utf-8")
    else:
        print(output)


if __name__ == "__main__":
    main()
