#!/usr/bin/env python3
"""Stage the verified ORIGINAL Professor CML for on-device iPhone level decoding.

No game bytes are committed or uploaded. A Python reference decode of level 1
is used ONLY to check the UCM inventory before the real iOS CML decoder runs.
The scene JSON is deliberately not copied to the simulator: it must be
produced from the genuine CML by the iPhone app itself.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import tempfile

from decode_professor_records import PROFESSOR_SHA256, read_professor_records
from decompress_original_level import decode_level_scene
from export_original_scene_json import export_scene, to_json
from stage_original_first_level import stage as stage_with_scene


def stage_original_cml(cml_path, ucm_directory, output_dir):
    cml_path, ucm_directory, output_dir = map(
        Path, (cml_path, ucm_directory, output_dir))
    if not cml_path.is_file() or not (256 <= cml_path.stat().st_size <= 64 * 1024 * 1024):
        raise ValueError("original Professor Laboratory CML missing or oversized")
    original = cml_path.read_bytes()
    if hashlib.sha256(original).hexdigest() != PROFESSOR_SHA256:
        raise ValueError("CML SHA256 does not match the verified original Professor Laboratory")
    records = read_professor_records(original, include_payload=True)
    if len(records) != 102:
        raise ValueError("original Professor Laboratory must contain 102 puzzles")
    scene = decode_level_scene(records[0]["payload"])
    first = export_scene(scene, index=1, title=records[0]["name"])
    with tempfile.TemporaryDirectory(prefix="cm-original-level-validation-") as tmp:
        scene_path = Path(tmp) / "level-001.json"
        scene_path.write_text(to_json(first), encoding="utf-8")
        report = stage_with_scene(scene_path, ucm_directory, output_dir)
    # Do NOT seed level JSON. The UI test must invoke the native CML decoder
    # to create level-001.json in Application Support at test runtime.
    (output_dir / "OriginalScenes" / "level-001.json").unlink()
    target = output_dir / "OriginalGame" / "Professor Laboratory.cml"
    shutil.copyfile(cml_path, target)
    report.update({
        "original_cml_sha256": PROFESSOR_SHA256,
        "native_ios_cml_decode_required": True,
        "reference_original_level_1_sha256": first["scene_sha256"],
        "verified_professor_record_count": len(records),
    })
    (output_dir / "staging-report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("original_professor_cml", type=Path)
    parser.add_argument("original_ucm_directory", type=Path)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(stage_original_cml(
            args.original_professor_cml, args.original_ucm_directory,
            args.output_dir), ensure_ascii=False, indent=2))
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(2, "Cannot stage real original CML: " + str(error) + "\n")


if __name__ == "__main__":
    main()
