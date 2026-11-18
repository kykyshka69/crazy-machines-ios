#!/usr/bin/env python3
"""Audit candidate texture matches by exact basename; never claim material links."""
import json,zipfile,io,collections
from pathlib import PurePosixPath
from PIL import Image

def audit(archive):
 with zipfile.ZipFile(archive) as z:
  names=z.namelist();models=sorted(n for n in names if n.lower().endswith('.ucm'))
  textures=sorted(n for n in names if n.lower().endswith('.tga'))
  index=collections.defaultdict(list)
  for name in textures:index[PurePosixPath(name).stem.casefold()].append(name)
  results=[];decode_errors=[]
  for name in textures:
   try:
    with Image.open(io.BytesIO(z.read(name))) as im:im.load()
   except Exception as e:decode_errors.append({'texture':name,'error':str(e)})
  for model in models:
   stem=PurePosixPath(model).stem.casefold();candidates=index.get(stem,[])
   results.append({'model':model,'candidate_textures':candidates,
                   'match_method':'exact basename only; unverified material mapping'})
  return {'models':len(models),'textures':len(textures),'texture_decode_errors':decode_errors,
          'matched_models':sum(bool(r['candidate_textures']) for r in results),
          'unmatched_models':sum(not r['candidate_textures'] for r in results),
          'models_detail':results}
if __name__=='__main__':
 import sys
 print(json.dumps(audit(sys.argv[1]),indent=2,ensure_ascii=False))
