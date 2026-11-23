# Original Crazy Machines Win32 gear and conveyor signal transmission

## Source / reproducibility

Source is the **user-owned original Windows CrazyMachines.exe**, SHA-256
`51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6`.
All addresses are **x86 32-bit virtual addresses for this precise executable**.
This note documents observed instructions, *not* completed Windows-mechanics
equivalence on iPhone. No original binary or proprietary meshes are committed.

With the owner's verified EXE, inspect using:

```sh
sha256sum /private/path/CrazyMachines.exe
objdump -d -Mintel --start-address=0x44b8d0 --stop-address=0x44ba20 /private/path/CrazyMachines.exe
objdump -d -Mintel --start-address=0x44c0f4 --stop-address=0x44c260 /private/path/CrazyMachines.exe
objdump -d -Mintel --start-address=0x458e20 --stop-address=0x458e39 /private/path/CrazyMachines.exe
```

## Verified dynamic mechanical transmission

| Win32 VA | What the original instructions do |
| --- | --- |
| `0x44C0F4` | Dispatch specifically for type `tmo_belt_gear` (string at `0x4EC548`) |
| `0x44C10F` | Mark this gear visited by writing state `2` to its `+0x178` byte |
| `0x44C125–0x44C13B` | Load gear scalar `+0xE8`; multiply by original float constant **0.1** (`0x4E9BD8`); pass it to `0x458E20` for the physical object at `+0x7C` |
| `0x458E27–0x458E33` | `0x458E20` stores supplied float at the physical object's `+0x84`; this is a field assignment, **not proof of a SceneKit angular-speed unit** |
| `0x44C140–0x44C14E` | Dispatch the gear into original link walker `0x44B8D0` |
| `0x44B8E3–0x44B917` | Enumerate links with original selector **5** and inspect their attached native pointer `+0x3C`; skip missing/incoming links |
| `0x44B955–0x44B963` | Copy the **negative** of the current gear `+0xE8` into the attached linked object's `+0xE8` |
| `0x44B975–0x44B988` | Scale that linked signal by original float **0.1** and assign its physical `+0x84` through `0x458E20` |
| `0x44B98D–0x44B9A7` | Avoid repeated links where target visited flag `+0x178 == 2`; otherwise recursively process `0x44B8D0` |
| `0x44C158` | Type branch for genuine `tmo_belt_conveyer` (`0x4EC558`) |
| `0x44C194–0x44C1A6` | Copy first authentic conveyor child signal `+0xE8` into its second child `+0xE8` |
| `0x44C1B2–0x44C1DC` | Compare **abs(second-child signal) > 0.5** (original double at `0x4EFDA8`), strictly; only then call the real `0x44B460` GOAL-channel dispatcher |
| `0x44C1F3–0x44C209` | Divide second-child `+0xE8` by original float **10.0** (`0x4E7A8C`), write corresponding physical `+0x84` via `0x458E20` |
| `0x44C21D–0x44C230` | Pass first-child `+0xE8` to the first child's physical `+0x84` setter |

## Exact implications — and known gaps

- This original mechanical channel **is separate** from cable
  `tmo_power_plug` pairs and from CML `CONNECTED_TO` metadata. The
  selector-5 dynamic links and attached pointer `+0x3C` are **runtime**
  evidence, and must not be fabricated from nearby pieces.
- The original linked gear **reverses** its `+0xE8` sign and forwards its
  scaled physical-command scalar. A naïve direct same-direction drive is
  inconsistent with these instructions.
- A conveyor's GOAL threshold is a real original rule, but an iOS UI
  must **not credit it** until the required original `+0xE8` source and
  child/physical-object mapping have been recovered and exercised.
- The original `+0x84` field is assigned by the original engine; how
  this value drives real motion, torque, collisions, and the SceneKit
  angular velocity field is **still unresolved**.
- Stage 1 remains incomplete: decode selector-5 contact/link creation,
  reconstruct actual physical source signals and motion transfer, then
  validate start/stop and all real PC puzzles under the Apple runtime.

See also `docs/windows-original-motor-state.md` and
`docs/windows-original-power-propagation.md`.

## Implemented SceneKit UCM gear-contact correction (2026-11-23)

The iOS *experimental* engine now observes actual SCNPhysicsContact between
original UCM rotating bodies, never inferred nearby or metadata links.
The contact point and imported physics owners yield the physical lever arms.
A bounded force correction opposes surface slip, so actual teeth contact
between `tmo_belt_gear` and a real motor rotor, another gear, a conveyor
wheel, or a generator rotor can transfer rotation with the opposite sign.
Two idle axles never self-start. It is also called on the first contact,
not only on long-standing contacts. Existing original conveyor UCM traction
then moves touching crates when its own wheel actually rotates.

This **is a physics integration, not a reconstruction of original Win32
selector-5 links or exact torque/radius scaling**. The damping gain/caps
remain labeled SceneKit-only prototypes; they must be calibrated against
the user's actual PC simulation. No GOAL or CONNECTED_TO event is fabricated.

## Authenticated 102-scene impact inventory (private archive, 2026-11-23)

The privately owned 445-entry CMASSET1 archive was read locally and all
445 SHA-256 resource payload checks succeeded. Counts in authentic 102
scene JSON trees: 29 levels with `tmo_belt_gear`, 38 with
`tmo_power_motor`, 34 with `tmo_belt_conveyer`, 21 with both gear and
motor, 23 with gear and conveyor and **17 with all three**:
41, 51, 54, 64, 66, 69, 70, 72, 77, 78, 80, 85, 92, 93, 94, 95, 99.
The 17 are **priority private integrated gameplay verification targets**
for the new contact bridge, but this metadata analysis does not prove
physical gear engagement or solve any of the puzzles on iOS.

## Original VALF transfer ratio integrated into contacted gears (2026-11-23)

**Original executable SHA-256 validated** as
`51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6`.

Further genuine Win32 x86 recovery:
- At `0x4226DE..0x422730` the original CML `VALF` decoder
  actually parses the Float and stores it into object `+0xEC`.
- At `0x44BAB2..0x44BAD0` an attached mechanical receiver gets
  `receiver.+0xE8 = source.+0xE8 * source.+0xEC / receiver.+0xEC`.
- At `0x44BAD8..0x44BB0B`, when runtime attachment flag `+0x50`
  is nonzero, the receiver instead evolves toward zero as
  `receiver.+0xE8 += (-receiver.+0xE8) * *(receiver.+0x128)`.
  These runtime flags/steps are NOT present in CML and are not invented.

Authentic original gear and motor rotors have `VALF 0.125000`;
original conveyor wheels have `VALF 0.100000`. The pure portable
`CMOriginalWindowsMechanicalTransfer` exactly computes the scalar
ratio and guarded decay. `CMOriginalAssembledSceneView` now reads
**actual per-object CML VALF** and supplies the native ratio to the
bounded SceneKit contact correction for physically touching original
UCM gear teeth, motor rotors and conveyor wheels. A gear (.125) to
conveyor wheel (.100) therefore uses 1.25x opposing *target-signal*
ratio instead of relying only on the imported mesh radius guess.
The native `+0x84` angular speed/torque mapping remains unknown:
SceneKit friction and force gain are still **experimental**, and this
change does not manufacture a selector-5 link or a GOAL event.

### Focused Stage-1 mechanics checkpoint (2026-11-23)

Native `tmo_power_generator_rotor` electricity must not wait for a
SceneKit UI polling threshold: a newly measured nonzero rotor command, or a
reversal of its sign, now propagates immediately even below the renderer's
0.05 ordinary update debounce. The existing 0.01 rest tolerance remains
an explicitly experimental numerical threshold, not a recovered Windows
current/torque constant.

The original per-gear/conveyor UCM `VALF` values were present in all
220 relevant authentic mechanism instances previously audited. When a
partially damaged scene provides just one of the two native coefficients,
a real mechanical contact will now refuse the guessed geometry fallback,
rather than pretending the native gear ratio is known.

For local validation between edits, run
`bash scripts/check-stage1-mechanics-fast.sh`. No full iOS build is
triggered by that script; batch source edits and run Xcode/CI only once
at a later integration checkpoint.
