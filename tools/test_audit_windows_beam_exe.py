"""Copyright-free verifier rejection tests. The original EXE is private."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_windows_beam_exe import verify

class OriginalBeamAuditTests(unittest.TestCase):
    def test_wrong_game_rejected(self):
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            verify(b"MZ" + bytes(10000))

    def test_empty_file_rejected(self):
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            verify(b"")
