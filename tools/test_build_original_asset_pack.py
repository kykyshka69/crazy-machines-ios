"""Portable checks for the user's private CML-only and JSON asset pack modes.

Synthetic tiny payloads only. No PC game resources are included.
"""
import tempfile
import unittest
from pathlib import Path

from build_original_asset_pack import build, verify


class OriginalAssetPackBuildTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.game = self.root / "original"
        self.scenes = self.root / "scenes"
        self.game.mkdir()
        self.scenes.mkdir()
        for i in range(160):
            (self.game / f"model{i:03}.ucm").write_bytes(b"UCM1" + bytes([i]))
        for i in range(181):
            (self.game / f"texture{i:03}.tga").write_bytes(b"TGA" + bytes([i]))
        (self.game / "professor.cml").write_bytes(b"professor-lab")
        (self.game / "empty.cml").write_bytes(b"empty-lab")

    def test_original_cml_only_pack_without_json_exports(self):
        output = self.root / "cml-only.cmassets"
        result = build(self.game, None, output)
        self.assertEqual(result["entries"], 343)
        self.assertEqual(result["types"], {".ucm": 160, ".tga": 181, ".cml": 2})
        verify(output)

    def test_original_pack_with_102_preexported_scenes(self):
        for i in range(1, 103):
            (self.scenes / f"level-{i:03}.json").write_text('{"index":1}')
        output = self.root / "preexported.cmassets"
        result = build(self.game, self.scenes, output)
        self.assertEqual(result["entries"], 445)
        self.assertEqual(result["types"][".json"], 102)
        verify(output)

    def test_named_sound_resources_are_optional(self):
        fx = self.game / "data" / "sounds" / "fx"
        fx.mkdir(parents=True)
        (fx / "spring.wav").write_bytes(b"synthetic wave")
        scripts = self.game / "scripts" / "sound"
        scripts.mkdir(parents=True)
        (scripts / "soundfx.vsc").write_bytes(b"synthetic script")
        (self.game / "anonymous.wav").write_bytes(b"unidentified")
        output = self.root / "named-sound.cmassets"
        result = build(self.game, None, output)
        self.assertEqual(result["entries"], 345)
        self.assertEqual(result["types"][".wav"], 1)
        self.assertEqual(result["types"][".vsc"], 1)
        verify(output)

    def test_export_count_remains_strict(self):
        (self.scenes / "level-001.json").write_text("{}")
        with self.assertRaisesRegex(ValueError, "Unexpected resource count"):
            build(self.game, self.scenes, self.root / "bad.cmassets")


if __name__ == "__main__":
    unittest.main()
