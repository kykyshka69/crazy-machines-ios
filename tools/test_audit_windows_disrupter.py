"""Public non-proprietary negative tests; owner-only positive EXE check is local."""
import unittest
from audit_windows_disrupter import verify

class Win32DisrupterAuditSmoke(unittest.TestCase):
    def test_rejects_non_original_exe(self):
        with self.assertRaises(ValueError):
            verify(b'MZ' + b'\0' * 2048)
    def test_rejects_unrelated_input(self):
        with self.assertRaises(ValueError):
            verify(b'not a PE32 file')

if __name__ == '__main__':
    unittest.main()