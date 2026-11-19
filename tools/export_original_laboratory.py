#!/usr/bin/env python3
"""Export user-owned original CML scenes to a private JSON directory.

Do not commit or redistribute the generated JSON: it contains original
proprietary puzzle content.
"""
import argparse
import hashlib
from pathlib import Path

from decode_professor_records import PROFESSOR_SHA256, read_professor_records
from decompress_original_level import decode_level_scene
from export_original_scene_json import export_scene, to_json


def export_original_laboratory(data: bytes, destination: Path) -> int:
    if hashlib.sha256(data).hexdigest() != PROFESSOR_SHA256:
        raise ValueError("input is not the verified original Professor Laboratory")
    records = read_professor_records(data, include_payload=True)
    documents = []
    for record in records:
        scene = decode_level_scene(record["payload"])
        documents.append(export_scene(scene, index=record["index"], title=record["name"]))
    # Decode and parse *all* levels before writing any files.
    destination.mkdir(parents=True, exist_ok=True)
    for document in documents:
        target = destination / f"level-{document['index']:03d}.json"
        target.write_text(to_json(document) + "\n", encoding="utf-8")
    return len(documents)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("professor_cml", type=Path)
    parser.add_argument("output_directory", type=Path)
    args = parser.parse_args()
    try:
        count = export_original_laboratory(args.professor_cml.read_bytes(), args.output_directory)
    except (ValueError, OSError, UnicodeError) as error:
        parser.error(str(error))
    print(f"Exported {count} original scenes to {args.output_directory} (private user-owned files)")


if __name__ == "__main__":
    main()
