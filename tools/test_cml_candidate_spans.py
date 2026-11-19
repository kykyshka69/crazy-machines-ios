"""Synthetic-only tests for opaque CML candidate span inventory."""
import hashlib
import unittest
from cml_candidate_spans import candidate_spans, OBSERVED_HEADER


class CandidateSpanTests(unittest.TestCase):
    def test_three_candidate_spans(self):
        data = b"prologue" + OBSERVED_HEADER + b"abc" + OBSERVED_HEADER + b"12345" + OBSERVED_HEADER + b"z"
        result = candidate_spans(data)
        self.assertEqual(result["prologue_bytes"], 8)
        self.assertEqual(result["candidate_count"], 3)
        spans = result["candidate_spans"]
        self.assertEqual([s["start"] for s in spans],
                         [8, 8 + len(OBSERVED_HEADER) + 3,
                          8 + 2 * len(OBSERVED_HEADER) + 8])
        self.assertEqual(spans[-1]["end_exclusive"], len(data))
        self.assertEqual(spans[0]["sha256"],
                         hashlib.sha256(OBSERVED_HEADER + b"abc").hexdigest())

    def test_no_marker(self):
        result = candidate_spans(b"no original marker")
        self.assertEqual(result["candidate_count"], 0)
        self.assertIsNone(result["prologue_bytes"])

    def test_reject_empty_marker(self):
        with self.assertRaises(ValueError):
            candidate_spans(b"anything", b"")


if __name__ == "__main__":
    unittest.main()
