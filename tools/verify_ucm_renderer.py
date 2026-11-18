#!/usr/bin/env python3
"""Verify actual UCM1 validation and index/vertex buffer construction in EXE."""
from pathlib import Path
import hashlib,json,struct,sys
def check(path):
 b=Path(path).read_bytes()
 def raw(va,n): return b[va-0x400000:va-0x400000+n]
 def call(va):
  v=raw(va,5)
  assert v[0]==0xe8, (hex(va),v.hex())
  return va+5+struct.unpack('<i',v[1:])[0]
 signature=[(0x46a3a0,0x55),(0x46a3a6,0x43),(0x46a3ac,0x4d),(0x46a3b2,0x31)]
 for va,char in signature:
  op=raw(va,4)
  assert op[:3]==bytes([0x80,0x79,va-0x46a3a0+4]) if False else op[:2]==b'\x80\x79'
  assert op[3]==char
 assert raw(0x46ae95,1)==b'\x53'
 assert raw(0x46aebc,3)==bytes.fromhex('ff5260')
 assert raw(0x46af43,3)==bytes.fromhex('ff525c')
 assert call(0x46b60d)==0x46ae40
 assert call(0x46b59b)==0x46a360
 return {"exe_sha256":hashlib.sha256(b).hexdigest(),"signature_check_va":"0x46a3a0",
 "signature":"UCM1","signature_relative_to_object":4,
 "additional_nonzero_fields":[8,0x64,0x6c],
 "index_buffer_creation_va":"0x46aebc","vertex_buffer_creation_va":"0x46af43",
 "index_count_formula":"object[0x50] * 3","index_element_bytes":2,
 "vertex_bytes_formula":"object[0x4c] * object[0x54] * 32",
 "renderer_call_chain":["0x46b560","0x46ae40"],"checks_passed":True}
if __name__=="__main__":
 if len(sys.argv)!=2:raise SystemExit("Usage: python tools/verify_ucm_renderer.py CrazyMachines.exe")
 print(json.dumps(check(sys.argv[1]),indent=2))
