#!/usr/bin/env python3
"""Extract the PRIVATE 102-level SceneKit CSV from local xcresult attachments.

Never searches public CI or uploads anything. The attachment belongs only
to testPrivateAll102OriginalLevelsWhenOptedIn and contains no PC artwork.
"""
import argparse
import csv
import io
import json
from pathlib import Path

TEST_ID = (
    "CrazyMachinesLaunchUITests/"
    "testPrivateAll102OriginalLevelsWhenOptedIn()"
)
ATTACHMENT = "PRIVATE-102-original-levels-SceneKit.csv"
HEADER = [
    "level", "title", "loaded_ucm_nodes", "glow_billboards", "status"
]


def export_private_report(attachments: Path, output: Path) -> int:
    manifest = json.loads((attachments / "manifest.json").read_text(encoding="utf-8"))
    candidates = []
    for test in manifest:
        if test.get("testIdentifier") != TEST_ID:
            continue
        for item in test.get("attachments", []):
            title = item.get("suggestedHumanReadableName", "")
            if title == ATTACHMENT or title.startswith(ATTACHMENT + "_"):
                candidates.append(item.get("exportedFileName", ""))

    if len(candidates) != 1:
        raise ValueError("Expected exactly one private 102-level CSV attachment")
    filename = candidates[0]
    if not filename or Path(filename).name != filename:
        raise ValueError("Unsafe exported attachment filename")
    content = (attachments / filename).read_bytes()
    records = list(csv.reader(io.StringIO(content.decode("utf-8-sig"))))
    if not records or records[0] != HEADER:
        raise ValueError("Invalid private 102-level CSV header")
    if not 1 <= len(records) - 1 <= 102:
        raise ValueError("Invalid number of reported original levels")
    for index, row in enumerate(records[1:], 1):
        if len(row) != 5 or row[0] != str(index):
            raise ValueError(f"Original level {index} missing or out of order")
        if row[4] not in ("loaded", "missing-original-meshes"):
            raise ValueError(f"Unexpected status for original level {index}")
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(content)
    return len(records) - 1


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--attachments-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    levels = export_private_report(args.attachments_dir, args.output)
    print(f"Exported {levels} locally inspected original levels to: {args.output}")


if __name__ == "__main__":
    main()
