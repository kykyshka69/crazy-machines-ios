"""Classify authentic puzzle binary prefixes by exact byte equality.

Classes are *not* asserted to be object types or gameplay categories.
"""


def classify_binary_prefixes(sections: list[bytes], *, offset: int = 85, width: int = 8) -> list[dict]:
    if offset < 0 or width <= 0:
        raise ValueError("invalid offset or width")
    groups: dict[bytes, list[int]] = {}
    for index, section in enumerate(sections, start=1):
        if len(section) < offset + width:
            raise ValueError(f"section {index} too short for prefix")
        groups.setdefault(section[offset:offset + width], []).append(index)
    return [
        {"signature_hex": signature.hex(), "count": len(indices), "level_indices": indices}
        for signature, indices in sorted(groups.items(), key=lambda pair: pair[1][0])
    ]
