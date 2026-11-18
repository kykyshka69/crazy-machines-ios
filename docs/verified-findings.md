# Verified observations and limits

- A local reverse-engineering pass found the literal ASCII string `FAKT3D_GFX_MODEL` at virtual address `0x4EE588` in the examined executable.
- A call near `0x475A47` targets `0x4756F0` on a branch associated with that string. This is **not** proof that the target parses UCM1.
- A previous candidate at `0x47DC60` was traced to `scripts/shaders/shaders.shd`, and should **not** be described as the UCM decoder.
- The current UCM first-mesh layout hypothesis uses an 88-byte header, 12 bytes per face and 32 bytes per vertex. These assumptions require validation against the original loader and must not be treated as the full file specification.
- No complete UCM decoder, material/UV mapping or iOS game is verified.

Reproduction: run `python tools/trace_model.py /path/to/CrazyMachines.exe` against your own legally obtained local copy. The section mapping is specific to the analyzed executable build.
