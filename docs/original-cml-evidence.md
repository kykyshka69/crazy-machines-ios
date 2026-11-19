# Original CML laboratory binary observations (2026-11-19)

Source: user-provided `crazy_machines_extracted_resources.zip`, entries under `data/labs/`.
These are observations from **real extracted game files**, not synthetic fixtures.

| Original laboratory | Size | SHA-256 |
|---|---:|---|
| My laboratory | 256 bytes | `0b43d45a6dff72c4ce599787b13fedfd6a802d81e0bf405c8d3267dadc068be7` |
| Professor laboratory | 330,971 bytes | `bd05d755d62a28abf7656d125fd6eec73c496ba6427d30341516da4f42124cc6` |

## Byte-for-byte comparison

At the **same absolute offsets** within the first 256 bytes, both files contain
identical bytes in the half-open ranges **[24, 148)** (124 bytes) and
**[232, 256)** (24 bytes). The first 24 bytes differ, as do bytes [148, 232).
These observations do not establish field boundaries, encoding, encryption,
compression, level counts or item coordinates.

The 330,971-byte Professor file has approximately **7.9991 bits/byte** of
whole-file Shannon entropy; the 256-byte My Laboratory file has approximately
**6.7559 bits/byte**. High entropy suggests that treating Professor CML as
plaintext structures is premature. Compression or obfuscation are possibilities,
**not proven**. The common byte ranges may be constants, shared plaintext under
a deterministic transform, or other shared data.

## Next evidence-based step

Locate the original Windows code that reads CML files and determine whether it
applies a transform before parsing. Validate the inferred transform against
**both** original CML files before implementing any iOS level parser.
No original copyrighted binary bytes are committed to this repository.
