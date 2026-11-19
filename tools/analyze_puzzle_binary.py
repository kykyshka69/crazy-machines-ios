"""Compare decrypted original puzzle binary sections without guessing object types.

Read-only analysis. No original assets are included in this repository.
"""


def longest_common_prefix(sections: list[bytes]) -> int:
    if not sections:
        return 0
    shortest = min(map(len, sections))
    for offset in range(shortest):
        first = sections[0][offset]
        if any(section[offset] != first for section in sections[1:]):
            return offset
    return shortest


def extract_binary_section(payload: bytes) -> bytes:
    if len(payload) < 4:
        raise ValueError("missing binary-section length")
    length = int.from_bytes(payload[:4], "little")
    if length > len(payload) - 4:
        raise ValueError("binary-section length exceeds decoded payload")
    return payload[4:4 + length]


def shared_binary_structure(payloads: list[bytes]) -> dict:
    sections = [extract_binary_section(payload) for payload in payloads]
    prefix = longest_common_prefix(sections)
    return {
        "puzzle_count": len(sections),
        "shared_prefix_bytes": prefix,
        "section_lengths": [len(section) for section in sections],
        "distinct_16_byte_chunks_at_0": len({section[:16] for section in sections}),
        "distinct_16_byte_chunks_at_80": len({
            section[80:96] for section in sections if len(section) >= 96
        }),
        "note": "shared bytes are an opaque header, not confirmed object records",
    }
