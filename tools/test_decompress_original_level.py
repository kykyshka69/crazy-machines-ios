import unittest

from decompress_original_level import (
    unpack_12bit_codes, decompress_level_section, decode_level_scene
)


def pack_codes(codes):
    if len(codes) % 2:
        codes = codes + [0]
    result = bytearray()
    for a, b in zip(codes[::2], codes[1::2]):
        result.extend((a >> 4, ((a & 15) << 4) | (b >> 8), b & 255))
    return bytes(result)


class OriginalLevelDecompressionTests(unittest.TestCase):
    def test_big_endian_12bit_packing(self):
        self.assertEqual(list(unpack_12bit_codes(bytes.fromhex("06c065"))), [108, 101])

    def test_original_scene_prefix(self):
        # First original scene codes begin with the literal bytes 'level'.
        codes = [108, 101, 118, 101, 108, 13, 10, 123, 4095, 0]
        section = pack_codes(codes)
        self.assertEqual(decompress_level_section(section), b"level\r\n{")
        payload = len(section).to_bytes(4, "little") + section
        self.assertEqual(decode_level_scene(payload), "level\r\n{")

    def test_dictionary_references(self):
        # After A,B, dictionary code 256 expands to AB.
        self.assertEqual(decompress_level_section(pack_codes([65, 66, 256, 4095])), b"ABAB")

    def test_missing_end_marker(self):
        with self.assertRaises(ValueError):
            decompress_level_section(pack_codes([65, 66]))

    def test_invalid_dictionary_reference(self):
        with self.assertRaises(ValueError):
            decompress_level_section(pack_codes([65, 700, 4095, 0]))

    def test_ignores_padding_after_end(self):
        self.assertEqual(decompress_level_section(pack_codes([65, 4095, 1, 0])), b"A")


if __name__ == "__main__":
    unittest.main()
