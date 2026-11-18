# Vertex layout regression (2026-11-18)

Audited 160 original UCM models, 55,342 vertices and 22,497 triangles directly from the extracted archive.

A 32-byte vertex record is eight little-endian floats:
- `[0:3]`: candidate XYZ position
- `[3:6]`: strongly supported normal XYZ
- `[6:8]`: candidate UV

**55,329 / 55,342** normal vectors in `[3:6]` have unit length within 0.01. A **shifted legacy mapping** that uses `[4:7]` as normals only has **4,101 / 55,342** unit-length vectors. All values are finite.

Example first vertex of `hammer_body.ucm`:
- XYZ: `(-0.004644656, 0.335355341, -0.050000001)`
- normal: `(0.707106590, 0.707106948, 0)`
- UV candidate: `(0.962000012, -0.702399969)`

**Correction to earlier experimental output:** `cm_build_textured_assets.py` used `v[1:4]` for position, `v[4:7]` for normal, and `(v[0],v[7])` for UV. That mapping is inconsistent with the verified normal-vector distribution. Its generated textured OBJs must be regarded as invalid geometry/UV demonstrations, not as a correct representation of the game models. The current `tools/export_ucm_obj.py` uses the corrected channel ordering.

Reproduce: `python tools/verify_vertex_layout.py crazy_machines_extracted_resources.zip`. No copyrighted game assets committed.
