"""Compare authentic puzzle binary sections without inferring object semantics.

All offsets are relative to the first byte after the section-length word.
"""


def first_difference(a: bytes, b: bytes) -> int:
    limit = min(len(a), len(b))
    for offset in range(limit):
        if a[offset] != b[offset]:
            return offset
    return limit


def common_prefix_length(sections: list[bytes]) -> int:
    if not sections:
        return 0
    shortest = min(sections, key=len)
    return min(first_difference(shortest, other) for other in sections)


def inspect_fixed_width_windows(sections: list[bytes], *, start: int, width: int, count: int) -> list[dict]:
    if start < 0 or width <= 0 or count < 0:
        raise ValueError("invalid window arguments")
    if not sections:
        return []
    results = []
    for index in range(count):
        offset = start + index * width
        if any(len(section) < offset + width for section in sections):
            raise ValueError(f"section shorter than requested window at {offset}")
        windows = [section[offset:offset + width] for section in sections]
        from collections import Counter
        frequencies = Counter(windows)
        results.append({
            "offset": offset,
            "width": width,
            "distinct_values": len(frequencies),
            "most_common_frequency": frequencies.most_common(1)[0][1],
        })
    return results


def analyze_sections(sections: list[bytes]) -> dict:
    return {
        "section_count": len(sections),
        "common_prefix_bytes": common_prefix_length(sections),
        "three_byte_windows_after_prefix": inspect_fixed_width_windows(
            sections, start=85, width=3, count=10
        ),
        "interpretation": "window widths are exploratory, not verified field boundaries",
    }
