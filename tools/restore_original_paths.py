#!/usr/bin/env python3
"""Restore original Crazy Machines paths for extracted 0..509 CAB entries.

Input: user-owned verified Smart Install Maker installer and a directory of
510 LZX-decompressed files named 0, 1, ... 509.
Output: original installation tree, preserving case and CP1251 file names.
No original game binaries or resources are included in this repository.

Example:
  python tools/restore_original_paths.py setup.exe unpacked_numeric private_install
"""
import argparse
import hashlib
import re
from pathlib import Path

INSTALLER_SHA = "8a36dd25e131e5541a8eca71cb7ded32ff93473cef28befaf914a40b9264fe19"


def restore(installer: Path, numeric: Path, output: Path) -> int:
    payload = installer.read_bytes()
    digest = hashlib.sha256(payload).hexdigest()
    if digest != INSTALLER_SHA:
        raise ValueError(f"Installer SHA256 mismatch: {digest}")
    entries = re.findall(rb"@\$&%04\\([^\x00]+)", payload[180736:220000])
    paths = [entry.decode("cp1251").replace("\\", "/") for entry in entries[12:]]
    if len(paths) != 510:
        raise ValueError(f"Expected 510 installer paths, found {len(paths)}")
    if len(set(path.lower() for path in paths)) != 510:
        raise ValueError("Duplicate installer paths")
    if (paths[5], paths[8], paths[10], paths[508]) != (
        "CrazyMachines.exe", "data/labs/Лаборатория Профессора.cml",
        "data/models/arrow.ucm", "scripts/strings/main.txt"
    ):
        raise ValueError("Original installer path mapping verification failed")
    # Validate the complete input before creating the output tree.
    for i, name in enumerate(paths):
        path = Path(name)
        if path.is_absolute() or any(part in (".", "..") for part in path.parts):
            raise ValueError(f"Unsafe installer path: {name}")
        if not (numeric / str(i)).is_file():
            raise ValueError(f"Missing decompressed CAB entry {i}")
    for i, name in enumerate(paths):
        src = numeric / str(i)
        dst = output / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        if dst.exists():
            raise ValueError(f"Destination file already exists: {dst}")
        dst.write_bytes(src.read_bytes())
    return len(paths)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("installer", type=Path)
    parser.add_argument("numeric_files", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    print(f"Restored {restore(args.installer, args.numeric_files, args.output_directory)} original files")


if __name__ == "__main__":
    main()
