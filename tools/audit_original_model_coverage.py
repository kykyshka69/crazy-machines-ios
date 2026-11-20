#!/usr/bin/env python3
"""Audit original 3DO model references against user-owned UCM assets.

Read-only. Never copies game meshes or decoded scenes into the repository.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path

from decode_professor_records import PROFESSOR_SHA256, read_professor_records
from decompress_original_level import decode_level_scene
from parse_original_scene import parse_scene


def audit_models(records, available_ucm_names):
    available = {name.casefold() for name in available_ucm_names}
    uses = collections.Counter()
    first_seen = {}
    level_uses = {}
    for record in records:
        root = parse_scene(decode_level_scene(record["payload"]))
        per_level = collections.Counter()
        for node in root.walk():
            if node.name.startswith("3DO "):
                model = node.name[4:].strip()
                uses[model] += 1
                per_level[model] += 1
                first_seen.setdefault(model, record["index"])
        level_uses[record["index"]] = per_level
    resolved, unresolved = [], []
    for model, count in sorted(uses.items(), key=lambda item: (-item[1], item[0])):
        # Only the observed original to_* -> *.ucm mapping is trusted.
        mapped = model[3:] if model.startswith("to_") else None
        entry = {"model": model, "uses": count, "first_level": first_seen[model]}
        if mapped is not None and mapped.casefold() in available:
            entry["ucm"] = mapped + ".ucm"
            resolved.append(entry)
        else:
            unresolved.append(entry)
    per_level_coverage = []
    for index, models in sorted(level_uses.items()):
        missing = sorted(
            (model for model in models
             if not (model.startswith("to_") and
                     model[3:].casefold() in available))
        )
        per_level_coverage.append({
            "index": index,
            "model_references": sum(models.values()),
            "unresolved_references": sum(models[name] for name in missing),
            "unresolved_models": missing,
        })
    return {
        "levels_with_all_models": sum(
            not item["unresolved_models"] for item in per_level_coverage
        ),
        "level_coverage": per_level_coverage,
        "unique_models": len(uses),
        "total_model_references": sum(uses.values()),
        "resolved_unique_models": len(resolved),
        "unresolved_unique_models": len(unresolved),
        "unresolved_references": sum(item["uses"] for item in unresolved),
        "resolved": resolved,
        "unresolved": unresolved,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("professor_cml", type=Path)
    parser.add_argument("ucm_directory", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if not args.ucm_directory.is_dir():
        parser.error("ucm_directory must be an existing directory")
    names = [p.stem for p in args.ucm_directory.rglob("*")
             if p.is_file() and p.suffix.lower() == ".ucm"]
    data = args.professor_cml.read_bytes()
    if hashlib.sha256(data).hexdigest() != PROFESSOR_SHA256:
        parser.error("not the verified original Professor Laboratory CML")
    records = read_professor_records(data, include_payload=True)
    result = audit_models(records, names)
    report = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(report, encoding="utf-8")
    else:
        print(report)


if __name__ == "__main__":
    main()
