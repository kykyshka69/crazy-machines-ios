#!/usr/bin/env python3
"""Audit inferred vertex fields against a locally owned Crazy Machines assets ZIP."""
import json,math,struct,sys,zipfile
def audit(archive):
 total=good=nonfinite=extreme=0; examples=[]
 with zipfile.ZipFile(archive) as z:
  names=[n for n in z.namelist() if n.lower().endswith('.ucm')]
  for name in names:
   b=z.read(name); groups,faces,verts,_,_=struct.unpack_from('<5I',b,72)
   offset=92+12*faces
   for i in range(groups*verts):
    r=struct.unpack_from('<8f',b,offset+32*i);total+=1
    if not all(math.isfinite(x) for x in r):nonfinite+=1
    if abs(math.sqrt(sum(x*x for x in r[3:6]))-1)<0.01:good+=1
    if any(abs(x)>100 for x in r[6:8]):
     extreme+=1
     if len(examples)<8:examples.append({'file':name,'vertex':i,'uv':list(r[6:8])})
 return {'models':len(names),'vertices':total,'unit_normals':good,
         'nonfinite_vertices':nonfinite,'extreme_uv_vertices':extreme,
         'examples':examples}
if __name__=='__main__':print(json.dumps(audit(sys.argv[1]),indent=2))
