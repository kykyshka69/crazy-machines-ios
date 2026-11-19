import unittest
from analyze_puzzle_binary import extract_binary_section, longest_common_prefix, shared_binary_structure


class PuzzleBinaryTests(unittest.TestCase):
    def test_shared_prefix(self):
        self.assertEqual(longest_common_prefix([b"abcdef", b"abc123", b"abcd"]), 3)
        self.assertEqual(longest_common_prefix([]), 0)
        self.assertEqual(longest_common_prefix([b"abc"]), 3)

    def test_extract_section(self):
        self.assertEqual(extract_binary_section(b"\x03\x00\x00\x00abcTAIL"), b"abc")
        with self.assertRaises(ValueError):
            extract_binary_section(b"\x08\x00\x00\x00abc")

    def test_realistic_sections(self):
        prefix = b"z" * 85
        def payload(section):
            return len(section).to_bytes(4, "little") + section + b"tail"
        result = shared_binary_structure([
            payload(prefix + b"A" * 20),
            payload(prefix + b"B" * 20),
        ])
        self.assertEqual(result["shared_prefix_bytes"], 85)
        self.assertEqual(result["puzzle_count"], 2)
        self.assertEqual(result["distinct_16_byte_chunks_at_80"], 2)


if __name__ == "__main__":
    unittest.main()
