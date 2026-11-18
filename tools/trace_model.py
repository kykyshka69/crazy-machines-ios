#!/usr/bin/env python3
"""Find executable string references relevant to model-loading research.

Usage: python tools/trace_model.py /path/to/CrazyMachines.exe
Produces JSON on stdout; does not modify or distribute the game executable.
"""
import hashlib
import json
from pathlib import Path
import struct
import sys

SECTIONS = [
    (".text", 0x1000, 0x1000, 0xE59E0),
    (".rdata", 0xE7000, 0xE7000, 0x15648),
]
IMAGE_BASE = 0x400000
TERMS = [b"FAKT3D_GFX_MODEL", b"MODEL\x00", b"PNT1Count\x00", b"PRC2T1Count\x00"]


def analyze(path):
    data = Path(path).read_bytes()

    def va(offset):
        for _name, file_offset, rva, size in SECTIONS:
            if file_offset <= offset < file_offset + size:
                return IMAGE_BASE + rva + offset - file_offset
        return None

    code = data[0x1000:0xE69E0]
    results = {"exe_sha256": hashlib.sha256(data).hexdigest(), "terms": []}
    for term in TERMS:
        start = 0
        while True:
            pos = data.find(term, start)
            if pos < 0:
                break
            start = pos + 1
            address = va(pos)
            if address is None:
                continue
            needle = struct.pack("<I", address)
            matches = []
            search_start = 0
            while True:
                index = code.find(needle, search_start)
                if index < 0:
                    break
                search_start = index + 1
                offset = index + 0x1000
                preceding = data[offset - 1] if offset else None
                matches.append({
                    "instruction_candidate_va": (
                        hex(va(offset - 1))
                        if preceding in (0x68, 0xB8, 0xB9, 0xBA, 0xBB, 0xBE, 0xBF)
                        else None
                    ),
                    "operand_va": hex(va(offset)),
                    "preceding_opcode": hex(preceding),
                })
            results["terms"].append({
                "text": term.decode(errors="replace"),
                "file_offset": pos,
                "virtual_address": hex(address),
                "references": matches,
            })
    return results


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python tools/trace_model.py /path/to/CrazyMachines.exe")
    print(json.dumps(analyze(sys.argv[1]), indent=2))
