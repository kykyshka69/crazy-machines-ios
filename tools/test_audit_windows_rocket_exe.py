import unittest
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from audit_windows_rocket_exe import verify

class RocketAuditSmoke(unittest.TestCase):
    def test_wrong_exe_rejected(self):
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            verify(b"MZ" + bytes(8192))
    def test_empty_rejected(self):
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            verify(b"")
