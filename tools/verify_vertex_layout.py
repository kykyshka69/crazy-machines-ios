#!/usr/bin/env python3
"""Regression audit for the UCM1 8-float vertex channel layout."""
import json,math,struct,sys,zipfile
def audit(path):
 t=dict(models=0,vertices=0,triangles=0,unit_normals=0,nonunit_normals=0,nonfinite=0,shifted_mapping_unit_normals=0)
 with zipfile.ZipFile(path) as z:
  for name in z.namelist():
   if not name.lower().endswith('.ucm'):continue
   b=z.read(name)
   if b[:4]!=b'UCM1':raise ValueError(name)
   groups,faces,per_group,_,_=struct.unpack_from('<5I',b,72)
   p=92+faces*12;count=groups*per_group
   if p+count*32>len(b):raise ValueError('truncated: '+name)
   t['models']+=1;t['vertices']+=count;t['triangles']+=faces
   for i in range(count):
    v=struct.unpack_from('<8f',b,p+32*i)
    if not all(math.isfinite(x) for x in v):t['nonfinite']+=1;continue
    good=abs(math.sqrt(sum(x*x for x in v[3:6]))-1)<.01
    shifted=abs(math.sqrt(sum(x*x for x in v[4:7]))-1)<.01
    t['unit_normals']+=good;t['nonunit_normals']+=not good
    t['shifted_mapping_unit_normals']+=shifted
 return t
if __name__=='__main__':
 result=audit(sys.argv[1]);print(json.dumps(result,indent=2))
 assert result['models']==160 and result['vertices']==55342 and result['triangles']==22497
 assert result['unit_normals']==55329 and result['nonfinite']==0
 assert result['unit_normals']>result['shifted_mapping_unit_normals']
