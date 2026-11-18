#!/usr/bin/env python3
"""Bounded UCM1 structural parser; does not infer unverified field meanings."""
import struct,json,sys,zipfile

def parse(data):
 if len(data)<92 or data[:4]!=b'UCM1':raise ValueError('not UCM1')
 version=struct.unpack_from('<I',data,4)[0]
 if version not in (1,2):raise ValueError('unsupported version')
 groups,faces,verts,records,flag=struct.unpack_from('<5I',data,72)
 p=92;blocks=[dict(name='header',offset=0,size=92)]
 def take(name,n):
  nonlocal p
  if n<0 or p+n>len(data):raise ValueError(f'{name} exceeds file bounds')
  blocks.append(dict(name=name,offset=p,size=n));p+=n
 take('indices_u32',faces*12)
 take('vertices_32byte',groups*verts*32)
 take('records_16byte',records*16)
 for i in range(groups):take(f'group_{i}_records_64byte',records*64)
 a=b=0
 if version>1:
  if p+8>len(data):raise ValueError('truncated extension counters')
  a,b=struct.unpack_from('<2I',data,p)
  take('extension_counters',8)
  take('extension_records_16byte',a*16)
  take('extension_records_60byte',b*60)
 if p!=len(data):raise ValueError('unparsed trailing bytes')
 indices=struct.unpack_from(f'<{faces*3}I',data,92)
 if indices and max(indices)>=groups*verts:raise ValueError('index out of range')
 return dict(version=version,groups=groups,faces=faces,vertices_per_group=verts,
             records=records,flag=flag,extension_a=a,extension_b=b,
             blocks=blocks,byte_length=len(data))
if __name__=='__main__':
 with zipfile.ZipFile(sys.argv[1]) as z:
  models={n:parse(z.read(n)) for n in z.namelist() if n.lower().endswith('.ucm')}
 print(json.dumps({'count':len(models),'models':models},indent=2))
