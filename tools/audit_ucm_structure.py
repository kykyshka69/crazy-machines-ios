#!/usr/bin/env python3
"""Validate UCM1 structural block lengths in a local ZIP of game assets."""
import argparse,json,struct,zipfile
def parse(b):
 if len(b)<92 or b[:4]!=b'UCM1': raise ValueError('invalid UCM1 header')
 version=struct.unpack_from('<I',b,4)[0]
 groups,faces,verts,records,flag=struct.unpack_from('<5I',b,72)
 p=92
 inds=struct.unpack_from('<%dI'%(faces*3),b,p)
 p+=faces*12+groups*verts*32+records*16+groups*records*64
 a=c=0
 if version>1:
  a,c=struct.unpack_from('<2I',b,p)
  p+=8+a*16+c*60
 if p!=len(b):raise ValueError(f'expected {p} bytes, got {len(b)}')
 return dict(version=version,groups=groups,faces=faces,vertices_per_group=verts,
             records=records,extension_a=a,extension_b=c,bytes=len(b),
             indices_in_range=max(inds,default=0)<groups*verts)
if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('archive');args=ap.parse_args()
 with zipfile.ZipFile(args.archive) as z:
  names=[n for n in z.namelist() if n.lower().endswith('.ucm')]
  results={n:parse(z.read(n)) for n in names}
 print(json.dumps({'models':len(results),'index_valid':sum(x['indices_in_range'] for x in results.values()),
                   'versions':{str(v):sum(x['version']==v for x in results.values()) for v in sorted({x['version'] for x in results.values()})}},indent=2))
