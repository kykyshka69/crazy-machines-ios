import unittest

from export_original_scene_json import export_scene, parse_vector3, to_json


class OriginalSceneJSONTests(unittest.TestCase):
    def test_nested_models_and_transforms(self):
        scene = ("level\r\n{\r\n"
                 "tmo_board\r\n{\r\n"
                 "POS -1.41905, -1.08718, 0.03751\r\n"
                 "POSREL 0.25, -0.5, 0\r\n"
                 "ROT xyz 0, 0, -1.57080\r\n"
                 "GOAL 1\r\n"
                 "3DO to_board\r\n{\r\n}\r\n"
                 "tmo_mount_bar\r\n{\r\nPOS 0, 1, 2\r\n}\r\n"
                 "}\r\n}\r\n")
        document = export_scene(scene, index=1, title="Оригинальный уровень")
        self.assertEqual(document["root"]["name"], "level")
        board = document["root"]["children"][0]
        self.assertEqual(board["position"], [-1.41905, -1.08718, 0.03751])
        self.assertEqual(board["models"], ["to_board"])
        self.assertEqual(board["position_relative"], [0.25, -0.5, 0])
        self.assertEqual(board["goal_raw"], "1")
        self.assertEqual(board["children"][1]["position"], [0, 1, 2])
        self.assertIn("Оригинальный уровень", to_json(document))

    def test_nested_model_ownership(self):
        scene = ("level\n{\n"
                 "tmo_parent\n{\n"
                 "helper\n{\n3DO to_parent\n{\n}\n}\n"
                 "tmo_child\n{\n3DO to_child\n{\n}\n}\n"
                 "}\n}\n")
        document = export_scene(scene, index=1, title="Nested original models")
        parent = document["root"]["children"][0]
        self.assertEqual(parent["models"], ["to_parent"])
        self.assertEqual(parent["children"][1]["models"], ["to_child"])

    def test_pc_vector_decimal_and_scientific_notation(self):
        self.assertEqual(parse_vector3(" .5, -1., +2.5e-2 "), [0.5, -1.0, 0.025])
        self.assertEqual(parse_vector3("1E+2, -0.25, 0"), [100.0, -0.25, 0.0])

    def test_reject_nonfinite_or_overflowing_vectors(self):
        for value in ("1e999, 0, 0", "NaN, 0, 0", "0, Infinity, 0"):
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    parse_vector3(value)

    def test_reject_bad_vector(self):
        with self.assertRaises(ValueError):
            parse_vector3("abc, 1, 2")

    def test_reject_invalid_identity(self):
        with self.assertRaises(ValueError):
            export_scene("level\n{\n}\n", index=0, title="x")


if __name__ == "__main__":
    unittest.main()
