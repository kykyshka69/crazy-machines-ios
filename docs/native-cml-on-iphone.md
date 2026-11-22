# Native original CML import on iPhone

The original Crazy Machines iOS app now has a **direct CML import path**. It no longer requires the user to run a Python JSON exporter on a PC before browsing the game's original level data.

## How to use

1. Transfer the original `Professor Laboratory.cml` (from your own Windows game installation) to the Files app on iPhone.
2. In **Original levels**, tap **Import original CML laboratory** and choose that file. The decoder runs off the UI thread.
3. Alternatively, in **Original files** import the game's `.cml` and `.ucm` resource files or their folder. Then open **Original levels** and tap **Decode previously imported CML**. The app selects the nonempty CML with the greatest validated original record count (not an empty laboratory).
4. Open an imported level, tap **3D view**, and use **Verify original UCM geometry** to identify missing or invalid model files.

The actual original CML and UCM files remain in user-controlled private storage. No proprietary level data is committed to GitHub. A converted level's generated JSON preserves the original `scene_sha256` and original object fields.

## Implemented decoding path

- Original Windows `0x47E610` keyed framing and validation of all three header fields
- Per-record flag, payload size, CP1251 title and level payload
- Big-endian fixed-width 12-bit LZW with terminating code `4095`
- Windows-1251 scene text, standalone-brace scene nodes, original fields, transforms, original `3DO` meshes and separate `tmo_*` object ownership
- Exact SHA-256 for the unpacked original scene bytes
- Shared validation with `CMOriginalSceneDocument.read` and safe save as `level-001.json` etc.
- Existing level files are not overwritten when a different original scene has the same index.

## What has been checked

An end-to-end Swift/Foundation smoke test using a self-generated, **non-copyrighted** CML laboratory and an original-format LZW-compressed scene confirms native framing, decoding, CP1251 names, original model ownership, scene hash, safe storage and several malformed-input rejections. Independent Python-generated encrypted-frame bytes are also part of this regression.

**Still not verified**: decoding all 102 genuine Professor puzzles from a licensed original CML **on a physical iPhone or the iPhone Simulator**, Apple's full Xcode build of the latest sources, correct original scene geometry/materials, original puzzle physics, win conditions, or a genuine first-level screenshot. Those require running the app with original user-owned files through the macOS/iPhone workflow. A successful synthetic regression alone is not a playable game.
