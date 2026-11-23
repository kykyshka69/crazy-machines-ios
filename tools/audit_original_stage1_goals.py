#!/usr/bin/env python3
"""Audit all 102 privately owned original PC levels, never publish assets.

    python3 tools/audit_original_stage1_goals.py path/to/CrazyMachines_Original_102Levels.cmassets

This validates original scene data, NOT iOS gameplay, Win32 parity, or
puzzle completion. Requires the owner-only CMASSET1 pack; none is in Git.
"""
import argparse
from collections import Counter, defaultdict
from hashlib import sha256
import json
from pathlib import Path
import struct


def read_pack(path: Path):
    blob = path.read_bytes()
    if blob[:8] != b"CMASSET1":
        raise ValueError("Expected owner-owned CMASSET1 archive")
    count = struct.unpack_from("<I", blob, 8)[0]
    pos, names, levels = 12, set(), {}
    for _ in range(count):
        if pos + 2 > len(blob):
            raise ValueError("Truncated name")
        n = struct.unpack_from("<H", blob, pos)[0]
        pos += 2
        if pos + n + 36 > len(blob):
            raise ValueError("Truncated resource header")
        name = blob[pos:pos+n].decode("utf-8")
        pos += n
        length = struct.unpack_from("<I", blob, pos)[0]
        pos += 4
        digest = blob[pos:pos+32]
        pos += 32
        content = blob[pos:pos+length]
        pos += length
        if name in names or len(content) != length or sha256(content).digest() != digest:
            raise ValueError("Duplicate, truncated, or invalid resource: " + name)
        names.add(name)
        if name.startswith("level-") and name.endswith(".json"):
            scene = json.loads(content)
            index = scene["index"]
            if name != f"level-{index:03d}.json" or index in levels:
                raise ValueError("Original scene index mismatch")
            levels[index] = scene
    if pos != len(blob) or len(names) != count:
        raise ValueError("Archive trailing bytes")
    if set(levels) != set(range(1, 103)):
        raise ValueError("Expected exactly the 102 real original level exports")
    return count, levels


def objects(node):
    if node["name"].startswith("tmo_"):
        yield node
    for child in node.get("children", []):
        yield from objects(child)


def audit(path: Path):
    count, levels = read_pack(path)
    goals, links, goal_levels = Counter(), 0, defaultdict(list)
    for index, scene in sorted(levels.items()):
        for obj in objects(scene["root"]):
            fields = obj.get("fields", [])
            marked = [value for value in fields if value.startswith("GOAL ")]
            if any(int(value.split()[1]) != 0 for value in marked):
                goals[obj["name"]] += 1
                goal_levels[obj["name"]].append(index)
            links += sum(value.startswith("CONNECTED_TO ") for value in fields)
    return {
        "integrity_verified_resources": count,
        "original_scene_count": len(levels),
        "original_goal_objects": sum(goals.values()),
        "original_goal_element_types": len(goals),
        "connected_to_records": links,
        "goal_objects_by_type": dict(sorted(goals.items())),
        "goal_level_indices_by_type": dict(sorted(goal_levels.items())),
        "disclaimer": "Source inventory only; no original level was run or solved on iOS.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", type=Path)
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    report = audit(args.pack)
    if args.json:
        print(json.dumps(report, indent=2))
    else:
        for k, v in report.items():
            if k not in ("goal_objects_by_type", "goal_level_indices_by_type"):
                print(f"{k}: {v}")
        for kind, count in sorted(report["goal_objects_by_type"].items(),
                                  key=lambda x: (-x[1], x[0])):
            print(f"  {kind}: {count}")


if __name__ == "__main__":
    main()
