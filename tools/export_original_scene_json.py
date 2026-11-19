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
    if node.name.startswith("tmo_"):
        position = node.first_field("POS")
        if position is not None:
            result["position"] = parse_vector3(position)
        rotation = node.first_field("ROT")
        if rotation is not None:
            result["rotation_raw"] = rotation
        relative_rotation = node.first_field("ROTREL")
        if relative_rotation is not None:
            result["rotation_relative_raw"] = relative_rotation
        result["models"] = [child.name[4:] for child in node.children
                            if child.name.startswith("3DO ")]
        goal = node.first_field("GOAL")
        if goal is not None:
            result["goal_raw"] = goal
    elif node.name == "level" or node.name.startswith("3DO ") or node.children:
        relative_position = node.first_field("POSREL")
        if relative_position is not None:
            result["position_relative"] = parse_vector3(relative_position)
        relative_rotation = node.first_field("ROTREL")
        if relative_rotation is not None:
            result["rotation_relative_raw"] = relative_rotation
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
