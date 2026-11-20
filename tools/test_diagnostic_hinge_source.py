"""Regression checks for diagnostic hinge selection in the SceneKit viewer.

These source-level guards run on Linux; they do not replace an Xcode build.
"""
from pathlib import Path
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / "ios" /
          "CMOriginalAssembledSceneView.swift")


class DiagnosticHingeSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = SOURCE.read_text(encoding="utf-8")
        cls.section = cls.source.split("let hingeCandidates:", 1)[1].split(
            "if hasBounds && experimentalPhysics", 1)[0]

    def test_compound_body_ancestor_is_resolved(self):
        self.assertIn("current = node.parent", self.section)
        self.assertIn("bodyNode: node", self.section)

    def test_same_body_meshes_are_not_joined(self):
        self.assertIn("bodyNode === hingeCandidates[j].bodyNode", self.section)
        self.assertIn("continue", self.section)

    def test_no_valid_pair_does_not_fall_back_to_first_two_meshes(self):
        self.assertIn("var closestPair: (Int, Int)?", self.section)
        self.assertIn("if let closestPair {", self.section)
        self.assertNotIn("var closestPair = (0, 1)", self.section)

    def test_selected_pair_is_updated_only_for_valid_distinct_bodies(self):
        self.assertIn("closestPair = (i, j)", self.section)
        self.assertIn("if distanceSquared.isFinite && distanceSquared < bestDistanceSquared", self.section)
        self.assertIn("if let closestPair {", self.section)

    def test_joint_creation_is_guarded_by_finite_coordinates(self):
        self.assertIn("if coordinates.allSatisfy({ $0.isFinite })", self.section)
        self.assertIn("scene.physicsWorld.addBehavior(hinge)", self.section)

    def test_anchor_uses_body_local_coordinates(self):
        self.assertIn("first.convertPosition(anchor, from: nil)", self.section)
        self.assertIn("second.convertPosition(anchor, from: nil)", self.section)


if __name__ == "__main__":
    unittest.main()
