import unittest
from material_bridge import translate
class BridgeTests(unittest.TestCase):
 def test_blend(self):
  s={'shader':'x','passes':[{'states':{'blend':[['srcalpha','invsrcalpha']]},'stages':[]}]}
  self.assertEqual(translate(s)['passes'][0]['blend'],{'source':'sourceAlpha','destination':'oneMinusSourceAlpha'})
 def test_unsupported_is_reported(self):
  s={'shader':'x','passes':[{'states':{'blend':[['mystery','mystery']]},'stages':[]}]}
  self.assertIsNone(translate(s)['passes'][0]['blend'])
  self.assertTrue(translate(s)['warnings'])
 def test_stage_sampler(self):
  s={'shader':'x','passes':[{'states':{},'stages':[{'states':{'address':[['mirror','clamp']],'colorop':[['modulate','texture','current']]},'textures':['a.tga']}]}]}
  p=translate(s)['passes'][0]['stages'][0]
  self.assertEqual(p['sampler_address'],['mirrorRepeat','clampToEdge'])
  self.assertEqual(p['ops']['colorop']['operation'],'multiply')
if __name__=='__main__':unittest.main()
