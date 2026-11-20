"""Synthetic tests for object-field inventory without game assets."""
import unittest
from unittest.mock import patch
from inventory_original_object_fields import inventory, field_keyword


class ObjectFieldInventoryTests(unittest.TestCase):
    def test_keyword(self):
        self.assertEqual(field_keyword("POS 1, 2, 3"), "POS")
        self.assertEqual(field_keyword("  GOAL 1"), "GOAL")
        self.assertEqual(field_keyword(""), "")

    def test_counts_fields_by_object_and_level(self):
        scene = """level
{
tmo_board
{
POS 1, 2, 3
GOAL 1
3DO to_board
{
}
}
tmo_board
{
POS 4, 5, 6
}
}
"""
        with patch("inventory_original_object_fields.decode_level_scene", return_value=scene):
            result = inventory([{"index": 1, "payload": b""}])
        board = result["object_types"][0]
        self.assertEqual(board["instances"], 2)
        self.assertEqual(board["level_count"], 1)
        self.assertEqual(board["field_frequencies"]["POS"], 2)
        self.assertEqual(board["field_frequencies"]["GOAL"], 1)
        self.assertEqual(board["child_type_frequencies"]["3DO to_board"], 1)
        self.assertEqual(result["level_fields"][0]["object_field_frequencies"]["POS"], 2)


if __name__ == "__main__":
    unittest.main()
