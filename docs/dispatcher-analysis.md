# Verified dispatcher analysis (2026-11-18)

Analyzed original `CrazyMachines.exe` SHA-256 `51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6` with `objdump -d -Mintel`.

## Confirmed control flow

Function `0x475840` dispatches a numeric mode to one of three object setup routines:

| Call site | Target | Mode |
|---|---|---|
| `0x47588C` | `0x4756F0` | 1 |
| `0x47587F` | `0x475740` | 2 |
| `0x475872` | `0x4757F0` | 3 |

The candidate `0x4756F0`:
- writes `1` to `[esi+0x28]`;
- calls `0x476E80` at `0x475705`;
- calls `0x46B560` at `0x47570E`;
- calls `0x476DD0` at `0x47572C`;
- returns an HRESULT-like error on negative result.

**Correction:** `0x4756F0` is an object setup wrapper for mode 1, not demonstrably a UCM parser. The binary decoder, if present on this call path, must be established deeper in the call graph. No verified complete UCM decoder or iOS game yet.

## Reproduction

```sh
objdump -d -Mintel --start-address=0x4756f0 --stop-address=0x475895 CrazyMachines.exe
python tools/verify_dispatcher.py CrazyMachines.exe
```

Keep all copyrighted original game assets outside the repository.
