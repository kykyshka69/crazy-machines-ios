import unittest
from classify_puzzle_prefixes import classify_binary_prefixes


class PrefixGroupingTests(unittest.TestCase):
    def test_groups_preserve_original_level_indices(self):
        sections = [b"0" * 85 + b"ABCDEFGH", b"0" * 85 + b"abcdefgh",
                    b"0" * 85 + b"ABCDEFGH"]
        groups = classify_binary_prefixes(sections)
        self.assertEqual([g["count"] for g in groups], [2, 1])
        self.assertEqual(groups[0]["level_indices"], [1, 3])
        self.assertEqual(groups[1]["level_indices"], [2])

    def test_rejects_truncated_section(self):
        with self.assertRaises(ValueError):
            classify_binary_prefixes([b"0" * 85])


if __name__ == "__main__":
    unittest.main()
