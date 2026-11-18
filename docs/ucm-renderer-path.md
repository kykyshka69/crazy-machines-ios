# UCM1 validation and renderer path (verified 2026-11-18)

Original executable SHA-256: `51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6`.

**New confirmed result:** `0x46A3A0` checks the ASCII bytes `UCM1` at offsets `+4..+7` of an in-memory object, then requires fields at `+8`, `+0x64`, `+0x6C` to be nonzero. This is the first verified *UCM-specific* function in this research path.

At `0x46B560` the program allocates 0x84 bytes and constructs an object via `0x46A360`. It calls `0x46AE40` at `0x46B60D`. That function validates the object using `0x46A3A0`, then prepares graphics buffers:
- `0x46AEBC`: virtual call at `[vtable+0x60]` for an index buffer, with `object[0x50] * 3 * 2` bytes (three 16-bit indices per face).
- `0x46AF43`: virtual call at `[vtable+0x5C]` for a vertex buffer, with `object[0x4C] * object[0x54] * 32` bytes.
- `0x4D5A29` is used to read data into the buffers; its precise stream semantics require additional verification.

**Interpretation:** this path is demonstrably UCM-aware and builds Direct3D-like buffers. It does *not yet* establish the on-disk file parser, multi-section layout, or all vertex attributes. Do not equate object offsets with on-disk offsets without proving the object construction.

Reproduce: `python tools/verify_ucm_renderer.py CrazyMachines.exe`; or disassemble ranges `0x46A3A0..0x46A3D6` and `0x46AE40..0x46AF50`.
