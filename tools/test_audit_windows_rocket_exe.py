import unittest
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from audit_windows_rocket_exe import verify, SITES

class RocketAuditSmoke(unittest.TestCase):
    def test_wrong_exe_rejected(self):
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            verify(b"MZ" + bytes(8192))
    def test_real_prelaunch_and_ignition_sites_are_pinned(self):
        self.assertEqual(len(SITES), 29)
        self.assertIn(0x44E3BD, SITES)  # native 0x409650 region
        self.assertIn(0x44CD79, SITES)  # write state 1
        self.assertIn(0x44EF6D, SITES)  # separate Engine clock
        self.assertIn(0x44F354, SITES)  # original GOAL 0
    def test_empty_rejected(self):
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            verify(b"")
