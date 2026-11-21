#!/usr/bin/env python3
"""Recover and unpack user-owned Crazy Machines installation archives.

Requires cabextract with LZX and multi-volume CAB support. This tool does not
run Windows executables, bundle copyrighted data, or claim iOS compatibility.

Usage: python3 tools/extract_original_installer.py GAME_SETUP.exe OUT_DIR
"""
from pathlib import Path
import hashlib
import shutil
import struct
import subprocess
import sys

EXPECTED_SHA = "8a36dd25e131e5541a8eca71cb7ded32ff93473cef28befaf914a40b9264fe19"
OFFSETS = (396348, 8784956, 17173564, 25562172)
LENGTHS = (8388612, 8388612, 8388612, 1052446)
EXPECTED_COUNTS = (216, 143, 117, 38)


def recover(data: bytes, directory: Path) -> list[Path]:
    if hashlib.sha256(data).hexdigest() != EXPECTED_SHA:
        raise ValueError("Installer hash mismatch: refusing to parse an unknown executable")
    directory.mkdir(parents=True, exist_ok=True)
    result = []
    for i, (offset, size, count) in enumerate(zip(OFFSETS, LENGTHS, EXPECTED_COUNTS)):
        raw = b"MSCF" + data[offset:offset + size - 4]
        if len(raw) != size or raw[:4] != b"MSCF":
            raise ValueError(f"CAB {i}: invalid length/signature")
        declared_size = struct.unpack_from("<I", raw, 8)[0]
        declared_files = struct.unpack_from("<H", raw, 28)[0]
        if (declared_size, declared_files) != (size, count):
            raise ValueError(f"CAB {i}: unexpected header {declared_size}/{declared_files}")
        path = directory / f"{i:04d}.cab"
        path.write_bytes(raw)
        result.append(path)
    return result


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: extract_original_installer.py GAME_SETUP.exe OUT_DIR")
    source, out = Path(sys.argv[1]), Path(sys.argv[2])
    cabinets = recover(source.read_bytes(), out / "cab")
    print(f"Recovered {len(cabinets)} CAB volumes, {sum(EXPECTED_COUNTS)} file entries")
    decoder = shutil.which("cabextract")
    if decoder is None:
        raise SystemExit(
            "CAB recovery succeeded, but cabextract is not installed. "
            "Install a multi-volume LZX-capable cabextract and rerun."
        )
    extracted = out / "unpacked"
    extracted.mkdir(parents=True, exist_ok=True)
    # Begin at the first cabinet: cabextract follows the volume chain.
    # Supplying all volumes separately can duplicate files.
    command = [decoder, "-d", str(extracted), str(cabinets[0])]
    result = subprocess.run(command, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(
            f"cabextract failed ({result.returncode}):\n"
            f"{result.stdout[-3000:]}\n{result.stderr[-3000:]}"
        )
    files = [p for p in extracted.rglob("*") if p.is_file()]
    print(f"Extracted {len(files)} files to {extracted}")
    if len(files) < 100:
        raise RuntimeError("Incomplete extraction: fewer than 100 files recovered")
    print("Original file-to-path mapping and iOS engine compatibility still require validation.")


if __name__ == "__main__":
    main()
