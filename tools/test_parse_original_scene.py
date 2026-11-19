import unittest
from parse_original_scene import parse_scene, scene_summary


SCENE = """level
{
  tmo_board
  {
    POS -1.41905, -1.08718, 0.03751
    ROT xyz 0, 0, -1.57080
    GOAL 1
    3DO to_board
    {
    }
    tmo_mount_bar
    {
      POSREL 0, 1, 0
    }
  }
  tmo_domino
  {
    VALB 64
  }
}
"""


class OriginalSceneTests(unittest.TestCase):
    def test_nested_original_shape(self):
        root = parse_scene(SCENE)
        self.assertEqual(root.name, "level")
        self.assertEqual(len(root.children), 2)
        board = root.children[0]
        self.assertEqual(board.name, "tmo_board")
        self.assertEqual(board.first_field("POS"), "-1.41905, -1.08718, 0.03751")
        self.assertEqual(board.first_field("GOAL"), "1")
        self.assertEqual(board.children[0].name, "3DO to_board")
        self.assertEqual(board.children[1].name, "tmo_mount_bar")
        self.assertEqual(board.children[1].first_field("POSREL"), "0, 1, 0")
        self.assertEqual(root.children[1].first_field("VALB"), "64")

    def test_summary_does_not_count_model_as_game_object(self):
        summary = scene_summary(parse_scene(SCENE))
        self.assertEqual(summary["object_nodes"], 3)
        self.assertEqual(summary["objects_with_position"], 1)
        self.assertEqual(summary["objects_with_model"], 1)
        self.assertEqual(summary["objects_with_goal"], 1)

    def test_unclosed_and_unmatched(self):
        for source in ("level\n{\ntmo_board\n{", "level\n{\n}\n}",
                       "level\n{\n}\nother\n{\n}"):
            with self.subTest(source=source), self.assertRaises(ValueError):
                parse_scene(source)

    def test_empty(self):
        with self.assertRaises(ValueError):
            parse_scene("")

    def test_scalar_before_closing_brace(self):
        root = parse_scene("level\n{\nFLAG 1\n}")
        self.assertEqual(root.first_field("FLAG"), "1")


if __name__ == "__main__":
    unittest.main()
