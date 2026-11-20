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

    def test_payload_statistics_exclude_marker_bytes(self):
        data = b"prefix" + OBSERVED_HEADER + bytes([0, 0, 3, 3, 255])
        result = candidate_spans(data)
        record = result["candidate_spans"][0]
        self.assertEqual(record["payload_length"], 5)
        self.assertEqual(record["payload_distinct_byte_values"], 3)
        self.assertEqual(record["payload_zero_bytes"], 2)

    def test_empty_payload_statistics(self):
        result = candidate_spans(OBSERVED_HEADER)
        record = result["candidate_spans"][0]
        self.assertEqual(record["payload_length"], 0)
        self.assertEqual(record["payload_distinct_byte_values"], 0)
        self.assertEqual(record["payload_zero_bytes"], 0)

    def test_duplicate_payload_groups(self):
        data = OBSERVED_HEADER + b"same" + OBSERVED_HEADER + b"other" + OBSERVED_HEADER + b"same"
        result = candidate_spans(data)
        self.assertEqual(result["duplicate_payload_candidate_indices"], [[0, 2]])

    def test_no_duplicate_payload_groups(self):
        data = OBSERVED_HEADER + b"a" + OBSERVED_HEADER + b"b"
        result = candidate_spans(data)
        self.assertEqual(result["duplicate_payload_candidate_indices"], [])

    def test_boundary_integrity_report(self):
        data = b"header" + OBSERVED_HEADER + b"one" + OBSERVED_HEADER + b"two"
        result = candidate_spans(data)
        checks = result["boundary_checks"]
        self.assertTrue(checks["all_markers_complete"])
        self.assertTrue(checks["contiguous_after_first_marker"])
        self.assertEqual(checks["empty_payload_indices"], [])
        self.assertEqual(checks["minimum_candidate_length"], len(OBSERVED_HEADER) + 3)
        self.assertEqual(checks["maximum_candidate_length"], len(OBSERVED_HEADER) + 3)
        self.assertEqual(checks["total_candidate_bytes"], len(data) - len(b"header"))

    def test_empty_candidate_payload_reported(self):
        result = candidate_spans(OBSERVED_HEADER + OBSERVED_HEADER)
        self.assertEqual(result["boundary_checks"]["empty_payload_indices"], [0, 1])

    def test_no_marker(self):
        result = candidate_spans(b"no original marker")
        self.assertEqual(result["candidate_count"], 0)
        self.assertIsNone(result["prologue_bytes"])

    def test_reject_empty_marker(self):
        with self.assertRaises(ValueError):
            candidate_spans(b"anything", b"")


if __name__ == "__main__":
    unittest.main()
