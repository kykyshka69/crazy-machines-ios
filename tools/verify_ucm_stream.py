#!/usr/bin/env python3
"""Verify the original EXE's UCM stream reads (no game assets distributed)."""
import hashlib,json,struct,sys
from pathlib import Path

def verify(exe):
 b=Path(exe).read_bytes()
 def at(va,n):return b[va-0x400000:va-0x400000+n]
 def nearcall(va):
  q=at(va,5)
  assert q[0]==0xe8,(hex(va),q.hex())
  return hex(va+5+struct.unpack('<i',q[1:])[0])
 expected={0x46ae9e:0x4d5a29,0x46aefa:0x4d5a29,0x46af7a:0x4d5a29,
           0x46afa1:0x4d5a29,0x46afe1:0x4d5a29}
 for va,target in expected.items():assert nearcall(va)==hex(target)
 assert at(0x46ae9b,3)==bytes.fromhex('6a5c51') # header length = 92
 assert at(0x46aef7,3)==bytes.fromhex('6a0450') # 4-byte indices on disk
 assert at(0x46af75,5)==bytes.fromhex('53526a2050') # 32-byte vertex stride
 assert at(0x46afdc,5)==bytes.fromhex('53526a4051') # 64-byte record
 return {"sha256":hashlib.sha256(b).hexdigest(),"header_bytes":92,
 "disk_index_bytes":4,"gpu_index_bytes":2,"vertex_stride_bytes":32,
 "extra_record_bytes":64,"all_checks_passed":True}

if __name__=="__main__":
 if len(sys.argv)!=2:raise SystemExit("Usage: python tools/verify_ucm_stream.py CrazyMachines.exe")
 print(json.dumps(verify(sys.argv[1]),indent=2))
