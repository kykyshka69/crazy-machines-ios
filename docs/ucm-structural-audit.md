# UCM1 structural audit — 160 models

Validated directly against the 160 UCM files in the original extracted resource archive (case-insensitive extension matching).

The executable's stream-read routine at 0x46AE40 reads:
1. 92-byte header.
2. `triangle_count * 3` 32-bit indices.
3. `group_count * vertex_count * 32` vertex bytes.
4. `record_count * 16` bytes.
5. `group_count` blocks, each `record_count * 64` bytes.
6. If version > 1: two uint32 counts A and B, followed by `A*16 + B*60` bytes.

This produces **exact file lengths for all 160/160 models** (159 version 2; one version 1). All 160 index arrays fit within the aggregate vertex count. The original game binaries and resource data are not committed.

The exact match establishes the byte-level structural block lengths, **not** the semantics of every vertex field, extension record, or materials. Multi-section rendering and iOS gameplay are not yet solved.

Run the audit against your own legally obtained extracted archive. See `tools/audit_ucm_structure.py`.
