#!/usr/bin/env python3
"""Extract named shaders and declared texture paths from original shaders.shd."""
import json,re,zipfile,sys
from pathlib import PurePosixPath
def shader_blocks(text):
 text=re.sub(r'//[^\n]*','',text)
 text=re.sub(r'/\*.*?\*/','',text,flags=re.S)
 result={};i=0;token=re.compile(r'([A-Za-z_][\w.]*)\s*\{')
 while (m:=token.search(text,i)):
  name=m.group(1);start=m.end();depth=1;j=start
  while j<len(text) and depth:
   if text[j]=='{':depth+=1
   elif text[j]=='}':depth-=1
   j+=1
  if depth:raise ValueError('unbalanced shader braces')
  body=text[start:j-1]
  textures=[x for x in re.findall(r'\btexture\s+([^\s{}]+)',body,flags=re.I) if x.lower().endswith(('.tga','.png','.bmp','.jpg'))]
  result[name.casefold()]={'name':name,'textures':textures,'passes':len(re.findall(r'\bpass\s*\{',body,re.I))}
  i=j
 return result
def audit(archive):
 with zipfile.ZipFile(archive) as z:
  shaders=shader_blocks(z.read('scripts/shaders/shaders.shd').decode('latin1'))
  models=sorted(n for n in z.namelist() if n.lower().endswith('.ucm'))
  names={n.casefold() for n in z.namelist()};matches=[]
  for n in models:
   s=shaders.get(PurePosixPath(n).stem.casefold())
   if s:matches.append({'model':n,'shader':s['name'],'textures':s['textures'],'texture_files_present':[p.casefold() in names for p in s['textures']]})
  return {'model_count':len(models),'shader_count':len(shaders),'model_shader_name_matches':len(matches),'models_with_texture_references':sum(bool(m['textures']) for m in matches),'matches':matches}
if __name__=='__main__':print(json.dumps(audit(sys.argv[1]),indent=2,ensure_ascii=False))
