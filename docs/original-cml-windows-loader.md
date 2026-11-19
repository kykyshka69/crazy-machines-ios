# Original Windows CML load path: verified x86 references

Inspected the **user-provided original** `CrazyMachines.exe` extracted from
`crazy_machines_extracted_resources.zip` (PE32 i386, image base 0x400000).
All addresses below are **virtual addresses**, not file offsets.

## Evidence in executable

- The laboratory enumeration pattern `data/labs/*.cml` resides in
  `.rdata` at **0x4EBCD0**.
- The C string `930%&g/2ANUBIS=!s?p$` begins at **0x4EBCE4**.
- At **0x4474C7**, the game executes `push 0x4EBCE4`, passing the
  address of that string to a function invoked at **0x478F10**
  (call instruction **0x4474F5**). The call also receives a pointer
  into the current laboratory object and a constant `0x40`.
- The return value is tested at **0x447500–0x447507**. On zero,
  control branches to an error-reporting path with
  `could_not_be_load` / `Laboratory '%s' has wrong format: %s !!!`
  strings nearby in the same read-only data section.
- Another comparison follows at **0x44757D** (call to **0x4043D0**)
  using two buffers within the laboratory object. This likely validates
  some loaded metadata, but its precise meaning remains unproven.

## Interpretation and next reverse-engineering target

The string `930%&g/2ANUBIS=!s?p$` is a **strong candidate for a
format-specific key or passphrase**, because its address is explicitly
passed to a laboratory-related loader. **It is not yet proven to be an
encryption key**; do not apply arbitrary XOR or cipher algorithms based
on its appearance alone.

**Next target: disassemble the function at 0x478F10**, then follow
its file-read and transform calls. Validate the resulting decoder against
both original laboratory files before exposing decoded objects in iOS.

This document contains only brief format evidence and no proprietary
original game asset bytes.

## Direct disassembly of 0x478F10 and 0x47E880

Rechecked against original PE32 executable using
`objdump -D -Mintel --start-address=0x478f10 --stop-address=0x479130`
and `--start-address=0x47e880 --stop-address=0x47e940`.

At 0x478F10 the routine clears an output buffer, prepares an input stream,
then makes successive calls to **0x47E880**. In the observed sequence:

| Call site | Length argument | Destination relative to object |
|---|---:|---|
| 0x478FB8 | 4 bytes | object + 0x0C (after increment) |
| 0x478FF8 | 0x50 bytes | local temporary buffer + 0x14 |
| 0x479023 | 4 bytes | object + 0x164 |
| 0x47905E | variable | object-provided buffer (conditional) |
| 0x47908A | 4 bytes | object + 0x10 |

**Correction to earlier interpretation:** the string at 0x4EBCE4 is
indeed passed as the fourth argument to 0x478F10, but at 0x478F8A it is
loaded into ESI and passed onward to 0x47E880. It is not yet proven to
be a cryptographic key.

The wrapper at **0x47E880** allocates a temporary buffer with
`0x4D42AC`, reads bytes via `0x4D5A29`, checks the read length,
then calls **0x47E610** to process the buffer, before releasing it
with `0x4D42A7`.

This is an important verified separation: **0x47E880 is a read-and-process
wrapper, while 0x47E610 is the next concrete transform candidate.**
The precise 0x47E610 algorithm has not been established.

## Breakthrough: first genuine CML frame successfully decoded

The original loader at 0x478FB8 passes the **20-byte** key
`930%&g/2ANUBIS=!s?p$` and a **4-byte payload length** to
0x47E880. The wrapper reads **24 bytes** (payload + key) and passes
them to 0x47E610.

The 0x47E610 read branch performs, in order:

1. Reverse the 20-byte key to obtain operation control pairs.
2. Apply the reverse adjacent-byte transform to the **entire encoded frame**.
3. Dispatch operations from the reversed key to the frame.
4. Compare the first 20 decoded bytes against the **original key**.
5. Remove the 20-byte prefix and return the requested payload.

**Executed against the original extracted 256-byte My Laboratory file:**
the first 24-byte frame passes the full key comparison, and its 4-byte
decoded payload is exactly `00 00 00 00`.

The second field is an 80-byte payload within a 100-byte encoded frame
at offsets [24,124), and the third is a 4-byte payload within [124,148).
Both also pass the key comparison; the third decoded value is
`00 00 00 00`. The 80-byte field begins `00 cd cd cd ...`,
consistent with uninitialized/debug-filled storage but **not yet
identified as a game-level structure**.

This is **verified decryption of actual original CML header fields**,
not yet decryption of the Professor laboratory's level records.
The next encoded fields require following the loader's conditional
branch at 0x47902E rather than assuming a fixed frame sequence.

Read-only code: `tools/cml_byte_transforms.py` and
`tools/decode_original_lab_header.py`.

## Confirmed original record count from decoded field (local execution)

Executed the recovered decoder against **both original CML files**,
verifying their SHA-256 hashes and the **full 20-byte key prefix** in
each of the first three frames.

| File | First decoded 4-byte field (hex) | Little-endian integer |
|---|---|---:|
| My Laboratory (256 bytes) | `00000000` | **0** |
| Professor Laboratory (330971 bytes) | `66000000` | **102** |

The Professor count **102** independently agrees with the **102**
observed 21-byte candidate markers. This is much stronger evidence
that the first decoded field is a **record count** rather than an
arbitrary value. It does **not** yet prove that every record is a
separately selectable puzzle or that object geometry has been decoded.

The other decoded 4-byte field at offsets [124,148) is zero in both
files. The 80-byte middle field begins `00 cd cd cd ...` in both.

Reproducible verification: run
`python tools/decode_original_lab_header.py MY_LAB.cml PROFESSOR_LAB.cml`
using the original extracted files. The tool checks both original file
hashes and fails on an unexpected record count.

## Full Professor Laboratory decoded — 102 authentic named records

Following original Windows reader **0x47F9E0**, each record contains
four separately keyed and encrypted fields:

| Field | Decoded length |
|---|---:|
| Flag | 1 byte |
| Payload size | 4 bytes, unsigned little-endian |
| Name | 80 bytes, null-terminated CP1251 |
| Opaque puzzle payload | Variable, from decoded size field |

Each field has an additional 20-byte encoded key prefix. The resulting
record consumes `1+20 + 4+20 + 80+20 + payload_length+20` bytes,
or **165 + payload_length**.

**Executed on the original 330,971-byte Professor file:** all 102
records independently passed key validation and all boundaries matched
exactly, with final offset **330,971** and no trailing bytes.

Examples from the real original records:

| Index | Original Russian puzzle name | Decoded opaque payload bytes |
|---|---|---:|
| 1 | Сначала наведем порядок | 2240 |
| 2 | Эффект домино | 2893 |
| 3 | Уборщик | 2361 |
| 4 | Магнетизм | 2021 |
| 5 | Все вместе взятое 1 | 2772 |
| 6 | Паровой свисток | 3197 |
| 7 | Жареная колбаса | 3129 |
| 8 | Обед | 4481 |
| 100 | Долой шар | 4416 |
| 101 | Плотник | 6070 |
| 102 | Завершение | 3380 |

This **confirms the 102 records are named original laboratory
challenges**, not invented placeholders. Their payloads have been
decrypted to bytes but their internal object and coordinate structures
remain to be parsed.

Reproduce with
`python tools/decode_professor_records.py PROFESSOR_LAB.cml`
(or `--json` for lengths, offsets, hashes, names). No copyrighted
puzzle bytes are committed.

## First original puzzle instructions decoded from inner payload

After decrypting the *outer* laboratory record, the inner puzzle
payload is **not** another encrypted CML record. Its first four bytes
are a little-endian size for a binary section, followed by additional
binary metadata and, in some puzzles, further variable-length sections.

**Verified against the original file:** for challenges **1–5** the
first section size plus eight bytes locates a 4-byte CP1251 instruction
length. The following bytes decode to genuine Russian instructions.
For example:

- **1 — Сначала наведем порядок:** begins
  `Добро пожаловать в мою лабораторию, дилетант!`
- **2 — Эффект домино:** begins
  `Итак, теперь можно по-настоящему взяться за дело.`
- **3 — Уборщик:** begins
  `Видишь эту пирамиду ящиков?`

For challenge 1, the binary-section size is **1755 bytes**, the
instruction text length is **469 bytes**, and the final 4-byte
little-endian value is **200**. The bounds reconcile with the original
**2240-byte** payload.

**Important:** The same simple instruction offset does **not** work
for all 102 challenges; from challenge 6 onward, some records contain
additional binary sections. The conservative parser
`tools/cml_puzzle_instructions.py` rejects unsupported layouts rather
than mislabeling binary data as text. The binary object/coordinate
structure is still under investigation.

## Inner puzzle binary section identified across all 102 records

Locally decrypted and inspected **all 102 original Professor puzzles**.
Each decoded payload begins with a **4-byte little-endian length**,
followed by exactly that many bytes of an opaque binary section.
The claimed length is within the decoded payload for **every one of
the 102 records**. The remaining bytes are not uniform across puzzles.

Examples:

| Puzzle | Binary section bytes | Remaining bytes after section |
|---|---:|---:|
| 1 — Сначала наведем порядок | 1755 | 481 |
| 2 — Эффект домино | 2664 | 225 |
| 3 — Уборщик | 2136 | 221 |
| 4 — Магнетизм | 1863 | 154 |
| 5 — Все вместе взятое 1 | 2647 | 121 |
| 6 — Паровой свисток | 2304 | 889 |
| 102 — Завершение | 3045 | 331 |

The first five records' remaining bytes follow the simple
instruction-text layout documented above. Puzzle 6 does **not**:
the corresponding four-byte word at `binary_length + 8` is zero
and **877 bytes** remain after the putative text position. This
demonstrates the need for a structured parser, not a guessed universal
text offset.

The read-only `tools/inventory_puzzle_binary.py` records offsets,
lengths and SHA-256 digests of each opaque binary section without
including any original copyrighted game data. Next: identify the
object-table format **inside** those length-delimited sections.

## All 102 original binary sections share an 85-byte prefix

Re-ran the actual decryption on the hash-verified Professor CML,
extracted the length-delimited binary section from each of the **102**
decoded challenge payloads, and compared their bytes position by
position. The **longest common prefix is exactly 85 bytes**.

- Bytes **0–79** are identical in every binary section.
- Bytes **80–84** are also identical in every section.
- The 16-byte window starting at offset **80** has **8 distinct
  values** across the 102 sections.
- The 16-byte window at offset **0** has only **1 distinct value**.

This is evidence of a common inner **binary header** preceding
puzzle-dependent information. **It is not evidence that bytes 85 onward
are object records**; they could contain a compressed or indexed stream.

Reproducible, non-extracting command:
`python tools/inventory_puzzle_binary.py PROFESSOR_LAB.cml --shared-structure`.

The analysis uses `tools/analyze_puzzle_binary.py`, which reports
counts and lengths without distributing original level bytes.

## Verified first differing binary-section bytes (102 original puzzles)

Direct comparison of all 102 decrypted original puzzle sections
confirmed the exact **85-byte** shared prefix. A 3-byte sliding
*non-overlapping* window experiment beginning at offset 85 yielded:

| Relative binary offset | Distinct 3-byte windows | Highest frequency |
|---|---:|---:|
| 85 | 3 | 44 |
| 88 | 8 | 17 |
| 91 | 8 | 17 |
| 94 | 7 | 28 |
| 97 | 6 | 28 |
| 100 | 5 | 28 |
| 103 | 5 | 28 |
| 106 | 5 | 28 |
| 109 | 5 | 28 |
| 112 | 5 | 28 |

The repeated 3-byte patterns may represent a compact encoding or a
repeated structure, but **no byte-to-object mapping is established**.
This experiment does not prove that 3 bytes are a logical field.

Reproduce with `python tools/inventory_puzzle_binary.py PROFESSOR_LAB.cml --window-analysis`.
No original asset bytes are included in the output.

## Eight recurring signatures in original inner puzzle headers

Inspected the original Professor CML directly, successfully decoded
all 102 records, and grouped the eight bytes at **binary offsets 85–92**.
Exactly **8 distinct signatures** occur, with the following verified
frequencies:

| Signature (hex) | Number of puzzles |
|---|---:|
| `405f06306f06e063` | 16 |
| `405f06306f07206b` | 11 |
| `411907206911c073` | 17 |
| `405f06d065074061` | 14 |
| `405f073063068069` | 14 |
| `405f070061070065` | 12 |
| `405f07706106c06c` | 15 |
| `405f07006f06f104` | 3 |
| **Total** | **102** |

Signatures are **not** contiguous level ranges. For example, the first
signature appears at levels 1, 7, 19, 27, 33, 38 and other positions;
the rare eighth signature appears at levels **31, 39, 45**.

These are byte-equality groups, not established item IDs or game
categories. Reproduce with
`python tools/inventory_puzzle_binary.py PROFESSOR_LAB.cml --prefix-groups`.

## BREAKTHROUGH: The inner binary section is 12-bit LZW, not opaque object data

**Verified directly on the user's original Professor Laboratory CML.**
The bytes after each inner 4-byte length are **big-endian packed,
fixed-width 12-bit LZW codes**, two codes per three bytes. Dictionary
codes **0–255** are literal bytes, new entries start at **256**, and
**4095** terminates the stream. The final padding code is zero.

For example, the original first three bytes `06 c0 65` unpack as
codes `108, 101`, ASCII **`le`**. The first eight decoded literal
codes spell `level\r\n{`. The complete decompressed text is a
human-readable **scene graph**, with object nodes and their coordinates,
rotations, IDs, values and goals.

Ran the decoder on **all 102 authentic records** without an LZW
dictionary error or missing terminator. Results:

- **707,577** decompressed scene bytes in total.
- **122** distinct `tmo_*` scene node names.
- **5,313** `tmo_*` node occurrences, including nested attachments.
- **2,263** explicit `POS x, y, z` lines (not counting `POSREL`).
- **86** occurrences of the literal `GOAL 1` across scenes.

Examples from the **actual original scene text** (not synthetic levels):

- Level 1 `Сначала наведем порядок`: `tmo_board` at
  `POS -1.41905, -1.08718, 0.03751`, rotation
  `ROT xyz 0, 0, -1.57080`; the object has nested
  `tmo_mount_bar` attachments.
- Level 2 `Эффект домино`: includes `tmo_domino`,
  `tmo_ball_basket`, `tmo_board`.
- Level 6 `Паровой свисток`: includes `tmo_boiler`,
  `tmo_pipe_corner`, `tmo_pipe`, `tmo_candle`.
- Level 31 `Поймай меня`: `tmo_rope_cage` with `GOAL 1`,
  plus `tmo_rope_hook`, `tmo_rope_scissors`, `tmo_ball_tennis`.

The 85-byte common prefix and eight signatures previously reported
are **compressed text artifacts**, not an object header or meaningful
level categories. This supersedes those earlier hypotheses.

New reproducible tools:
`tools/decompress_original_level.py` (LZW decoder),
`tools/inspect_original_scene_graphs.py` (scene object/position report).
No original game assets or proprietary scene texts are committed.
The next step is a **brace-aware scene graph parser**, followed by
mapping `3DO` model identifiers to the original UCM models and
recreating interactions.

## Direct original-data validation (2026-11-19)

Rechecked the user's **actual 330,971-byte** Professor Laboratory CML
and its original resource archive (160 UCM files), not synthetic fixtures.

**Critical decoder correction:** 44 of 102 authentic inner compressed
sections have lengths not divisible by three. The LZW terminator
(`4095`) can occur before the end of the last packed 12-bit pair.
The decoder must zero-pad the final partial three-byte packing unit,
stop at the terminator and ignore trailing padding bits. With this
correction, all 102 scenes decode.

**Important transform discovery:** the 102 decompressed scenes contain
**3,777 `POSREL` lines** and **64 `ROTREL` lines**, in addition to
2,263 `POS` lines and 793 `ROT` lines. The JSON exporter and
iOS document now retain these relative fields, and the assembled
scene viewer uses relative transforms where present. Exact precedence
of simultaneous absolute and relative fields still needs comparison
with the Windows loader.

**Verified 3DO-to-UCM name mapping:** the 102 scenes contain
**125 unique `3DO` identifiers** and 5,626 total `3DO` occurrences.
None of the identifiers directly match a UCM basename; **100 of 125**
match exactly after removing the literal `to_` prefix, e.g.
`3DO to_board` → `board.ucm`,
`3DO to_domino` → `domino.ucm`.
The remaining **25 identifiers do not match** the 160-file UCM archive
by that rule. The iOS resolver now applies only the verified prefix
rule and leaves unresolved assets missing rather than substituting
guessed meshes.

These counts are from a direct local run on the original files.
They are not a claim that a complete textured, playable scene has
been validated on an iPhone.
