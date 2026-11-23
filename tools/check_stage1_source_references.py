#!/usr/bin/env python3
"""Guard against Git tree updates silently dropping referenced Swift files."""
import re
from pathlib import Path

root = Path(__file__).resolve().parent.parent
manifests = (
    "scripts/run-local-checks.sh",
    "scripts/check-stage1-mechanics-fast.sh",
    ".github/workflows/source-checks.yml",
    ".github/workflows/portable-checks.yml",
    ".github/workflows/ios-device-build.yml",
    ".github/workflows/ios-simulator-build.yml",
)
source_path = re.compile(r"(?<![\\w/])(?:ios|tests)/[A-Za-z0-9_.-]+\\.swift\\b")
missing = set()
for relative in manifests:
    file = root / relative
    if not file.is_file():
        missing.add(relative)
        continue
    for matched in source_path.findall(file.read_text(encoding="utf-8")):
        if not (root / matched).is_file():
            missing.add(f"{relative}: {matched}")
if missing:
    raise SystemExit("Missing referenced Swift source(s):\\n" + "\\n".join(sorted(missing)))
print("Stage-1 Swift source manifest: all referenced files exist")
