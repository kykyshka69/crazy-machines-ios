# UCM on-disk read path: verified new facts

At `0x46AE95..0x46AEA3`, the loader reads **0x5C = 92 bytes** from the file stream into `object+4` (the object has a vtable pointer at offset 0).

At `0x46AEF0..0x46AF18`, it iterates `object[0x50]*3` times and reads **4 bytes per index** into a temporary integer, then writes its low 16 bits into a graphics index buffer. Thus **file indices are 32-bit; GPU indices are 16-bit**. This corrects earlier experimental descriptions of UCM file indices.

At `0x46AF6A..0x46AF7F`, it reads `object[0x4C]*object[0x54]` records of **32 bytes** into the vertex buffer.

At `0x46AF8A..0x46AFE5`, it reads `object[0x58]` records of **16 bytes**, then allocates `object[0x4C]` pointers and reads **64 bytes per entry** for each of the `object[0x4C]` entries.

Because the file header is copied to `object+4`, the corresponding file header fields are shifted by four bytes:
- `object[0x4C]` = file offset `0x48`: group/section count
- `object[0x50]` = file offset `0x4C`: triangle count
- `object[0x54]` = file offset `0x50`: vertices per group
- `object[0x58]` = file offset `0x54`: 16-byte record count

**Important:** the data after these blocks, optional records and their semantics are not yet fully decoded. We must not claim the full UCM file format is solved.

Reproduce against local original EXE: `python tools/verify_ucm_stream.py CrazyMachines.exe`. The repository does not contain copyrighted game assets.
