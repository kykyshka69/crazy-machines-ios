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
    def test_native_ignition_and_two_independent_rocket_timers(self):
        # Physical heat region produces a genuine threshold sample;
        # a literal candle tap or the GOAL metadata cannot bypass it.
        self.assertEqual(SITES[0x44E112], "68 a0 c8 4e 00")
        self.assertEqual(SITES[0x44E3BD], "e8 8e b2 fb ff")
        self.assertEqual(SITES[0x44E3D7], "75 64")
        # Exactly one original 0->1 timestamp, then Engine child clock.
        self.assertEqual(SITES[0x44CD79],
                         "c7 81 ec 00 00 00 00 00 80 3f")
        self.assertEqual(SITES[0x44EC72], "dc a1 30 01 00 00")
        self.assertEqual(SITES[0x44EF6D], "dd 99 30 01 00 00")
        self.assertEqual(SITES[0x44F296], "dc a0 30 01 00 00")
        self.assertEqual(SITES[0x44F354], "e8 07 c1 ff ff")

    def test_empty_rejected(self):
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            verify(b"")
