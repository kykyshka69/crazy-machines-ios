#!/usr/bin/env python3
"""Verify original Win32 power-disrupter phase gate from one private EXE.

Only reads, hashes and checks the owner's binary. Never exports game data.
"""
import argparse
import hashlib
import struct
from pathlib import Path

SHA256 = "51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6"
SITES = {
    # 0x44C8A0 is the original recursive electrical endpoint dispatcher.
    0x44C8A0: "55 8b ec 83 ec 50",
    0x44C8C1: "0f be 91 78 01 00 00",   # cycle-guard status byte
    0x44C8E5: "8b 55 08",              # +0x50 flagged source blocks signal
    0x44C8E8: "c7 42 40 00 00 00 00",
    0x44C8F2: "8b 4d 08 8b 51 40 89 50 40", # propagate original +0x40
    0x44C988: "89 42 40",              # fan out to next original endpoint
    0x44C98B: "68 10 c6 4e 00",       # tmo_power_switch selector
    0x44CA30: "68 24 c6 4e 00",       # tmo_power_disrupter selector
    0x44CA59: "68 db 0f 49 40",       # exact single-precision Pi
    0x44CA68: "e8 f3 66 fb ff",       # call 0x403160 -> x87 remainder
    0x44CA70: "d9 5d d8",             # store signed phase
    0x44CA73: "d9 45 d8 d8 1d 9c 3b 4f 00", # phase compared with 0.0
    0x44CA83: "d9 45 d8 d8 1d bc dd 4e 00", # phase versus -Pi/2
    0x44CA93: "d9 45 d8 d8 1d 5c 82 4e 00", # phase versus -Pi
    0x44CAA3: "8b 4d e4 c7 41 40 00 00 00 00", # gate clears signal
    0x44CAAF: "d9 45 d8 d8 1d f4 be 4e 00", # phase versus +Pi/2
    0x44CABF: "8b 55 e4 c7 42 40 00 00 00 00", # gate clears signal
    0x44CACC: "d9 05 9c 3b 4f 00", # branch may update switch state
}
FLOATS = {
    0x4F3B9C: 0.0,
    0x4E763C: -1.0,
    0x4E7A8C: 10.0,
    0x4EDDBC: -1.5707963705062866,
    0x4E825C: -3.1415927410125732,
    0x4EBEF4: 1.5707963705062866,
}

def verify(data: bytes) -> dict[str, int]:
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise ValueError("Wrong executable hash; refusing unrelated Win32 game")
    if data[:2] != b"MZ":
        raise ValueError("Not a Windows executable")
    pe = struct.unpack_from('<I', data, 0x3C)[0]
    if data[pe:pe+4] != b"PE\0\0":
        raise ValueError("Invalid PE header")
    nsections = struct.unpack_from('<H', data, pe+6)[0]
    header_size = struct.unpack_from('<H', data, pe+20)[0]
    opt = pe+24
    if struct.unpack_from('<H', data, opt)[0] != 0x10B:
        raise ValueError("Expected PE32")
    base = struct.unpack_from('<I', data, opt+28)[0]
    sections = []
    for i in range(nsections):
        offset = opt+header_size+40*i
        _, vsize, rva, rawsize, raw = struct.unpack_from('<8sIIII', data, offset)
        sections.append((base+rva, rawsize, raw))
    def off(va: int) -> int:
        for start, length, raw in sections:
            if start <= va < start+length:
                return raw+va-start
        raise ValueError(f"Invalid RVA 0x{va:X}")
    for va, pattern in SITES.items():
        expected=bytes.fromhex(pattern)
        if data[off(va):off(va)+len(expected)] != expected:
            raise ValueError(f"Disrupter Win32 opcode mismatch at 0x{va:X}")
    for va, value in FLOATS.items():
        actual=struct.unpack_from('<f', data, off(va))[0]
        if actual != value:
            raise ValueError(f"Disrupter Win32 float mismatch at 0x{va:X}")
    for addr, ident in [(0x4EC610,b'tmo_power_switch\0'),
                        (0x4EC624,b'tmo_power_disrupter\0')]:
        if not data[off(addr):].startswith(ident):
            raise ValueError(f"Disrupter selector mismatch at 0x{addr:X}")
    return {'verified_sites':len(SITES),'float_constants':len(FLOATS),'original_types':2}

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('original_exe',type=Path)
    result=verify(parser.parse_args().original_exe.read_bytes())
    print('Original Windows power disrupter confirmed:',result)