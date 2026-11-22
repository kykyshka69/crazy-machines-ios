"""Synthetic-only tests for private staging of the first real PC level."""
import json
from pathlib import Path
import struct
import tempfile
import unittest

from stage_original_first_level import model_base, original_references, stage


def synthetic_ucm():
    # A triangle that matches the known UCM1 v2 block structure.
    data = bytearray(92 + 12 + 3 * 32 + 8)
    data[:4] = b"UCM1"
    for offset, value in [(4, 2), (72, 1), (76, 1), (80, 3), (84, 0),
                          (92, 0), (96, 1), (100, 2)]:
        struct.pack_into("<I", data, offset, value)
    return bytes(data)


def scene(models=None):
    return {
        "schema": "crazy-machines-original-scene-v1",
        "index": 1,
        "title": "Test-only scene, NOT original game content",
        "scene_sha256": "f" * 64,
        "root": {
            "name": "level", "fields": [], "children": [{
                "name": "tmo_board", "fields": [],
                "models": ["to_board"] if models is None else models,
                "children": [{"name": "3DO to_board", "fields": [],
                              "children": []}]
            }]
        }
    }


class FirstLevelStagingTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.models = self.root / "models"
        self.models.mkdir()
        self.scene = self.root / "level-001.json"
        self.scene.write_text(json.dumps(scene()), encoding="utf-8")
        (self.models / "board.ucm").write_bytes(synthetic_ucm())
        self.output = self.root / "private-staging"

    def test_stages_real_format_without_duplicate_model(self):
        report = stage(self.scene, self.models, self.output)
        self.assertEqual(report["model_references"], 1)
        self.assertEqual(report["original_ucm_files"], 1)
        self.assertTrue((self.output / "OriginalGame" / "board.ucm").is_file())
        self.assertTrue((self.output / "OriginalScenes" / "level-001.json").is_file())
        self.assertFalse(report["original_gameplay_verified"])
        self.assertEqual(original_references(scene()["root"]), ["to_board"])

    def test_rejects_missing_ucm_before_writing(self):
        (self.models / "board.ucm").unlink()
        with self.assertRaisesRegex(ValueError, "missing"):
            stage(self.scene, self.models, self.output)
        self.assertFalse(self.output.exists())

    def test_rejects_corrupt_ucm_before_writing(self):
        (self.models / "board.ucm").write_bytes(b"not a mesh")
        with self.assertRaises(ValueError):
            stage(self.scene, self.models, self.output)
        self.assertFalse(self.output.exists())

    def test_rejects_second_level_json(self):
        doc = scene()
        doc["index"] = 2
        self.scene.write_text(json.dumps(doc), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "level 1"):
            stage(self.scene, self.models, self.output)

    def test_rejects_replacing_existing_staging(self):
        stage(self.scene, self.models, self.output)
        with self.assertRaisesRegex(ValueError, "must be empty"):
            stage(self.scene, self.models, self.output)

    def test_rejects_traversal_and_invalid_extensions(self):
        for ref in ("../board", "/board", "C:\\board", "board.png", "foo//board"):
            with self.subTest(ref=ref):
                with self.assertRaises(ValueError):
                    model_base(ref)

    def test_rejects_ambiguous_alias_names(self):
        (self.models / "BOARD.UCM").write_bytes(synthetic_ucm())
        with self.assertRaisesRegex(ValueError, "ambiguous"):
            stage(self.scene, self.models, self.output)

    def test_rejects_non_finite_vertex_component(self):
        data = bytearray(synthetic_ucm())
        # First vertex position at 92-byte header + 12-byte index array.
        struct.pack_into("<f", data, 104, float("nan"))
        (self.models / "board.ucm").write_bytes(data)
        with self.assertRaisesRegex(ValueError, "non-finite"):
            stage(self.scene, self.models, self.output)


if __name__ == "__main__":
    unittest.main()
