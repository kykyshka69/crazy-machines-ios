import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_windows_source_click_exe import verify

class OriginalSourceClickBinaryAuditSmoke(unittest.TestCase):
    def test_wrong_executable_rejected(self):
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            verify(b"MZ"+bytes(30000))

    def test_empty_executable_rejected(self):
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            verify(b"")
