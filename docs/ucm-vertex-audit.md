# UCM vertex field audit

Original local extracted game archive: 160 UCM models, 55,342 vertex records (32 bytes each).

A record is consistent with eight little-endian IEEE-754 floats:
- floats 0–2: **likely** XYZ position;
- floats 3–5: **strongly supported** surface normal; 55,329 of 55,342 have length within 0.01 of 1;
- floats 6–7: **likely** UV texture coordinates.

All vertex records contained finite float values. The non-unit normals include zero-length normals in `steam_body.ucm`. `rope_crossbow_body.ucm` contains UV-like fields equal to approximately ±431,602,080, which should be treated as anomalous until validated in the original renderer.

These field meanings remain hypotheses pending confirmation from vertex declarations and rendering calls. Never silently clamp or replace raw data in a lossless parser.

Reproduce with `python tools/audit_ucm_vertices.py crazy_machines_extracted_resources.zip`. No game data is stored in this repository.
