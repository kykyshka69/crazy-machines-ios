"""Regression tests for original-scene audit: no invented game behavior."""
import unittest

from audit_original_scene_json import audit


class AuditOriginalSceneTests(unittest.TestCase):
    def setUp(self):
        self.document = {
            "schema": "crazy-machines-original-scene-v1",
            "index": 1,
            "scene_sha256": "test-scene",
            "root": {
                "name": "level", "fields": [], "children": [
                    {"name": "tmo_test", "fields": ["POS 1,2,3", "GOAL 1", "MASS 5"],
                     "models": ["to_test"], "position": [1, 2, 3],
                     "goal_raw": "1", "children": [
                         {"name": "3DO to_test", "fields": ["POSREL 0,1,0"],
                          "position_relative": [0, 1, 0], "children": []}
                     ]},
                    {"name": "tmo_empty", "fields": ["ROT 1,0,0"],
                     "rotation_raw": "1,0,0", "models": [], "children": []}
                ]
            }
        }

    def test_original_counts(self):
        result = audit(self.document)
        self.assertEqual(result["counts"]["original_objects"], 2)
        self.assertEqual(result["counts"]["goal_annotations"], 1)
        self.assertEqual(result["counts"]["objects_without_position"], 1)
        self.assertEqual(result["counts"]["position_relative"], 1)

    def test_original_fields_and_models(self):
        result = audit(self.document)
        self.assertEqual(result["object_fields_by_type"]["tmo_test"]["MASS"], 1)
        self.assertEqual(result["referenced_original_models"]["to_test"], 1)
        self.assertEqual(len(result["objects_without_direct_model_reference"]), 1)
        self.assertFalse(result["original_victory_condition_verified"])

    def test_invalid_schema_rejected(self):
        self.document["schema"] = "invented-scene"
        with self.assertRaises(ValueError):
            audit(self.document)

    def test_missing_root_rejected(self):
        self.document["root"] = {"name": "invented", "children": []}
        with self.assertRaises(ValueError):
            audit(self.document)


if __name__ == "__main__":
    unittest.main()
