"""Brace-aware parser for decrypted original Crazy Machines scene text.

Keeps original field strings and nested children intact; does not infer
physics or manufacture game objects. No copyrighted scenes are bundled.
"""
from dataclasses import dataclass, field


@dataclass
class SceneNode:
    name: str
    fields: list[str] = field(default_factory=list)
    children: list["SceneNode"] = field(default_factory=list)

    def walk(self):
        yield self
        for child in self.children:
            yield from child.walk()

    def first_field(self, keyword: str) -> str | None:
        prefix = keyword + " "
        for value in self.fields:
            if value == keyword:
                return ""
            if value.startswith(prefix):
                return value[len(prefix):]
        return None


def parse_scene(text: str) -> SceneNode:
    """Parse name/newline/{...} blocks and preserve scalar lines.

    Supports nested model nodes and attached items. Delimiters must be
    standalone lines, avoiding false positives inside scalar values.
    """
    lines = [(number, raw.strip()) for number, raw in enumerate(text.splitlines(), 1)
             if raw.strip()]
    if not lines:
        raise ValueError("empty scene")
    root = None
    stack: list[SceneNode] = []
    pending: tuple[int, str] | None = None
    for line_number, line in lines:
        if line == "{":
            if pending is None:
                raise ValueError(f"line {line_number}: opening brace without node name")
            node = SceneNode(pending[1])
            if stack:
                stack[-1].children.append(node)
            elif root is None:
                root = node
            else:
                raise ValueError(f"line {line_number}: multiple roots")
            stack.append(node)
            pending = None
        elif line == "}":
            if pending is not None:
                if not stack:
                    raise ValueError(f"line {line_number}: stray field outside root")
                stack[-1].fields.append(pending[1])
                pending = None
            if not stack:
                raise ValueError(f"line {line_number}: unmatched closing brace")
            stack.pop()
        else:
            if pending is not None:
                if not stack:
                    raise ValueError(f"line {line_number}: root missing opening brace")
                stack[-1].fields.append(pending[1])
            pending = (line_number, line)
    if pending is not None:
        if not stack:
            raise ValueError(f"line {pending[0]}: unbraced root")
        stack[-1].fields.append(pending[1])
    if stack:
        raise ValueError("unclosed scene node")
    if root is None or root.name != "level":
        raise ValueError("expected original level root")
    return root


def scene_summary(root: SceneNode) -> dict:
    if root.name != "level":
        raise ValueError("expected level root")
    objects = [node for node in root.walk() if node.name.startswith("tmo_")]
    return {
        "nodes_total": sum(1 for _ in root.walk()),
        "object_nodes": len(objects),
        "objects_with_position": sum(node.first_field("POS") is not None for node in objects),
        "objects_with_rotation": sum(node.first_field("ROT") is not None for node in objects),
        "objects_with_model": sum(any(child.name.startswith("3DO ") for child in node.children) for node in objects),
        "objects_with_goal": sum(node.first_field("GOAL") == "1" for node in objects),
        "object_types": sorted({node.name for node in objects}),
    }
