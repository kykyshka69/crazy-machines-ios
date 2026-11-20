"""Synthetic verification of exact original puzzle object manifest."""
import unittest
from unittest.mock import patch
from inspect_original_level_objects import manifest_for_record


class OriginalLevelManifestTests(unittest.TestCase):
    def test_nested_objects_and_goal_values(self):
        scene = """level
{
tmo_board
{
POS 1, 2, 3
3DO to_board
{
}
tmo_mount_bar
{
GOAL 1
3DO to_bar
{
}
}
}
}
"""
        record = {"index": 1, "name": "Test", "payload": b""}
        with patch("inspect_original_level_objects.decode_level_scene", return_value=scene):
            result = manifest_for_record(record)
        self.assertEqual(result["object_count"], 2)
        self.assertEqual(result["objects"][0]["models"], ["to_board"])
        self.assertEqual(result["objects"][0]["children"], ["tmo_mount_bar"])
        self.assertEqual(result["objects"][1]["goal_marker"], "1")
        self.assertEqual(result["objects"][1]["path"],
                         ["level", "tmo_board", "tmo_mount_bar"])


if __name__ == "__main__":
    unittest.main()
