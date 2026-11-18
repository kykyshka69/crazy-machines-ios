"""Asset-free regression tests for local-only original resource staging."""
import pathlib
import struct
import tempfile
import unittest
import zipfile

from stage_local_preview import stage


class StagePreviewTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name)
        self.archive = self.root / "fixtures.zip"
        self.model = b"UCM1" + bytes(88)
        # Uncompressed, 1x1, 24-bit TGA.
        self.texture = bytes([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 0, 24, 0, 0, 0, 255])
        with zipfile.ZipFile(self.archive, "w") as z:
            z.writestr("data/models/ball.ucm", self.model)
            z.writestr("data/textures/ball.tga", self.texture)

    def test_exact_bytes_and_original_name(self):
        out = self.root / "out"
        self.assertEqual(stage(self.archive, "data/models/ball.ucm", "data/textures/ball.tga", out),
                         (len(self.model), len(self.texture)))
        self.assertEqual((out / "sample.ucm").read_bytes(), self.model)
        self.assertEqual((out / "sample.tga").read_bytes(), self.texture)
        self.assertEqual((out / "sample_model_name.txt").read_text(), "data/models/ball.ucm\n")

    def test_rejects_traversal_before_writing(self):
        out = self.root / "out"
        with self.assertRaises(ValueError):
            stage(self.archive, "../data/models/ball.ucm", "data/textures/ball.tga", out)
        self.assertFalse(out.exists())

    def test_rejects_missing_texture_before_writing(self):
        out = self.root / "out"
        with self.assertRaises(ValueError):
            stage(self.archive, "data/models/ball.ucm", "missing.tga", out)
        self.assertFalse(out.exists())


if __name__ == "__main__":
    unittest.main()
