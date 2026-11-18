# Crazy Machines — iOS research

Private reverse-engineering workspace for investigating the original Crazy Machines game's proprietary UCM model format and preparing a future iOS implementation.

## Verified status
- The original Windows game and extracted resources are available **outside this repository**.
- UCM model files use a `UCM1` signature; the complete multi-section geometry, UV and materials layout is **not yet decoded**.
- A reference to `FAKT3D_GFX_MODEL` was traced in the Windows executable. The related function at `0x4756F0` is a **candidate** model handler, not a confirmed UCM decoder.
- There is **no playable iOS port** at this time.

## Next engineering work
1. Disassemble the candidate model-handler function and establish its callers and callees.
2. Verify a concrete code path that reads UCM bytes.
3. Build reproducible tests using local game assets; do not commit copyrighted game files.
4. Decode the full model layout and validate against original assets before attempting gameplay reconstruction.

## Legal and data hygiene
Do not commit original game binaries, models, textures, audio, level data or game installer. Research scripts and independently authored notes only.
