import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from audit_windows_power_cables import verify

class PowerCableBinaryEvidenceTests(unittest.TestCase):
    def test_rejects_non_original_or_corrupt_exe(self):
        with TemporaryDirectory() as d:
            p = Path(d)/"CrazyMachines.exe"
            p.write_bytes(b"MZ" + b"\x00" * 256)
            with self.assertRaises(ValueError):
                verify(p)

if __name__ == '__main__':
    unittest.main()