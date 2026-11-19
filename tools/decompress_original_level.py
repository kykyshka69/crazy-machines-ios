"""Decode the original Crazy Machines inner level stream.

Verified on all 102 Professor Laboratory levels. The length-delimited
binary section is fixed-width, big-endian 12-bit LZW, terminated by
code 4095. The decompressed content is a textual level scene graph.
No original game data is bundled.
"""


def unpack_12bit_codes(data: bytes):
    if len(data) % 3:
        data += bytes(3 - len(data) % 3)
    for offset in range(0, len(data), 3):
        a, b, c = data[offset:offset + 3]
        yield (a << 4) | (b >> 4)
        yield ((b & 15) << 8) | c


def decompress_level_section(section: bytes) -> bytes:
    dictionary = {i: bytes((i,)) for i in range(256)}
    next_code = 256
    previous = b""
    output = bytearray()
    ended = False
    for code in unpack_12bit_codes(section):
        if ended:
            # Trailing bits after the terminator are padding, not LZW codes.
            continue
        if code == 4095:
            ended = True
            continue
        if code in dictionary:
            entry = dictionary[code]
        elif code == next_code and previous:
            entry = previous + previous[:1]
        else:
            raise ValueError(f"invalid LZW code {code} (next={next_code})")
        output.extend(entry)
        if previous and next_code < 4095:
            dictionary[next_code] = previous + entry[:1]
            next_code += 1
        previous = entry
    if not ended:
        raise ValueError("missing LZW end marker 4095")
    return bytes(output)


def decode_level_scene(payload: bytes) -> str:
    if len(payload) < 4:
        raise ValueError("missing level section length")
    length = int.from_bytes(payload[:4], "little")
    if length > len(payload) - 4:
        raise ValueError("level section exceeds payload")
    raw = decompress_level_section(payload[4:4 + length])
    text = raw.rstrip(b"\0").decode("cp1251")
    if not text.startswith("level\r\n{"):
        raise ValueError("not an original level scene graph")
    return text
