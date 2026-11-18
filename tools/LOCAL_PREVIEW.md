# Preview with original game assets (local only)

The app's Metal view reads `sample.ucm` and `sample.tga` from the app bundle.
These files are **not** included in this repository.

With a locally owned extracted resource archive, run:

```bash
python3 tools/stage_local_preview.py /path/to/crazy_machines_extracted_resources.zip \
  --model data/models/ball_basket.ucm \
  --texture data/textures/ball_basket.tga \
  --output ios
```

Then generate the Xcode project and build the app on macOS using Xcode.
The UCM and TGA are copied into the iOS source/resource directory only on
your local machine; the repository ignores these file types.

The texture is a **preview pairing**, not proof of the original game's
per-submesh shader/material mapping. Compare the Metal output with the
independently rendered reference before trusting UV orientation or lighting.

This script does not build an IPA, run an iOS simulator, or verify device output.
