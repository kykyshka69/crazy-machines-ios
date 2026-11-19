# Recovered original CML byte-transform primitives

Disassembled the user-provided `CrazyMachines.exe` (PE32 i386) directly
using GNU objdump. This supersedes the earlier generic "unknown transform"
description. The following **byte-level primitives are confirmed by the
instructions**; their exact composition for CML must still be validated.

## 0x47E480 — reverse a buffer

The routine copies bytes from the end of the source toward the beginning
(`mov al,[edx]`, `mov [ecx+ebp],al`, `dec edx` at 0x47E4A0–0x47E4A9).
It then copies the reversed temporary buffer back to the destination.

## 0x47E4D0 — position-dependent byte addition/subtraction

At 0x47E4E3–0x47E548, the routine iterates over bytes. It computes
`(signed_initial_byte + length + index) mod 256` and either **adds**
that value to each byte (`add bl,dl` at 0x47E51F) or **subtracts**
it (`sub dl,bl` at 0x47E535), according to a boolean argument.
All byte arithmetic wraps modulo 256.

## 0x47E570 — adjacent-byte delta transform

At 0x47E5B0–0x47E5D0, a flag selects between:
- forward prefix sum: `out[i] = (original[i] + original[i-1]) & 255`
  (in-place, reading the **original** buffer)
- backward delta: `out[i] = (original[i] - out[i-1]) & 255`
  (reading the previously transformed destination byte)

The first byte is unchanged in both modes.

## 0x47E610 — composite transform

This routine dispatches the three primitives above using successive
two-byte entries of a supplied control string. The second byte of each
pair is interpreted as a signed 8-bit integer and divided by 3; its
signed remainder selects operation 0, 1, or 2. The first byte is passed
as an operation parameter. The composite routine also performs buffer
prefix/suffix copying and a final call to 0x47E570 with constant
`0x6f`. The other branch includes an explicit byte comparison and
error return.

**Important:** The exact argument order, control-string length,
operation direction, and buffer boundaries in 0x47E610 are not yet
proven end-to-end. Therefore these recovered primitives are not
presented as a validated original CML decoder. The next check is
reproducing the original call against both user-owned CML files.

## Source addresses

- `0x47E480–0x47E4C9` reverse
- `0x47E4D0–0x47E569` offset arithmetic
- `0x47E570–0x47E5DF` adjacent delta
- `0x47E610–0x47E85F` composite dispatch

## Correction from instruction-level source tracing

The initial description of 0x47E570 mistakenly reversed the
source/destination dependency. Re-reading 0x47E5B7 and 0x47E5C6
shows the **forward** path reads the previously modified destination,
while the **reverse** path subtracts the previous original byte from
a preserved temporary copy. Thus the verified pair is:

- forward: `out[0]=in[0]; out[i]=(in[i]+out[i-1]) & 255`
- reverse: `out[0]=in[0]; out[i]=(in[i]-in[i-1]) & 255`

Both directions now have regression round-trip tests. This correction
is necessary before reconstructing the composite decoder.
