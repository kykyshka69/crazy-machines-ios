"""Regression tests to prevent a wrong screenshot being called original level one."""
import json
from pathlib import Path
import struct
import tempfile
import unittest

from select_first_level_screenshot import (
    ATTACHMENT_NAME, ATTACHMENT_NAME_LEVEL_TWO, ATTACHMENT_NAME_LEVEL_THREE, TEST_NAME,
    select_screenshot, validate_summary
)

GOOD_SUMMARY = dict(totalTestCount=1, passedTests=1, failedTests=0, skippedTests=0)


def png():
    # Header and dummy payload for metadata selection; not a rendered screenshot.
    return b"\x89PNG\r\n\x1a\n" + struct.pack(">I", 13) + b"IHDR" + struct.pack(">II", 1170, 2532) + b"\x08\x06\x00\x00\x00" + b"PLACEHOLDER"


class SelectFirstLevelScreenshotTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.path = Path(self.folder.name)
        self.output = self.path / "actual-first-level.png"
        (self.path / "right.png").write_bytes(png())
        (self.path / "wrong.png").write_bytes(png())
        self.record = dict(testIdentifier="CrazyMachinesUITests/CrazyMachinesLaunchUITests/" + TEST_NAME + "()",
                           attachments=[{"exportedFileName": "wrong.png", "suggestedHumanReadableName": "Screenshot"},
                                        {"exportedFileName": "right.png", "suggestedHumanReadableName": ATTACHMENT_NAME}])
        self.write_manifest([self.record])

    def write_manifest(self, records):
        (self.path / "manifest.json").write_text(json.dumps(records), encoding="utf-8")

    def test_selects_named_attachment_not_first_png(self):
        self.assertEqual(select_screenshot(self.path, GOOD_SUMMARY, self.output), self.output)
        self.assertEqual(self.output.read_bytes(), (self.path / "right.png").read_bytes())

    def test_can_select_exact_original_second_level_capture(self):
        self.record["attachments"][1]["suggestedHumanReadableName"] = (
            ATTACHMENT_NAME_LEVEL_TWO)
        self.write_manifest([self.record])
        self.assertEqual(
            select_screenshot(
                self.path, GOOD_SUMMARY, self.output,
                ATTACHMENT_NAME_LEVEL_TWO),
            self.output)
        self.assertEqual(
            self.output.read_bytes(),
            (self.path / "right.png").read_bytes())

    def test_selects_authentic_third_level_only_by_exact_name(self):
        self.record["attachments"][1]["suggestedHumanReadableName"] = (
            ATTACHMENT_NAME_LEVEL_THREE)
        self.write_manifest([self.record])
        self.assertEqual(
            select_screenshot(
                self.path, GOOD_SUMMARY, self.output,
                ATTACHMENT_NAME_LEVEL_THREE),
            self.output)
        self.assertEqual(
            self.output.read_bytes(),
            (self.path / "right.png").read_bytes())

    def test_rejects_synthetic_or_unknown_level_name(self):
        self.record["attachments"][1]["suggestedHumanReadableName"] = (
            "08-synthetic-original-level-two-navigation")
        self.write_manifest([self.record])
        with self.assertRaisesRegex(ValueError, "unknown authentic"):
            select_screenshot(self.path, GOOD_SUMMARY, self.output,
                              "08-synthetic-original-level-two-navigation")
        with self.assertRaisesRegex(ValueError, "exactly one"):
            select_screenshot(self.path, GOOD_SUMMARY, self.output,
                              ATTACHMENT_NAME_LEVEL_TWO)

    def test_rejects_skipped_test(self):
        with self.assertRaisesRegex(ValueError, "not the sole passing"):
            select_screenshot(self.path, dict(GOOD_SUMMARY, skippedTests=1, passedTests=0), self.output)

    def test_rejects_missing_summary_counts(self):
        with self.assertRaisesRegex(ValueError, "missing numeric"):
            validate_summary(dict(passedTests=1))

    def test_rejects_failure_case(self):
        with self.assertRaisesRegex(ValueError, "not the sole passing"):
            select_screenshot(self.path, dict(GOOD_SUMMARY, failedTests=1), self.output)

    def test_rejects_wrong_attachment_name(self):
        self.record["attachments"][1]["suggestedHumanReadableName"] = "Launch screenshot"
        self.write_manifest([self.record])
        with self.assertRaisesRegex(ValueError, "exactly one"):
            select_screenshot(self.path, GOOD_SUMMARY, self.output)

    def test_rejects_wrong_test(self):
        self.record["testIdentifier"] = "CrazyMachinesUITests/UnrelatedUITests/testOther()"
        self.write_manifest([self.record])
        with self.assertRaisesRegex(ValueError, "exactly one"):
            select_screenshot(self.path, GOOD_SUMMARY, self.output)

    def test_rejects_duplicate_named_screenshots(self):
        self.record["attachments"].append(dict(exportedFileName="wrong.png", suggestedHumanReadableName=ATTACHMENT_NAME))
        self.write_manifest([self.record])
        with self.assertRaisesRegex(ValueError, "exactly one"):
            select_screenshot(self.path, GOOD_SUMMARY, self.output)

    def test_rejects_path_traversal(self):
        self.record["attachments"][1]["exportedFileName"] = "../right.png"
        self.write_manifest([self.record])
        with self.assertRaisesRegex(ValueError, "unsafe"):
            select_screenshot(self.path, GOOD_SUMMARY, self.output)

    def test_rejects_renamed_non_png(self):
        (self.path / "right.png").write_bytes(b"NOT A PNG")
        with self.assertRaisesRegex(ValueError, "valid PNG"):
            select_screenshot(self.path, GOOD_SUMMARY, self.output)

    def test_rejects_existing_destination(self):
        self.output.write_bytes(b"existing user content")
        with self.assertRaisesRegex(ValueError, "overwrite"):
            select_screenshot(self.path, GOOD_SUMMARY, self.output)


if __name__ == "__main__":
    unittest.main()
