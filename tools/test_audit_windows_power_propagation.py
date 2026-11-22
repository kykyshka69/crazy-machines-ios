import unittest
from audit_windows_power_propagation import verify, INSTRUCTIONS


class OriginalPowerAuditorTests(unittest.TestCase):
    def test_unknown_input_does_not_claim_engine_recovery(self):
        with self.assertRaisesRegex(ValueError, "exact original"):
            verify(b"MZ" + bytes(32000))

    def test_truncated_game_is_rejected(self):
        with self.assertRaises(ValueError):
            verify(b"")

    def test_fingerprint_is_a_nontrivial_instruction_set(self):
        self.assertGreaterEqual(len(INSTRUCTIONS), 12)
        self.assertIn(0x4504C9, INSTRUCTIONS)
        self.assertIn(0x44C8F2, INSTRUCTIONS)
        self.assertIn(0x450A2D, INSTRUCTIONS)
        self.assertIn(0x44D9C7, INSTRUCTIONS)

if __name__ == "__main__":
    unittest.main()