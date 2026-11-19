"""Regression tests for the original CML binary inspector (synthetic files only)."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from inspect_cml import inspect


class CMLInspectorTests(unittest.TestCase):
    def test_empty_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "empty.cml"
            path.write_bytes(b"")
            result = inspect(path)
            self.assertEqual(result["bytes"], 0)
            self.assertEqual(result["byte_entropy_bits"], 0)
            self.assertEqual(result["windows_4k"], [])
            self.assertEqual(result["aligned_u32_first_32"], [])

    def test_signature_and_block_boundaries(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "test.cml"
            path.write_bytes(b"UCM1" + b"\\x00" * 4092 + b"OggS" + b"\\xff" * 16)
            result = inspect(path)
            self.assertEqual(result["known_signature_offsets"][b"UCM1".hex()], [0])
            self.assertEqual(result["known_signature_offsets"][b"OggS".hex()], [4096])
            self.assertEqual([w["length"] for w in result["windows_4k"]], [4096, 20])
            self.assertEqual(result["aligned_u32_first_32"][0], 0x314D4355)

    def test_cli_json_report(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "sample.cml"
            output = Path(directory) / "report.json"
            source.write_bytes(b"\\x00" * 32)
            subprocess.run(
                [sys.executable, str(Path(__file__).with_name("inspect_cml.py")),
                 str(source), "--output", str(output)],
                check=True, capture_output=True, text=True
            )
            self.assertEqual(json.loads(output.read_text())["files"][0]["bytes"], 32)

    def test_cli_rejects_non_cml(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "sample.exe"
            source.write_bytes(b"data")
            process = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("inspect_cml.py")), str(source)],
                capture_output=True, text=True
            )
            self.assertNotEqual(process.returncode, 0)


if __name__ == "__main__":
    unittest.main()
