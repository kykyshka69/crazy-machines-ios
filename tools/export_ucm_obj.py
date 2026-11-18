#!/usr/bin/env python3
"""Export local UCM1 meshes as Wavefront OBJ without inventing materials."""
import argparse,json,math,struct,zipfile
from pathlib import Path

def decode(data):
 if len(data)<92 or data[:4]!=b'UCM1':raise ValueError('invalid UCM1 header')
 version=struct.unpack_from('<I',data,4)[0]
 if version not in (1,2):raise ValueError('unsupported UCM version')
 groups,faces,per_group,records,_=struct.unpack_from('<5I',data,72)
 if not groups or not per_group or groups*per_group>1000000 or faces>1000000:raise ValueError('invalid geometry counts')
 p=92
 if p+faces*12+groups*per_group*32>len(data):raise ValueError('truncated geometry')
 indices=struct.unpack_from(f'<{faces*3}I',data,p);p+=faces*12
 vertices=[struct.unpack_from('<8f',data,p+32*i) for i in range(groups*per_group)]
 p+=groups*per_group*32+records*16+groups*records*64
 if p>len(data):raise ValueError('truncated records')
 if version==2:
  if p+8>len(data):raise ValueError('truncated extension')
  a,b=struct.unpack_from('<2I',data,p);p+=8+a*16+b*60
 if p!=len(data):raise ValueError('unparsed or truncated tail')
 if indices and max(indices)>=len(vertices):raise ValueError('out of range index')
 if any(not math.isfinite(x) for row in vertices for x in row):raise ValueError('non-finite vertex')
 return vertices,indices

def obj_text(vertices,indices,name='ucm_mesh'):
 lines=['# UCM1 geometry export; UV/material interpretation remains provisional','o '+name]
 lines+=['v %.9g %.9g %.9g'%row[:3] for row in vertices]
 lines+=['vt %.9g %.9g'%row[6:8] for row in vertices]
 lines+=['vn %.9g %.9g %.9g'%row[3:6] for row in vertices]
 lines+=['f '+' '.join(f'{j+1}/{j+1}/{j+1}' for j in indices[i:i+3]) for i in range(0,len(indices),3)]
 return '\n'.join(lines)+'\n'

if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('archive');ap.add_argument('output_dir');args=ap.parse_args()
 out=Path(args.output_dir);out.mkdir(parents=True,exist_ok=True);manifest=[]
 with zipfile.ZipFile(args.archive) as z:
  for name in z.namelist():
   if not name.lower().endswith('.ucm'):continue
   v,i=decode(z.read(name));stem=Path(name).stem
   (out/(stem+'.obj')).write_text(obj_text(v,i,stem),encoding='utf8')
   manifest.append({'model':name,'vertices':len(v),'triangles':len(i)//3})
 (out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
 print(json.dumps({'models':len(manifest),'vertices':sum(x['vertices'] for x in manifest),'triangles':sum(x['triangles'] for x in manifest)},indent=2))
