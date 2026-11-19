"""Regression tests for the original CML binary inspector (synthetic files only)."""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from inspect_cml import inspect, compare, text_candidates, discover, repeated_signatures


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
            path.write_bytes(b"UCM1" + b"\x00" * 4092 + b"OggS" + b"\xff" * 16)
            result = inspect(path)
            self.assertEqual(result["known_signature_offsets"][b"UCM1".hex()], [0])
            self.assertEqual(result["known_signature_offsets"][b"OggS".hex()], [4096])
            self.assertEqual([w["length"] for w in result["windows_4k"]], [4096, 20])
            self.assertEqual(result["aligned_u32_first_32"][0], 0x314D4355)

    def test_cross_file_differences(self):
        with tempfile.TemporaryDirectory() as directory:
            a = Path(directory) / "a.cml"
            b = Path(directory) / "b.cml"
            a.write_bytes(b"HEAD" + b"123" + b"TAIL")
            b.write_bytes(b"HEAD" + b"xyz" + b"TAIL")
            result = compare([a, b])
            self.assertEqual(result["shared_prefix_bytes"], 4)
            self.assertEqual(result["shared_suffix_bytes"], 4)
            self.assertTrue(result["equal_length"])
            self.assertEqual(result["differing_byte_ranges"],
                             [{"start": 4, "end_exclusive": 7}])

    def test_single_file_comparison_is_undefined(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "a.cml"
            path.write_bytes(b"1234")
            self.assertIsNone(compare([path])["shared_prefix_bytes"])

    def test_text_clues_with_offsets_and_alignment(self):
        payload = b"prefix\x00" + "LEVELNAME".encode("utf-16le") + b"\x00\x00" + b"OBJFILE"
        clues = text_candidates(payload)
        self.assertTrue(any(c["offset"] == 7 and c["encoding"] == "utf-16le"
                            and c["text"] == "LEVELNAME" for c in clues))
        self.assertTrue(any(c["encoding"] == "ascii" and c["text"] == "OBJFILE"
                            for c in clues))

    def test_text_clue_limit(self):
        data = b"FIRST\x00SECOND\x00THIRD"
        self.assertEqual(len(text_candidates(data, limit=2)), 2)

    def test_directory_discovery(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            nested = root / "laboratories"
            nested.mkdir()
            first = nested / "Professor.CML"
            second = root / "second.cml"
            first.write_bytes(b"one")
            second.write_bytes(b"two")
            (root / "notes.txt").write_text("ignore")
            self.assertEqual(discover([root, first]), sorted([first.resolve(), second.resolve()], key=str))

    def test_directory_without_labs_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaisesRegex(ValueError, "no CML"):
                discover([Path(directory)])

    def test_repeated_structural_markers(self):
        marker = b"0123456789ABCDEF"
        payload = marker + b"x" * 23 + marker + b"y" * 31 + marker
        found = repeated_signatures(payload)
        match = next(item for item in found if item["signature_hex"] == marker.hex())
        self.assertEqual(match["count"], 3)
        self.assertEqual(match["offsets"], [0, 39, 86])
        self.assertEqual(match["min_gap"], 39)
        self.assertEqual(match["max_gap"], 47)

    def test_repeated_marker_short_input(self):
        self.assertEqual(repeated_signatures(b"short"), [])

    def test_cli_json_report(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "sample.cml"
            output = Path(directory) / "report.json"
            source.write_bytes(b"\x00" * 32)
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
