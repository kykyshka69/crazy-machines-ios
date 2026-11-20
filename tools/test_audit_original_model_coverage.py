"""Synthetic tests for original 3DO-to-UCM coverage audit."""
import unittest
from unittest.mock import patch

from audit_original_model_coverage import audit_models
from parse_original_scene import parse_scene


class ModelCoverageTests(unittest.TestCase):
    def test_reports_unresolved_models_and_usage(self):
        scene = """level
{
tmo_one
{
3DO to_board
{
}
3DO to_missing
{
}
}
tmo_two
{
3DO to_board
{
}
}
}
"""
        with patch("audit_original_model_coverage.decode_level_scene", return_value=scene):
            result = audit_models([{"index": 1, "payload": b""}], ["board"])
        self.assertEqual(result["unique_models"], 2)
        self.assertEqual(result["total_model_references"], 3)
        self.assertEqual(result["resolved_unique_models"], 1)
        self.assertEqual(result["unresolved_unique_models"], 1)
        self.assertEqual(result["unresolved_references"], 1)
        self.assertEqual(result["resolved"][0]["uses"], 2)
        self.assertEqual(result["unresolved"][0]["model"], "to_missing")

    def test_does_not_guess_non_prefixed_mapping(self):
        scene = "level\n{\n3DO board\n{\n}\n}\n"
        with patch("audit_original_model_coverage.decode_level_scene", return_value=scene):
            result = audit_models([{"index": 9, "payload": b""}], ["board"])
        self.assertEqual(result["unresolved_unique_models"], 1)
        self.assertEqual(result["unresolved"][0]["first_level"], 9)


if __name__ == "__main__":
    unittest.main()
