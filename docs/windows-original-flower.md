# Original Win32 tmo_light_flower: illuminated growth state and GOAL

Source: user-owned exact `CrazyMachines.exe` SHA-256
`51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6`.
Five original Professor scenes have GOAL-marked `tmo_light_flower` instances.

## Native instructions confirmed

- At `0x44FF35–0x44FF52`: source light scalar is clamped to 1 from above.
- `0x44FF52–0x44FF7A`: exact `tmo_light_flower` type path multiplies
  observed light scalar by 10, later dividing by 10 at `0x44FF96`.
  Native goal is thus driven by **optical input**, not cable voltage.
- `0x44FF96–0x44FFA2`: native target is `1 - min(lightInput, 1)`.
- `0x44FFAE–0x44FFD9`: compute
  `increment = min((target - previousProgress) * 0.5, 0.5)`.
  Only the **positive** increment is capped; no manufactured clamp of
  a negative update occurs in this block.
- `0x44FFE3–0x45000C`: multiply by the native double step at `+0x128`
  and update flower physical progress `+0x130`.
- `0x450018–0x450039`: x87 compare `+0x130` with float 0.5;
  dispatch native GOAL 0 only when progress `<= 0.5` (equal counts).

The source's complete beam emission/cone/reflection, observation sampling,
and the original native `+0x128` clock relation to SceneKit remain
unrecovered. Code `CMOriginalWindowsFlower` **only** evaluates
independently observed native light/progress/clock scalars, rejecting
nonfinite values and never inferring them from an unobstructed UCM path.

`CMOriginalWindowsElectricalGoals` accepts an optional native flower
progress keyed to actual original object ID; GOAL annotations,
batteries and visible lines alone can never cause this condition.
The standalone portable boundary test passed; **no actual original level
was solved and no iPhone Simulator run was requested** in this patch.

Reproduce on the owner's EXE:
`objdump -d -Mintel --start-address=0x44ff35 --stop-address=0x450045 CrazyMachines.exe`.
