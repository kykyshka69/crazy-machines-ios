#!/usr/bin/env python3
"""Select ONLY the named, genuine level-one screenshot from Xcode's UI test bundle.

Never substitute arbitrary XCT failure attachments or other simulator screens.
Consumes xcresulttool export attachments manifest.json and its test summary.
"""
import argparse
import json
from pathlib import Path
import shutil
import struct

TEST_NAME = "testPrivateOriginalLevelOneWhenOptedIn"
ATTACHMENT_NAME = "07-PRIVATE-original-professor-level-001"
ATTACHMENT_NAME_LEVEL_TWO = "09-PRIVATE-original-professor-level-002"
ATTACHMENT_NAME_LEVEL_THREE = "11-PRIVATE-original-professor-level-003"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def validate_summary(summary):
    """A skipped or unexecuted test is not a successful screenshot run."""
    if not isinstance(summary, dict):
        raise ValueError("invalid Xcode test summary")
    fields = ("totalTestCount", "passedTests", "failedTests", "skippedTests")
    if any(type(summary.get(field)) is not int for field in fields):
        raise ValueError("Xcode test summary is missing numeric run counters")
    if (summary["totalTestCount"] != 1 or summary["passedTests"] != 1
            or summary["failedTests"] or summary["skippedTests"]):
        raise ValueError("real first-level UI test was not the sole passing test")


def find_exact_attachment(manifest, export_directory, attachment_name=ATTACHMENT_NAME):
    """Require the exact named attachment from the exact original-level UI test."""
    if not isinstance(manifest, list):
        raise ValueError("invalid Xcode attachment manifest")
    found = []
    for record in manifest:
        if not isinstance(record, dict):
            raise ValueError("invalid Xcode attachment record")
        test_id = record.get("testIdentifier")
        if not isinstance(test_id, str) or TEST_NAME not in test_id:
            continue
        attachments = record.get("attachments", [])
        if not isinstance(attachments, list):
            raise ValueError("invalid attachment list")
        for item in attachments:
            if not isinstance(item, dict):
                raise ValueError("invalid screenshot attachment")
            name = item.get("suggestedHumanReadableName", "")
            if not isinstance(name, str):
                continue
            if name != attachment_name and not name.startswith(attachment_name + "_"):
                continue
            exported = item.get("exportedFileName", "")
            if not isinstance(exported, str):
                raise ValueError("missing screenshot file name")
            relative = Path(exported)
            if (not exported or relative.name != exported
                    or exported in (".", "..") or relative.suffix.lower() != ".png"):
                raise ValueError("unsafe or invalid Xcode screenshot file name")
            found.append(export_directory / exported)
    if len(found) != 1:
        raise ValueError("expected exactly one named first-original-level screenshot")
    return found[0]


def validate_png(path):
    """Reject empty, non-PNG or thumbnail attachments."""
    try:
        with path.open("rb") as file:
            header = file.read(24)
    except OSError as exc:
        raise ValueError("named first-level screenshot could not be read") from exc
    if (len(header) != 24 or not header.startswith(PNG_SIGNATURE)
            or header[12:16] != b"IHDR" or struct.unpack(">I", header[8:12])[0] != 13):
        raise ValueError("named first-level attachment is not a valid PNG header")
    width, height = struct.unpack(">II", header[16:24])
    if width < 200 or height < 300:
        raise ValueError("named first-level screenshot has unexpected dimensions")
    if path.stat().st_size <= 33:
        raise ValueError("named first-level screenshot contains no PNG image payload")


def select_screenshot(export_directory, summary, destination,
                      attachment_name=ATTACHMENT_NAME):
    export_directory = Path(export_directory)
    destination = Path(destination)
    validate_summary(summary)
    manifest = json.loads((export_directory / "manifest.json").read_text(encoding="utf-8"))
    if attachment_name not in (
        ATTACHMENT_NAME, ATTACHMENT_NAME_LEVEL_TWO, ATTACHMENT_NAME_LEVEL_THREE
    ):
        raise ValueError("unknown authentic original-level screenshot name")
    source = find_exact_attachment(manifest, export_directory, attachment_name)
    validate_png(source)
    if destination.resolve() == source.resolve():
        return source
    if destination.exists():
        raise ValueError("refusing to overwrite an existing screenshot")
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    return destination


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--attachments-dir", required=True, type=Path)
    parser.add_argument("--summary", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--attachment-name", default=ATTACHMENT_NAME,
                        choices=[ATTACHMENT_NAME, ATTACHMENT_NAME_LEVEL_TWO,
                                 ATTACHMENT_NAME_LEVEL_THREE])
    args = parser.parse_args()
    try:
        summary = json.loads(args.summary.read_text(encoding="utf-8"))
        output = select_screenshot(args.attachments_dir, summary, args.output,
                                   args.attachment_name)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as exc:
        parser.exit(2, "Authentic first-level capture not confirmed: " + str(exc) + "\n")
    print(output)


if __name__ == "__main__":
    main()
