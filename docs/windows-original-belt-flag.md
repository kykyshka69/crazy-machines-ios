# Native Crazy Machines belt flag: level-34 GOAL condition

**Original file:** owner-only `CrazyMachines.exe`, SHA-256
`51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6`.

**Genuine original scene:** `level-034.json` (from the owner's 445-entry,
all-SHA-verified CMASSET1 archive). Contains a `tmo_belt_flag` with
`GOAL 1`, four nested telescoping child elements and a separate
`tmo_belt_flag_wheel` with `VALF 0.125000`. This wheel VALF is NOT
the state or accumulated travel used by the Win32 GOAL condition.

## Exactly observed Win32 x86 predicates

- `0x44F9FB–0x44FA14`: compare the second telescope native physical
  `+0x90` with float `0x3EC28F5C` = 0.3799999952316284.
- `0x44FA16–0x44FA2C`: first branch requires original flag `+0xEC == 0`.
- `0x44FA2E–0x44FA58`: call `fabsf` on the accumulated native `+0x284`;
  send GOAL channel 0 only when `abs(accumulatedTravel) >= 2.0`.
- `0x44FA5F–0x44FA75`: alternate branch when the telescope indicator
  does **not** equal 0.3799999952316284 still requires flag `+0xEC == 0`.
- `0x44FA77–0x44FAA1`: alternate GOAL channel 0 requires
  `abs(accumulatedTravel) < 2.0`, a strict opposite boundary.

Original constant `2.0` at PE32 VA `0x4E74AC`. No reflection, power,
other object collision or generic wheel angle is sufficient to infer
native `+0x90` or accumulated travel.

## Scope in the iOS port

`CMOriginalWindowsBeltFlag.triggersGoal` models the **pure verified
native predicate** with finite-field rejection. The original GOAL resolver
accepts an optional `beltFlagRuntimeByObjectID` map, so a properly
recovered telescope physical-state sampler can supply validated values.
**No such native sampler is claimed yet:** the UI must never substitute
SceneKit angular speed as proof or award the level just from CML metadata.
Portable boundary tests cover equality and strict inequalities, zero
flag state and invalid/NaN observed fields. A full real level-34 end-to-end
test remains a blocker for Stage 1.

Reproduce the relevant original instructions on a private copy using
`objdump -d -Mintel --start-address=0x44f993 --stop-address=0x44faa6 CrazyMachines.exe`.
