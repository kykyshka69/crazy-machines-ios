#!/usr/bin/env python3
"""Create a tiny synthetic UCM1 v1 fixture (not a game asset)."""
import struct,sys
from pathlib import Path
header=bytearray(92)
header[:4]=b'UCM1'
struct.pack_into('<I',header,4,1)
struct.pack_into('<5I',header,72,1,1,3,0,0)
indices=struct.pack('<3I',0,1,2)
vertices=b''.join(struct.pack('<8f',*p,0,0,1,0,0) for p in ((0,0,0),(1,0,0),(0,1,0)))
Path(sys.argv[1]).write_bytes(header+indices+vertices)
