#!/usr/bin/env python3
"""Verify mode dispatch and model candidate calls in the original executable."""
import hashlib
import json
import struct
import sys
from pathlib import Path

def inspect(path):
    b = Path(path).read_bytes()
    def at(va, size):
        return b[va - 0x400000:va - 0x400000 + size]
    def call(va):
        raw = at(va, 5)
        if raw[0] != 0xe8:
            raise ValueError(f"Not a near CALL at {va:#x}")
        return va + 5 + struct.unpack("<i", raw[1:])[0]
    dispatch = {hex(x): hex(call(x)) for x in (0x475872, 0x47587f, 0x47588c)}
    assert dispatch == {"0x475872": "0x4757f0", "0x47587f": "0x475740", "0x47588c": "0x4756f0"}
    assert at(0x4756fe, 7).hex() == "c7462801000000"
    calls = {hex(x): hex(call(x)) for x in (0x475705, 0x47570e, 0x47572c)}
    return {"sha256": hashlib.sha256(b).hexdigest(), "dispatcher": dispatch,
            "mode1_setup_calls": calls, "checks_passed": True}

if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python tools/verify_dispatcher.py CrazyMachines.exe")
    print(json.dumps(inspect(sys.argv[1]), indent=2))
