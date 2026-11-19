"""Self-contained regression for original CML framing and record parsing."""
import unittest

from cml_byte_transforms import (
    ORIGINAL_LAB_KEY, adjacent_delta, apply_control_pairs,
    decode_original_lab_field, reverse_bytes,
)


def encode_original_frame(payload: bytes) -> bytes:
    """Inverse of the recovered original read-mode transform."""
    key = ORIGINAL_LAB_KEY
    data = key + payload
    control = reverse_bytes(key)
    # Undo decoding operations in reverse order.
    for i in range(len(control) - 2, -1, -2):
        selector = control[i]
        parameter = control[i + 1]
        signed = selector if selector < 128 else selector - 256
        remainder = signed - int(signed / 3) * 3
        if remainder == 0:
            data = reverse_bytes(data)
        elif remainder == 1:
            from cml_byte_transforms import offset_arithmetic
            data = offset_arithmetic(data, parameter, add=True)
        elif remainder == 2:
            data = adjacent_delta(data, forward=True)
    return adjacent_delta(data, forward=True)


class OriginalFrameTests(unittest.TestCase):
    def test_roundtrip_all_field_sizes(self):
        for size in (0, 1, 4, 80, 1755, 6070):
            with self.subTest(size=size):
                payload = bytes((i * 17 + 13) % 256 for i in range(size))
                encoded = encode_original_frame(payload)
                self.assertEqual(len(encoded), size + len(ORIGINAL_LAB_KEY))
                self.assertEqual(
                    decode_original_lab_field(encoded, payload_length=size), payload
                )

    def test_reject_corrupted_frame(self):
        encoded = bytearray(encode_original_frame(b"abc"))
        encoded[0] ^= 0x80
        with self.assertRaises(ValueError):
            decode_original_lab_field(bytes(encoded), payload_length=3)

    def test_reject_wrong_field_size(self):
        with self.assertRaises(ValueError):
            decode_original_lab_field(encode_original_frame(b"abc"), payload_length=4)


if __name__ == "__main__":
    unittest.main()
