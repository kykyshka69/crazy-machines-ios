import unittest
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from audit_windows_rocket_exe import verify, SITES, REGION_SITES, FORCE_SITES, VELOCITY_SITES, CANDLE_HEAT_PATH_SITES, CANDLE_HEAT_FACTORY_SITES

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

    def test_native_heat_region_plane_and_selector_are_pinned(self):
        self.assertEqual(len(REGION_SITES), 8)
        # Both vectors have Z forcibly overwritten with zero.
        self.assertEqual(REGION_SITES[0x40966D],
                         "c7 45 f8 00 00 00 00")
        self.assertEqual(REGION_SITES[0x409688],
                         "c7 45 d4 00 00 00 00")
        # Heat receiver asks for FIRST selector-3 region (0x4204A0).
        self.assertEqual(REGION_SITES[0x44E3A4], "6a 00 6a 03")
        self.assertEqual(REGION_SITES[0x420522], "0f b6 48 10")
        self.assertEqual(REGION_SITES[0x44E3B3], "83 c0 24")

    def test_rocket_direction_force_at_original_body_center(self):
        self.assertEqual(len(FORCE_SITES), 12)
        self.assertEqual(FORCE_SITES[0x44F1DD], "68 a8 ca 4e 00")
        self.assertEqual(FORCE_SITES[0x44F219], "8b 91 fc 00 00 00")
        self.assertEqual(FORCE_SITES[0x44F22D], "e8 2e 52 fb ff")
        self.assertEqual(FORCE_SITES[0x44F27D], "e8 ee 71 fd ff")
        self.assertEqual(FORCE_SITES[0x486408], "d8 80 08 01 00 00")
        self.assertEqual(FORCE_SITES[0x486418], "d8 80 0c 01 00 00")

    def test_original_rocket_velocity_loader(self):
        self.assertEqual(len(VELOCITY_SITES), 3)
        self.assertEqual(VELOCITY_SITES[0x422D35], "68 30 94 4e 00")
        self.assertEqual(VELOCITY_SITES[0x422D81], "d9 9a fc 00 00 00")
        self.assertEqual(VELOCITY_SITES[0x44F219], "8b 91 fc 00 00 00")

    def test_source_candle_cone_is_not_rocket_receiver_region(self):
        self.assertEqual(len(CANDLE_HEAT_PATH_SITES), 9)
        self.assertEqual(CANDLE_HEAT_PATH_SITES[0x44E146], "8b 42 18")
        self.assertEqual(CANDLE_HEAT_PATH_SITES[0x44E14F], "d9 81 ec 00 00 00")
        self.assertEqual(CANDLE_HEAT_PATH_SITES[0x44E17A], "8b 42 20")
        self.assertEqual(CANDLE_HEAT_PATH_SITES[0x44E3B3], "83 c0 24")
        self.assertEqual(CANDLE_HEAT_PATH_SITES[0x44E3B7], "8b 8d 38 ff ff ff")
        self.assertEqual(CANDLE_HEAT_PATH_SITES[0x44E3BD], "e8 8e b2 fb ff")

    def test_candle_has_original_native_source_cone_shape(self):
        self.assertEqual(len(CANDLE_HEAT_FACTORY_SITES), 10)
        self.assertEqual(CANDLE_HEAT_FACTORY_SITES[0x4545C0], "68 a8 d2 4e 00")
        self.assertEqual(CANDLE_HEAT_FACTORY_SITES[0x4545D8], "6a 00 6a 03")
        self.assertEqual(CANDLE_HEAT_FACTORY_SITES[0x4545FE], "e8 7d d8 fd ff")
        self.assertEqual(CANDLE_HEAT_FACTORY_SITES[0x432053], "68 00 00 88 41")
        self.assertEqual(CANDLE_HEAT_FACTORY_SITES[0x432060], "68 cd cc 4c 3e")
        self.assertEqual(CANDLE_HEAT_FACTORY_SITES[0x43206D], "68 cd cc 4c 3f")
        self.assertEqual(CANDLE_HEAT_FACTORY_SITES[0x4320A9], "89 51 20")

    def test_empty_rejected(self):
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            verify(b"")
