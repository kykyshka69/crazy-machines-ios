import unittest
from cml_puzzle_instructions import read_simple_instruction


class PuzzleInstructionsTests(unittest.TestCase):
    def test_extracts_cp1251_text_and_trailer(self):
        binary = b"abcd"
        text = "Привет, лаборатория!".encode("cp1251")
        # First 4 bytes are a section size; the binary section is 4 bytes
        # followed by an 8-byte metadata section before the text length.
        payload = (4).to_bytes(4, "little") + binary + b"\x00" * 4
        payload += len(text).to_bytes(4, "little") + text + (200).to_bytes(4, "little")
        parsed = read_simple_instruction(payload)
        self.assertEqual(parsed["instruction_text"], "Привет, лаборатория!")
        self.assertEqual(parsed["trailing_value"], 200)

    def test_rejects_extra_sections(self):
        payload = (0).to_bytes(4, "little") + b"\x00" * 4
        payload += (1).to_bytes(4, "little") + b"A" + b"extra" + b"\x00" * 4
        with self.assertRaises(ValueError):
            read_simple_instruction(payload)

    def test_rejects_short_payload(self):
        with self.assertRaises(ValueError):
            read_simple_instruction(b"abc")


if __name__ == "__main__":
    unittest.main()
