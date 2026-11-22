"""Fail closed for wrong Win32 EXE; private original is not in CI."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_windows_switch_contacts import verify

class SwitchContactAuditTests(unittest.TestCase):
    def test_reject_mismatched_exe(self):
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            verify(b'MZ' + bytes(20000))
    def test_reject_random_data(self):
        with self.assertRaisesRegex(ValueError, 'SHA-256'):
            verify(bytes(1000))

if __name__=='__main__':
    unittest.main()