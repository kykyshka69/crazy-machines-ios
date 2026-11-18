#!/usr/bin/env python3
"""Stage a locally owned original UCM/TGA pair for the iOS Metal preview.

This does not assert that the texture is the original engine's material binding.
Run locally; never commit the extracted proprietary assets.
"""
import argparse
import pathlib
import zipfile

def stage(archive, model, texture, output):
    output = pathlib.Path(output)
    with zipfile.ZipFile(archive) as z:
        names = set(z.namelist())
        for name, suffix in ((model, ".ucm"), (texture, ".tga")):
            path = pathlib.PurePosixPath(name.replace("\\", "/"))
            if (name not in names or path.is_absolute() or ".." in path.parts
                    or path.suffix.lower() != suffix):
                raise ValueError("Missing or unsafe archive resource: " + name)
        model_bytes = z.read(model)
        texture_bytes = z.read(texture)
    if model_bytes[:4] != b"UCM1" or len(model_bytes) < 92:
        raise ValueError("Not a UCM1 model")
    if len(texture_bytes) < 18 or texture_bytes[2] != 2 or texture_bytes[16] not in (24, 32):
        raise ValueError("Expected uncompressed RGB/RGBA TGA")
    output.mkdir(parents=True, exist_ok=True)
    (output / "sample.ucm").write_bytes(model_bytes)
    (output / "sample.tga").write_bytes(texture_bytes)
    (output / "sample_model_name.txt").write_text(model + "\n", encoding="utf-8")
    return len(model_bytes), len(texture_bytes)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", help="Locally owned extracted game resource ZIP")
    parser.add_argument("--model", default="data/models/ball_basket.ucm")
    parser.add_argument("--texture", default="data/textures/ball_basket.tga")
    parser.add_argument("--output", default="ios")
    args = parser.parse_args()
    sizes = stage(args.archive, args.model, args.texture, args.output)
    print("Staged UCM/TGA preview:", sizes, "bytes")
