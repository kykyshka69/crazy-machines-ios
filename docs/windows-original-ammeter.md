# Windows original ammeter: exact native needle formula

The user's SHA-verified original CrazyMachines.exe has a distinct `tmo_power_amperemeter` handler at `0x450F2E–0x45105A`. Original levels 40, 54 and 94 contain one such instrument each.

- Compare the instrument's incoming electrical `+0x40` against the separate physical subcomponent obtained by `0x420360` with selector `0xFE`, also read at `+0x40`. Choose the greater.
- Clamp that value from above to 10, with no absolute-value operation.
- GOAL callback at `0x450FDC–0x450FED` occurs only if the clamped max exceeds 1. Original ammeters on these levels do **not** have GOAL flags; do not fabricate them.
- Compute the needle's Z target at `0x450FF2–0x45100A` as `π/4 − (π/2)*(power/10)`.

The native scalar is in `CMOriginalWindowsAmmeter.swift`. iOS opt-in electrical playback is wired to the imported original UCM needle and observed main power. The native secondary `0xFE` source remains unresolved: its contribution is provisionally treated as 0 for display, not as proven Windows equivalent. Native time-interpolation and actual electrical return currents are likewise unfinished.
