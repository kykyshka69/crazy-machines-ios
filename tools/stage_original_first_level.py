#!/usr/bin/env python3
"""Privately stage a real original Crazy Machines first level for iOS Simulator.

This program NEVER generates substitute geometry or commits game resources.
Give it a first-level JSON exported by the repository tools and the directory
containing your legally acquired original UCM files.
"""
import argparse
import json
import math
from pathlib import Path
import shutil
import struct

from ucm_parser import parse as parse_ucm


def original_references(root):
    """Visit the original tree and de-duplicate explicit and metadata 3DOs."""
    stack = [root]
    references = []
    seen = set()
    while stack:
        node = stack.pop()
        if not isinstance(node, dict):
            raise ValueError("invalid original scene node")
        name = node.get("name", "")
        if not isinstance(name, str):
            raise ValueError("invalid node name")
        found = []
        if name.startswith("3DO "):
            found.append(name[4:])
        if name.startswith("tmo_"):
            found.extend(node.get("models", []))
        for value in found:
            if not isinstance(value, str) or not value:
                raise ValueError("invalid original 3D reference")
            if value.casefold() not in seen:
                seen.add(value.casefold())
                references.append(value)
        children = node.get("children", [])
        if not isinstance(children, list):
            raise ValueError("invalid original scene children")
        stack.extend(reversed(children))
    return references


def model_base(reference):
    """Follow the same conservative filename and to_ alias rules as iOS."""
    normalized = reference.replace("\\", "/")
    pieces = normalized.split("/")
    if (normalized.startswith("/") or ":" in normalized
            or any(p in ("", ".", "..") for p in pieces)
            or any(ord(ch) < 32 for ch in normalized)):
        raise ValueError("unsafe original model reference: " + repr(reference))
    filename = pieces[-1]
    if "." in filename:
        if not filename.lower().endswith(".ucm"):
            raise ValueError("unsupported original model suffix: " + repr(reference))
        base = filename[:-4]
    else:
        base = filename
    if not base:
        raise ValueError("empty original model name")
    return base.casefold()


def check_ucm(path):
    size = path.stat().st_size
    if not 0 < size <= 64 * 1024 * 1024:
        raise ValueError("UCM exceeds the iOS import limit: " + path.name)
    data = path.read_bytes()
    info = parse_ucm(data)
    groups = info["groups"]
    vertices_per_group = info["vertices_per_group"]
    faces = info["faces"]
    count = groups * vertices_per_group
    if not (0 < groups <= 10000 and 0 < vertices_per_group <= 100000
            and 0 < faces <= 1000000 and count <= 65536):
        raise ValueError("unrenderable UCM vertex or triangle count: " + path.name)
    # Swift/Metal currently uses 16-bit vertex indices.
    if max(struct.unpack_from("<" + str(faces * 3) + "I", data, 92)) > 65535:
        raise ValueError("UCM needs unsupported 32-bit indices: " + path.name)
    start = 92 + faces * 12
    for offset in range(start, start + count * 32, 32):
        if not all(math.isfinite(v) for v in struct.unpack_from("<8f", data, offset)):
            raise ValueError("UCM contains non-finite vertex attributes: " + path.name)
    return info


def stage(scene_json, ucm_directory, output_dir):
    scene_json = Path(scene_json)
    ucm_directory = Path(ucm_directory)
    output_dir = Path(output_dir)
    if not ucm_directory.is_dir():
        raise ValueError("original UCM directory does not exist")
    if not scene_json.is_file() or scene_json.stat().st_size > 8_000_000:
        raise ValueError("missing or oversized original scene JSON")
    document = json.loads(scene_json.read_text(encoding="utf-8"))
    if (document.get("schema") != "crazy-machines-original-scene-v1"
            or document.get("index") != 1
            or not isinstance(document.get("root"), dict)
            or document["root"].get("name") != "level"):
        raise ValueError("the supplied scene is not the original level 1 JSON")
    sha = document.get("scene_sha256")
    if not isinstance(sha, str) or len(sha) != 64 or any(
            ch not in "0123456789abcdefABCDEF" for ch in sha):
        raise ValueError("missing original scene SHA-256 metadata")
    references = original_references(document["root"])
    if not references:
        raise ValueError("first level has no original 3D references")

    catalog = {}
    for file in ucm_directory.rglob("*"):
        if file.is_file() and file.suffix.casefold() == ".ucm":
            catalog.setdefault(file.stem.casefold(), []).append(file)

    selected = {}
    missing = []
    for ref in references:
        base = model_base(ref)
        matches = catalog.get(base, [])
        if not matches and base.startswith("to_") and len(base) > 3:
            matches = catalog.get(base[3:], [])
        if len(matches) > 1:
            raise ValueError("ambiguous UCM filenames for " + ref)
        if not matches:
            missing.append(ref)
        else:
            selected[ref] = matches[0]
    if missing:
        raise ValueError("original UCM files missing: " + ", ".join(missing[:20]))
    unique_files = {file.resolve() for file in selected.values()}
    used_names = set()
    for path in unique_files:
        key = path.name.casefold()
        if key in used_names:
            raise ValueError("duplicate UCM destination basename: " + path.name)
        used_names.add(key)
        check_ucm(path)

    if output_dir.exists() and any(output_dir.iterdir()):
        raise ValueError("staging directory must be empty: " + str(output_dir))
    levels = output_dir / "OriginalScenes"
    models = output_dir / "OriginalGame"
    levels.mkdir(parents=True, exist_ok=True)
    models.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(scene_json, levels / "level-001.json")
    for path in unique_files:
        shutil.copyfile(path, models / path.name)
    report = {
        "original_level": 1,
        "scene_sha256": sha,
        "model_references": len(references),
        "original_ucm_files": len(unique_files),
        "staging_directory": str(output_dir.resolve()),
        "original_geometry_verified": True,
        "original_gameplay_verified": False,
    }
    (output_dir / "staging-report.json").write_text(
        json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scene_json", type=Path,
                        help="real exported original level-001.json")
    parser.add_argument("ucm_directory", type=Path,
                        help="directory containing original PC .ucm files")
    parser.add_argument("--output-dir", type=Path, required=True,
                        help="empty private staging directory OUTSIDE the repository")
    args = parser.parse_args()
    try:
        report = stage(args.scene_json, args.ucm_directory, args.output_dir)
    except (OSError, ValueError, KeyError, TypeError, struct.error) as error:
        parser.exit(2, "Cannot stage the original level: " + str(error) + "\n")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
