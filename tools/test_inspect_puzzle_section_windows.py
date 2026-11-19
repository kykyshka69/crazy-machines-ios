import unittest

from inspect_puzzle_section_windows import (
    analyze_sections, common_prefix_length, first_difference,
    inspect_fixed_width_windows,
)


class WindowInspectionTests(unittest.TestCase):
    def test_first_difference_and_prefix(self):
        self.assertEqual(first_difference(b"abc123", b"abc456"), 3)
        self.assertEqual(first_difference(b"abc", b"abcdef"), 3)
        self.assertEqual(common_prefix_length([b"abc123", b"abc456"]), 3)
        self.assertEqual(common_prefix_length([]), 0)

    def test_window_frequencies(self):
        sections = [b"A" * 85 + b"xyz" + b"abc" * 9,
                    b"A" * 85 + b"xyz" + b"def" * 9,
                    b"A" * 85 + b"uvw" + b"def" * 9]
        result = analyze_sections(sections)
        self.assertEqual(result["common_prefix_bytes"], 85)
        self.assertEqual(result["three_byte_windows_after_prefix"][0]["distinct_values"], 2)
        self.assertEqual(result["three_byte_windows_after_prefix"][0]["most_common_frequency"], 2)

    def test_reject_truncated_section(self):
        with self.assertRaises(ValueError):
            inspect_fixed_width_windows([b"abc"], start=3, width=3, count=1)


if __name__ == "__main__":
    unittest.main()
