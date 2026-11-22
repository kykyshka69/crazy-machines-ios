import json
import tempfile
import unittest
from pathlib import Path

from export_private_102_report import (
    ATTACHMENT, HEADER, TEST_ID, export_private_report
)


class Private102ReportTests(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name)
        self.attachments = self.root / "attachments"
        self.attachments.mkdir()
        self.output = self.root / "report.csv"
        self.filename = "private-evidence-001.csv"
        self.body = (
            ",".join(HEADER) + "\n" +
            '1,"Original level one",30,30,0,0,loaded\n' +
            '2,"Original, level two",66,66,1,1,loaded\n'
        )
        (self.attachments / self.filename).write_text(
            self.body, encoding="utf-8")
        self.write_manifest(TEST_ID, ATTACHMENT + "_0_UUID.csv")

    def write_manifest(self, test_id, attachment_name, filename=None):
        (self.attachments / "manifest.json").write_text(json.dumps([{
            "testIdentifier": test_id,
            "attachments": [{
                "suggestedHumanReadableName": attachment_name,
                "exportedFileName": filename or self.filename
            }]
        }]), encoding="utf-8")

    def test_exports_exact_private_test_and_preserves_quoted_titles(self):
        self.assertEqual(
            export_private_report(self.attachments, self.output), 2)
        self.assertEqual(self.output.read_text(encoding="utf-8"), self.body)

    def test_never_exports_from_public_synthetic_test(self):
        self.write_manifest(
            "CrazyMachinesLaunchUITests/testReal3DNavigationWithSyntheticImportedScene()",
            ATTACHMENT)
        with self.assertRaisesRegex(ValueError, "exactly one"):
            export_private_report(self.attachments, self.output)
        self.assertFalse(self.output.exists())

    def test_rejects_duplicated_or_missing_levels(self):
        bad = ",".join(HEADER) + "\n1,x,30,30,0,0,loaded\n3,y,20,20,0,0,loaded\n"
        (self.attachments / self.filename).write_text(bad, encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "out of order"):
            export_private_report(self.attachments, self.output)

    def test_rejects_false_loaded_render_count(self):
        bad = ",".join(HEADER) + "\n1,x,29,30,0,0,loaded\n"
        (self.attachments / self.filename).write_text(bad, encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Incorrectly marked"):
            export_private_report(self.attachments, self.output)

    def test_preserves_incomplete_level_report_for_diagnosis(self):
        bad = ",".join(HEADER) + "\n1,x,29,30,0,0,mismatch\n"
        (self.attachments / self.filename).write_text(bad, encoding="utf-8")
        self.assertEqual(export_private_report(self.attachments, self.output), 1)
        self.assertIn("mismatch", self.output.read_text(encoding="utf-8"))

    def test_rejects_parent_path_and_unexpected_status(self):
        self.write_manifest(TEST_ID, ATTACHMENT, "../other.csv")
        with self.assertRaisesRegex(ValueError, "Unsafe"):
            export_private_report(self.attachments, self.output)
        self.write_manifest(TEST_ID, ATTACHMENT)
        bad = ",".join(HEADER) + "\n1,x,30,30,0,0,solved\n"
        (self.attachments / self.filename).write_text(bad, encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "Unexpected status"):
            export_private_report(self.attachments, self.output)


if __name__ == "__main__":
    unittest.main()
