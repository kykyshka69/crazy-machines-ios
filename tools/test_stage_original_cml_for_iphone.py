"""End-to-end synthetic framing test for private original-CML iPhone staging.

No Crazy Machines proprietary data. A 102-record laboratory is generated
using the recovered framing/LZW structure and a fake SHA injected only here.
"""
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import stage_original_cml_for_iphone as staging
from test_original_cml_frames import encode_original_frame
from test_decompress_original_level import pack_codes
from test_stage_original_first_level import synthetic_ucm


def make_synthetic_cml():
    def encode(data):
        return encode_original_frame(data)

    header = encode((102).to_bytes(4, "little")) + encode(bytes(80)) + encode(bytes(4))
    assert len(header) == 148
    data = bytearray(header + bytes(256-len(header)))
    for number in range(102):
        scene = ("level\r\n{\r\ntmo_board\r\n{\r\n"
                 "POS 1, 2, 3\r\n3DO to_board\r\n{\r\n}\r\n}\r\n}\r\n")
        packed = pack_codes(list(scene.encode("cp1251")) + [4095])
        payload = len(packed).to_bytes(4, "little") + packed
        name = f"Synthetic test {number + 1}".encode("cp1251").ljust(80, b"\0")
        data += encode(bytes([0]))
        data += encode(len(payload).to_bytes(4, "little"))
        data += encode(name)
        data += encode(payload)
    return bytes(data)


class NativeCMLStagingTest(unittest.TestCase):
    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.root = Path(self.work.name)
        self.cml = self.root / "Professor Laboratory.cml"
        self.synthetic = make_synthetic_cml()
        self.cml.write_bytes(self.synthetic)
        self.models = self.root / "models"
        self.models.mkdir()
        (self.models / "board.ucm").write_bytes(synthetic_ucm())
        self.output = self.root / "output"

    def stage(self):
        with patch.object(staging, "PROFESSOR_SHA256",
                          hashlib.sha256(self.synthetic).hexdigest()):
            return staging.stage_original_cml(self.cml, self.models, self.output)

    def test_native_import_must_create_json_itself(self):
        result = self.stage()
        self.assertTrue(result["native_ios_cml_decode_required"])
        self.assertEqual(result["verified_professor_record_count"], 102)
        self.assertEqual(result["original_ucm_files"], 1)
        self.assertFalse((self.output / "OriginalScenes" / "level-001.json").exists())
        self.assertEqual((self.output / "OriginalGame" / "Professor Laboratory.cml").read_bytes(),
                         self.synthetic)
        self.assertTrue((self.output / "OriginalGame" / "board.ucm").is_file())

    def test_invalid_original_hash_blocks_staging(self):
        with self.assertRaisesRegex(ValueError, "SHA256"):
            staging.stage_original_cml(self.cml, self.models, self.output)
        self.assertFalse(self.output.exists())

    def test_missing_first_level_model_blocks_staging(self):
        (self.models / "board.ucm").unlink()
        with self.assertRaisesRegex(ValueError, "missing"):
            self.stage()
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
