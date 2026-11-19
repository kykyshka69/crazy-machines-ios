"""Read a verified instruction-text section from an original decoded puzzle.

This is a deliberately conservative parser: it only accepts the layout
observed in the first five original Professor Laboratory challenges.
Other challenges may include additional sections before their text.
"""


def read_simple_instruction(payload: bytes) -> dict:
    if len(payload) < 16:
        raise ValueError("truncated puzzle payload")
    section_size = int.from_bytes(payload[:4], "little")
    text_size_offset = section_size + 8
    if text_size_offset + 8 > len(payload):
        raise ValueError("first section extends beyond puzzle payload")
    text_size = int.from_bytes(payload[text_size_offset:text_size_offset + 4], "little")
    text_start = text_size_offset + 4
    text_end = text_start + text_size
    if text_end != len(payload) - 4:
        raise ValueError("additional puzzle sections or invalid text layout")
    raw = payload[text_start:text_end]
    if not raw or b"\x00" in raw:
        raise ValueError("invalid instruction text")
    return {
        "binary_section_bytes": section_size,
        "instruction_text": raw.decode("cp1251"),
        "instruction_bytes": text_size,
        "trailing_value": int.from_bytes(payload[-4:], "little"),
    }
