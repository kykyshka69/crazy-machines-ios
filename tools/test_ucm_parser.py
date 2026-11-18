import unittest,zipfile,sys
from ucm_parser import parse
class TestUCM(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  with zipfile.ZipFile(sys.argv[1]) as z:
   cls.models={n:z.read(n) for n in z.namelist() if n.lower().endswith('.ucm')}
 def test_all_models(self):
  self.assertEqual(len(self.models),160)
  for n,data in self.models.items():
   with self.subTest(name=n):
    parsed=parse(data)
    self.assertEqual(sum(x['size'] for x in parsed['blocks']),len(data))
 def test_truncation_rejected(self):
  for data in self.models.values():
   with self.assertRaises(ValueError):parse(data[:-1])
 def test_bad_signature_rejected(self):
  for data in self.models.values():
   with self.assertRaises(ValueError):parse(b'XXXX'+data[4:])
 def test_extra_bytes_rejected(self):
  for data in self.models.values():
   with self.assertRaises(ValueError):parse(data+b'\0')
if __name__=='__main__':
 archive=sys.argv[1]
 sys.argv=[sys.argv[0]]
 unittest.main(verbosity=2)
