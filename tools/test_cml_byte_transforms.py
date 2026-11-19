import unittest
from cml_byte_transforms import reverse_bytes, offset_arithmetic, adjacent_delta


class OriginalByteTransformTests(unittest.TestCase):
    def test_reverse(self):
        self.assertEqual(reverse_bytes(b"abcde"), b"edcba")
        self.assertEqual(reverse_bytes(b""), b"")

    def test_offset_add_subtract_roundtrip(self):
        for initial in (-128, -1, 0, 1, 127, 255):
            for data in (b"", b"x", bytes(range(256))):
                encoded = offset_arithmetic(data, initial, True)
                self.assertEqual(offset_arithmetic(encoded, initial, False), data)

    def test_adjacent_prefix_uses_original_bytes(self):
        self.assertEqual(adjacent_delta(bytes([1, 2, 3, 4]), True),
                         bytes([1, 3, 5, 7]))

    def test_adjacent_backward_uses_transformed_previous_byte(self):
        self.assertEqual(adjacent_delta(bytes([1, 2, 3, 4]), False),
                         bytes([1, 1, 2, 2]))

    def test_adjacent_empty_and_single(self):
        for flag in (True, False):
            self.assertEqual(adjacent_delta(b"", flag), b"")
            self.assertEqual(adjacent_delta(b"z", flag), b"z")


if __name__ == "__main__":
    unittest.main()
