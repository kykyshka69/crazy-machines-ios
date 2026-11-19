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
