"""Synthetic audit failures are deterministic without a private Windows EXE."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_windows_solar_exe import verify

class SolarAuditSmoke(unittest.TestCase):
    def test_wrong_exe_rejected(self):
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            verify(b'MZ' + b'\0' * 16384)
    def test_nonsensical_input_rejected(self):
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            verify(bytes(2048))

if __name__ == '__main__':
    unittest.main()