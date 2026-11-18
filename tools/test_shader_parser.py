#!/usr/bin/env python3
"""Asset-free regression tests for the shader declaration parser."""
import unittest
from parse_shader_states import parse

class ShaderParserTests(unittest.TestCase):
    def test_nested_pass_stage_texture(self):
        blocks = parse("""
        ball_basket {
          pass {
            blend srcalpha invsrcalpha
            stage {
              texture data/textures/ball_basket.tga
              address wrap clamp
            }
          }
        }
        """)
        self.assertEqual(len(blocks), 1)
        self.assertEqual(blocks[0]["name"], "ball_basket")
        stage = blocks[0]["children"][0]["children"][0]
        self.assertEqual(stage["properties"]["texture"], [["data/textures/ball_basket.tga"]])
        self.assertEqual(stage["properties"]["address"], [["wrap", "clamp"]])

    def test_comments_not_counted_as_shaders(self):
        blocks = parse("""
        // fake { pass { stage { texture missing.tga } } }
        /* other { pass { } } */
        real { pass { stage { texture good.tga } } }
        """)
        self.assertEqual([b["name"] for b in blocks], ["real"])

    def test_duplicate_declarations_preserved(self):
        blocks = parse("weight { pass { } }\nweight { pass { } }")
        self.assertEqual([b["name"] for b in blocks], ["weight", "weight"])

    def test_unbalanced_block_rejected(self):
        with self.assertRaises(ValueError):
            parse("broken { pass { stage { texture x.tga } }")

if __name__ == "__main__":
    unittest.main()
