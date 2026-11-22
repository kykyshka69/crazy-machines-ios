# Original Win32 electrical disrupter gate — verified November 22, 2026

**Source:** privately supplied genuine `CrazyMachines.exe`, SHA-256 `51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6`. The EXE is not included in the public repository. Verify the executable on an owner's machine with `python3 tools/audit_windows_disrupter.py /path/to/CrazyMachines.exe`.

## x86 evidence

- `0x44C8A0`: existing recursive electrical endpoint dispatcher. A per-cable byte at `+0x178` prevents processing the same connection again (compared against 2). If the source `+0x50` field is nonzero, it clears its `+0x40` state; its source **runtime meaning remains unknown**. The dispatcher copies the source `+0x40` state to target `+0x40` and visits further original cable connections.
- `0x44CA30`: exact `tmo_power_disrupter` name comparison inside the power dispatcher (separate from the `tmo_power_switch` branch at `0x44C98B`).
- `0x44CA59`: pushes IEEE-754 `π=0x40490FDB`; `0x44CA61` loads the disrupter wheel's float at offset `+0xD0`; `0x44CA68` calls the float remainder wrapper `0x403160`, which reaches the original CRT's x87 `fprem` implementation via `0x403180` and `0x4D48A4`.
- `0x44CA70`: stores the signed remainder. `0x44CA73..0x44CAC8` compares it with exact float `0`, `−π/2`, `−π`, and `+π/2` (two branches). When blocked, the destination's electrical `+0x40` is **cleared to zero**, rather than being allowed to reach the next device.

Using x87 condition codes and the branch destinations, for a finite rotor angle `θ` and `p=fmodf(θ,π)`, the Win32 **conducting intervals** are `−π < p < −π/2` or `0 ≤ p < π/2`. Note that the negative endpoint `−π/2` is **blocked**, and the positive endpoint `+π/2` is **blocked**; the source angle's sign matters. An absent or nonfinite rotor measurement must not silently pass power in the iOS implementation.

The read-only auditor checks **18 opcode locations, 6 original float constants and both original element type strings**, rejecting any other EXE hash. `ios/CMOriginalWindowsPowerDisrupter.swift` implements only this verified x86 gate, with Swift portable boundary tests.

## Integration and remaining limits

- The imported CML hierarchy supplies the exact owner pair `tmo_power_disrupter` → `tmo_power_disrupter_wheel`. No nearest-wheel guess is accepted.
- In the opt-in experimental iOS circuit, a disrupter is now an electrically conditional **transmission node**: without a measured wheel angle it fails closed; an allowed angle passes incoming scalar power, otherwise downstream loads are isolated.
- The SceneKit rotor's presentation Z Euler angle supplies the provisional iOS observation. The original Win32 uses its `+0xD0` wheel scalar. **The coordinate/rotation-scale equivalence and coupling of the full mechanical disrupter are not yet validated on authentic iPhone assets**. Thus this is a functionally useful integration, not complete Windows electrical/physics parity.
- Original source mixing, wire persistence, the `+0x50` runtime field's producer, switch internal geometry, solar light rays, motors' real torque, and full 102-level completion still require reconstruction.