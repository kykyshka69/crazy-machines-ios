import unittest
from cml_byte_transforms import reverse_bytes, offset_arithmetic, adjacent_delta, apply_control_pairs


class OriginalByteTransformTests(unittest.TestCase):
    def test_reverse(self):
        self.assertEqual(reverse_bytes(b"abcde"), b"edcba")
        self.assertEqual(reverse_bytes(b""), b"")

    def test_offset_add_subtract_roundtrip(self):
        for initial in (-128, -1, 0, 1, 127, 255):
            for data in (b"", b"x", bytes(range(256))):
                encoded = offset_arithmetic(data, initial, True)
                self.assertEqual(offset_arithmetic(encoded, initial, False), data)

    def test_adjacent_prefix_uses_updated_previous_byte(self):
        self.assertEqual(adjacent_delta(bytes([1, 2, 3, 4]), True),
                         bytes([1, 3, 6, 10]))

    def test_adjacent_backward_uses_original_previous_byte(self):
        self.assertEqual(adjacent_delta(bytes([1, 2, 3, 4]), False),
                         bytes([1, 1, 1, 1]))

    def test_adjacent_roundtrip(self):
        for data in (b"", b"x", bytes(range(256)), bytes([255, 255, 1])):
            self.assertEqual(adjacent_delta(adjacent_delta(data, True), False), data)
            self.assertEqual(adjacent_delta(adjacent_delta(data, False), True), data)

    def test_original_dispatch_reverse(self):
        data = b"abcdef"
        self.assertEqual(apply_control_pairs(data, bytes([77, 0]), encode=True), b"fedcba")
        self.assertEqual(apply_control_pairs(b"fedcba", bytes([0, 77]), encode=False), data)

    def test_original_dispatch_arithmetic(self):
        data = bytes(range(64))
        encoded = apply_control_pairs(data, bytes([5, 1]), encode=True)
        self.assertEqual(apply_control_pairs(encoded, bytes([1, 5]), encode=False), data)

    def test_original_dispatch_delta(self):
        data = bytes(range(64))
        encoded = apply_control_pairs(data, bytes([7, 2]), encode=True)
        self.assertEqual(apply_control_pairs(encoded, bytes([2, 7]), encode=False), data)

    def test_original_signed_negative_remainder_is_noop(self):
        self.assertEqual(apply_control_pairs(b"abc", bytes([1, 255]), encode=True), b"abc")

    def test_original_control_rejects_odd_length(self):
        with self.assertRaises(ValueError):
            apply_control_pairs(b"abc", b"x", encode=True)

    def test_adjacent_empty_and_single(self):
        for flag in (True, False):
            self.assertEqual(adjacent_delta(b"", flag), b"")
            self.assertEqual(adjacent_delta(b"z", flag), b"z")


if __name__ == "__main__":
    unittest.main()
