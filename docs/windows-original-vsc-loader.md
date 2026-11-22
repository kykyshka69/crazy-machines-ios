# Original CrazyMachines.exe — recovered FAKT Value Script (.vsc) loader

Date: 2026-11-22. Source: user-owned PE32 CrazyMachines.exe (SHA-256 `51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6`) and original scripts under `scripts/`. **This document contains no proprietary script bytes.**

## Verified Win32 call chain

- `0x423437` pushes the address of an eight-character text constant in the original `.rdata`, VA **`0x4E97E8`**.
- At `0x423445`, the Windows game calls `0x41C730`, which at `0x41C755` calls `0x47B400` with that key pointer.
- `0x47B400` validates the key is short and even-length (the function rejects odd lengths and lengths >= 17) and copies it to the process-global buffer at **`0x513744`**.
- The original VSC read paths at `0x47B678` and `0x47B9BB` pass the same global key and their encrypted file bytes to the established `0x47E610` reversible byte transform.
- Key bytes at `0x4E97E8` decode to ASCII **`tz023416`**. They are **not** the 20-byte laboratory / encrypted FSC key (`930%&g/2ANUBIS=!s?p$`).

## Real-file verification

Read all **17** original encrypted `.vsc` files extracted from the user's PC game with the verified transform: **17/17 passed key-prefix verification** and decoded to FAKT Value Script text, without guessing a password or substituting synthetic data. The portable Swift decoder `CMOriginalVSCDecoder` was exercised against all original files off-repository.

The content is a Windows-1251 configuration language with `[SECTION]` and `key = value`. It contains **326 section occurrences** and **1,218 property occurrences** across the original 17 scripts. The original `gfx/gfx.vsc` repeats two section labels; a correct parser **must retain duplicates and original order** rather than deduplicating them. `gui/leveldone.vsc` declares `task_done` and the three button entries with IDs `1/2/3`: Continue, Replay, Main_menu. `sound/soundfx.vsc` maps 31 named effects to original game sound resources. All 17 scripts, including Cyrillic values, were read with the CP1251 codec.

## iOS integration and explicit limits

- `CMOriginalVSCDecoder` decrypts the user-imported original script bytes, verifies the real FAKT header, parses Windows-1251 key-value sections, and preserves duplicate sections.
- Both individual-file and `.cmassets` pack imports validate `.vsc` scripts before writing to the user's private iPhone sandbox; the public GitHub repository contains only decoder source and synthetic test fixtures.
- `CMOriginalVSCScriptLibrary` reads the *imported* level-completion dialog metadata so its original button names/IDs can drive Replay, Continue and Main menu on iOS. This **does not** prove that the prototype scene's win condition matches the Windows win decision.
- The GUI, resource and sound Value Scripts are **configuration**, not original Windows physics engine source or bytecode of all mechanism effects. Real current and voltage propagation, generator activation, physical constraints, audio playback and authoritative win rules still need independent implementation and validation on genuine puzzles.
- The reversible byte scheme uses a key prefix check, not cryptographic authentication: arbitrary bit damage is not guaranteed to be detected if it preserves the prefix/header.

The original `.vsc`, `.ucm`, `.tga`, `.wav`, `.ogg`, `.cml` and `.fsc` resources must remain user-owned and out of public GitHub. CI tests use newly generated, non-copyrighted encrypted FAKT data.