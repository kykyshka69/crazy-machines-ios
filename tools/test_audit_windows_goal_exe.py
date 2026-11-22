"""No original game binary is needed for public CI forensic verifier tests."""
import hashlib
import pathlib
import tempfile
import unittest
from audit_windows_goal_exe import verify, SUPPORTED_SHA256, SITES, EXPECTED_STRINGS


class OriginalWindowsGoalAuditSmoke(unittest.TestCase):
    def test_evidence_inventory_is_strict_and_unique(self):
        self.assertEqual(len(SUPPORTED_SHA256), 64)
        self.assertEqual(len(SITES), 13)
        self.assertEqual(len(EXPECTED_STRINGS), 6)
        self.assertEqual(len({a for a, _, _ in SITES}), len(SITES))
        self.assertEqual(len({a for a in EXPECTED_STRINGS}), len(EXPECTED_STRINGS))
        for address, bytecode, description in SITES:
            self.assertGreater(address, 0x400000)
            self.assertGreater(len(bytes.fromhex(bytecode)), 0)
            self.assertTrue(description)

    def test_unsupported_executable_rejected_before_untrusted_parse(self):
        with tempfile.TemporaryDirectory() as temp:
            file = pathlib.Path(temp) / 'fake-original.exe'
            file.write_bytes(b'MZ' + bytes(1024))
            with self.assertRaisesRegex(ValueError, 'unsupported original'):
                verify(file)
            file.write_bytes(b'')
            with self.assertRaisesRegex(ValueError, 'unsupported original'):
                verify(file)


if __name__ == '__main__':
    unittest.main()