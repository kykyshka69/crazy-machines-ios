"""Lossless structured representation of decrypted original level scene trees.

The JSON is generated from user-supplied proprietary CML files and is
never bundled with the open-source iOS app. No game physics is inferred.
"""
import hashlib
import json
import re

from parse_original_scene import SceneNode, parse_scene

_VECTOR = re.compile(r"^\s*([-+]?\d+(?:\.\d*)?(?:[eE][-+]?\d+)?)\s*,\s*([-+]?\d+(?:\.\d*)?(?:[eE][-+]?\d+)?)\s*,\s*([-+]?\d+(?:\.\d*)?(?:[eE][-+]?\d+)?)\s*$")


def parse_vector3(value: str) -> list[float]:
    match = _VECTOR.fullmatch(value)
    if not match:
        raise ValueError(f"invalid original vector: {value!r}")
    return [float(number) for number in match.groups()]


def export_node(node: SceneNode) -> dict:
    fields = list(node.fields)
    result = {"name": node.name, "fields": fields,
              "children": [export_node(child) for child in node.children]}
    # Preserve transforms on every node: the original level uses POSREL
    # on nested model and background nodes, not just tmo_ objects.
    for field, key in (("POS", "position"), ("POSREL", "position_relative")):
        value = node.first_field(field)
        if value is not None:
            result[key] = parse_vector3(value)
    for field, key in (("ROT", "rotation_raw"), ("ROTREL", "rotation_relative_raw")):
        value = node.first_field(field)
        if value is not None:
            result[key] = value
    if node.name.startswith("tmo_"):
        result["models"] = [child.name[4:] for child in node.children
                            if child.name.startswith("3DO ")]
        goal = node.first_field("GOAL")
        if goal is not None:
            result["goal_raw"] = goal
    return result


def export_scene(scene: str, *, index: int, title: str) -> dict:
    if index < 1 or not title:
        raise ValueError("invalid original level identity")
    root = parse_scene(scene)
    return {
        "schema": "crazy-machines-original-scene-v1",
        "index": index,
        "title": title,
        "scene_sha256": hashlib.sha256(scene.encode("cp1251")).hexdigest(),
        "root": export_node(root),
    }


def to_json(document: dict) -> str:
    return json.dumps(document, ensure_ascii=False, separators=(",", ":"))
