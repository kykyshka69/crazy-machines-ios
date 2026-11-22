"""No user-owned Windows bytes enter the GitHub repository."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from audit_windows_goal_calls import verify

class NativeGoalDispatchAuditSmoke(unittest.TestCase):
    def test_wrong_PE_rejected(self):
        with self.assertRaisesRegex(ValueError,"SHA-256"):
            verify(b"MZ"+bytes(65536))
    def test_empty_rejected(self):
        with self.assertRaisesRegex(ValueError,"SHA-256"):
            verify(b"")
