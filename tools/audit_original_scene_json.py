#!/usr/bin/env python3
"""Audit the exact original level data used by the iOS importer.

Reads user-exported scene JSON. Never infers mechanics or generates substitute
objects. Reports field and transform coverage to guide faithful porting.
"""
import argparse
import collections
import json
from pathlib import Path


def audit(document):
    if document.get("schema") != "crazy-machines-original-scene-v1":
        raise ValueError("unsupported original scene schema")
    root = document.get("root")
    if not isinstance(root, dict) or root.get("name") != "level":
        raise ValueError("missing original level root")
    counts = collections.Counter()
    field_counts = collections.Counter()
    object_types = collections.Counter()
    missing_models = []
    model_references = collections.Counter()
    original_object_fields = collections.defaultdict(collections.Counter)
    stack = [(root, "level")]
    while stack:
        node, path = stack.pop()
        counts["nodes"] += 1
        name = node.get("name", "")
        if name.startswith("tmo_"):
            counts["original_objects"] += 1
            object_types[name] += 1
            models = node.get("models", [])
            if not models:
                missing_models.append(path)
            for model in models:
                model_references[model] += 1
            if "position" not in node:
                counts["objects_without_position"] += 1
            if "goal_raw" in node:
                counts["goal_annotations"] += 1
        for key in ("position", "position_relative", "rotation_raw",
                    "rotation_relative_raw"):
            if key in node:
                counts[key] += 1
        for field in node.get("fields", []):
            if field.strip():
                keyword = field.split(None, 1)[0]
                field_counts[keyword] += 1
                if name.startswith("tmo_"):
                    original_object_fields[name][keyword] += 1
        for index, child in reversed(list(enumerate(node.get("children", [])))):
            stack.append((child, f"{path}/{index}:{child.get('name', '')}"))
    return {
        "level_index": document.get("index"),
        "scene_sha256": document.get("scene_sha256"),
        "counts": dict(sorted(counts.items())),
        "original_object_types": dict(sorted(object_types.items())),
        "original_field_keywords": dict(sorted(field_counts.items())),
        "object_fields_by_type": {
            name: dict(sorted(fields.items()))
            for name, fields in sorted(original_object_fields.items())
        },
        "referenced_original_models": dict(sorted(model_references.items())),
        "objects_without_direct_model_reference": missing_models,
        "original_victory_condition_verified": False,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scene_json", type=Path, nargs="+")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    reports = [audit(json.loads(path.read_text(encoding="utf-8")))
               for path in args.scene_json]
    result = json.dumps(reports, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(result, encoding="utf-8")
    else:
        print(result, end="")


if __name__ == "__main__":
    main()
