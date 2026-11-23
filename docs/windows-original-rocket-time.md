# Native Win32 rocket fuse and explosion GOAL

Original user's CrazyMachines.exe SHA-256: 51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6.

At 0x44F03B–0x44F04E the original Windows engine requires rocket element physical state +0xEC to be precisely float 2.0, before selecting type tmo_heat_rocket at 0x44F1A2. A native engine clock read from +0x124 minus the rocket's recorded launch timestamp +0x130 is compared against original double 3.0 at 0x44F288–0x44F2A7. The x87 test ah,0x41; jne accepts elapsed time strictly GREATER THAN 3.0, rejecting equality. After running physical Engine/Explode operations it writes +0xEC=3.0 (0x44F33C) and emits the original GOAL 0 callback at 0x44F354.

CMOriginalWindowsRocketTimer implements these recovered type-specific transition conditions and rejects missing original flying/engine input, backwards time and nonfinite data. All 16 GOAL-marked rockets in the user's 102 scenes (11 in level 102) need real ignition, engine physics, force, and post-explosion state transitions to be wired before they can count as solved; this helper alone does NOT trigger them. Real Windows optical/thermal flame collisions and the complete 102-level wins are still unfinished.

Reproduce with python3 tools/audit_windows_rocket_exe.py /private/CrazyMachines.exe. It verifies 13 x86 instruction sites, original selector and native state/timer constants; no proprietary bytes are committed.

## Recovered PRE-LAUNCH native phase omitted in the earlier iOS helper (2026-11-23)

Re-disassembled the **exact owner-owned** PE32 with verified SHA-256
`51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6`.

Two distinct timed stages are confirmed, each strictly **GREATER** than
3 seconds, not one 3-second countdown:
1. `0x44EC48–0x44EC83`: original PARENT `+0xEC == 1`, check
   `engineClock - parentOriginalIgnitionTime(+0x130) > 3`.
   `0x44EE2B` selects `tmo_heat_rocket`. If launch actions really
   succeed, the original `Engine` child is activated; `0x44EF59–0x44EF73`
   records the **new** Engine child launch timestamp, and only then
   `0x44F029` writes parent state **2** (flying).
2. `0x44F03B–0x44F04E`: PARENT `+0xEC == 2`, then
   `0x44F1BE–0x44F2A7` checks the live original Engine child clock
   against the separate Engine launch timestamp `+0x130` strictly
   **> 3 seconds**. Actual Engine/Explode effects precede writing parent
   **3** at `0x44F33C` and dispatching GOAL 0 at `0x44F354`.

The first state **1** must itself arise from actual original thermal
ignition (still not recovered). `CMOriginalWindowsRocketTimer` now
evaluates both stage boundaries and requires proof of real Engine
activation for state 1→2 and proof of actual Engine/Explode effect for
state 2→3. The level's GOAL resolver now accepts a native physical
explosion observation under the authentic rocket object ID and NEVER
credits a rocket from a clock, proximity, heat-source tap or GOAL
annotation alone.

**Known missing in SceneKit:** rocket thermal-hit producer, native state
1 establishment, original Engine/Explode force and moving meshes.
Thus the 16 genuine GOAL rockets (including 11 in original level 102)
are NOT claimed completed. Combined source compilers and focused smoke
tests have been updated; no full iOS rebuild requested for this
intermediate commit.

## Native physical ignition from a lit ORIGINAL candle — verified Win32 branch

Additional original EXE x86 evidence from the exact SHA-256-matched PE32:

- `0x44E112` explicitly dispatches source type **`tmo_candle`**.
  `0x44E149–0x44E16E` requires that source's original +0xEC
  emitted/active state.
- `0x44E317–0x44E36C` includes original
  `tmo_heat_rocket` (along with separately handled cannon,
  dynamite and candle targets). The rocket's original +0xEC must be
  precisely **0** before first ignition.
- `0x44E39D–0x44E3C2` retrieves the receiver's authentic selector-3
  heat region and runs the SAME original physical intersection engine
  `0x409650` already recovered for wind coverage.
- `0x44E3C6–0x44E3D7` compares the measured fraction to the original
  float at `0x4EDDE8` — bits `0x3F570A3D`, or
  **0.8399999737739563** — with strict **GREATER THAN**. Equality
  does not ignite.
- `0x44E3E6` calls original helper `0x44CD30`.
  `0x44CD39–0x44CD4F` again verifies previous native +0xEC==0;
  `0x44CD51–0x44CD75` actually activates the original effect child,
  `0x44CD79` then writes state **1**, and
  `0x44CD83–0x44CD91` records the TRUE original clock in parent
  +0x130. This time starts the first separate >3-sec interval.

The iOS source now models this **genuine candle/rocket type and
physical-hit threshold**, not an assumed universal heat transfer.
`acceptsObservedCandleIgnition` requires source actually lit and
observed physical hit fraction; `ignitionAfterObservedCandleEffect`
requires proof that the original child effect actually activated before
it supplies state-1/time evidence.

**Still missing:** translating the actual selector-3 original heat
region, native source emissive state and effect-child activation to live
SceneKit measurements. Ordinary UCM mesh collisions, a user click
alone, and a guessed heat radius still must NOT ignite the rocket or
fabricate the 16 authentic rocket GOAL events.

## Native region-to-rocket ignition integration (2026-11-23)

Original candle x86 0x44E39D–0x44E3C2 retrieves selector-3 heat-region
geometry and calls the same original 0x409650 region-overlap function as
wind. The iOS rocket now composes the recovered region calculation with
the exact strict >0.84 ignition gate, lit source and observed original
effect/clock. Tests reject out-of-cone, missing/invalid, wrong source,
unlit candle and absent effect. Region test values are synthetic.

**Still missing:** live original SceneKit selector-3 parameters, actual
heat emitter/effect observations, flight thrust/explosion and successful
runs across all 102 authentic scenes. These tests are not level wins.

## Corrected shared Win32 heat/wind intersection plane and region selection (2026-11-23)

Verified the **user-owned, exact SHA-256 matched** `CrazyMachines.exe` with
`objdump` and eight newly pinned native instruction addresses
(`tools/audit_windows_rocket_exe.py:REGION_SITES`):

- `0x40966D`: `mov dword ptr [ebp-0x8], 0` after copying the
  source displacement XYZ; native distance/angle code deliberately
  ignores source Z.
- `0x409688`: `mov dword ptr [ebp-0x2c], 0` after copying
  the region axis; region-axis Z is likewise ignored.
- `0x4096B9` and `0x4096C5`: displacement/vector length;
  `0x409D00` computes squared distance of the projected vector.
- `0x44E3A4` requests native region **type 3**, first match
  (index zero); `0x4204A0` follows genuine per-object region
  entries of stride `0x54`, requiring an associated pointer at
  entry `+0x44` and matching selector byte at `+0x10`.
  The selected entry's actual region fields begin at `+0x24`
  (`0x44E3B3`). **Not** a generic mesh collider or distance radius.

The earlier Swift `CMOriginalWindowsWindRegion.measuredFraction`
incorrectly retained Z in its norm and angular calculation. It now
projects into authentic XY **before** checking radius/angle for both
heat and wind. Its portable regression includes depth-invariance and
depth-only rejection; rocket ignition now inherits that corrected
native geometry path.

Remaining blocker: obtain these exact per-object region records (not
UCM bounding spheres) from the owner-original scene data, transform
them into the current SceneKit object reference frame, and observe
the original effect child, Engine physical impulse and explosion.
No original level success is claimed by this geometry correction.

## Recovered original Direction vector operations at engine activation

The owner SHA-256-matched `CrazyMachines.exe` at `0x44EE57`
fetches the literal original `Direction` marker on the rocket child.
At `0x44EE7E` the code accesses `Direction+0x30`,
`0x44EE89` copies a three-component vector through `0x45A07B`,
and `0x44EE8E` pushes exactly IEEE float `0x40400000`
(**3.0**) before `0x44EEA1` calls `0x420CE0`.
The independently disassembled helper at `0x420CE0–0x420D12`
multiplies each of its three input vector components by that scalar,
without clamping or normalization. The same original gameplay
sequence activates the literal `Engine` child and establishes the
independent Engine launch clock.

The privately recovered decrypted original `elements.fsc` separately
defines `tmo_heat_rocket_rocket` with `VELOCITY 4.0` and
`VALF 0.125`. These are **not** interchangeable with the 3.0 vector
scale. Their precise mapping to physical-body velocity/force,
Direction anchor coordinate frame, and Engine effect still requires
tracing the native call chain. Do NOT directly treat the 3.0 scalar
as a SceneKit impulse or claim rocket flight from these constants.

## Original rocket's actual physics-body force application (2026-11-23)

Independently decoded and SHA-pinned **12 additional machine-code sites**
from the exact owner-original EXE (SHA-256 `51f9bee...d601e6`):
- `0x44F1DD..0x44F1F6`: obtains the runtime `Direction` marker
  vector at `+0x30`, not necessarily the raw UCM local-axis vector.
- `0x44F219`: reads the flying rocket child object's LIVE `+0xFC`
  scalar. This value cannot be substituted with template `VALF 0.125`
  or `VELOCITY 4.0` without additional source verification.
- `0x44F22D`: native `0x404460` multiplies the vector components by
  that measured scalar; no invented normalization or force constant.
- `0x44F264`: native `0x4261C0` reads the actual physics body center.
  `0x44F27D`: `0x426470` calls native physics `0x486400` to
  accumulate a force at that point. The bridge copies native X and Y
  and sends Z=0; `0x486400` accumulates actual force and torque.

Added `CMOriginalWindowsRocketForce.observedThrust` with a portable,
positive/negative state-based regression requiring original flying state
2, activated Engine child, observed runtime scalar and real Direction
vector AND body center. It returns a planar force-at-body-center
command, NOT a level GOAL or time-triggered fake rocket impulse.
SceneKit's live native +0xFC producer and physical force dispatcher are
still unimplemented. They must be connected before flight is real.

## SceneKit physical Engine force dispatch wired (2026-11-23)

The original Win32 rocket launch loop at `0x44F1DD..0x44F27D`
applies a **continuous planar force at the genuine physics body center**.
Added `CMOriginalRocketForceDelivery` to require all of the original:
- exact `tmo_heat_rocket` parent and its own `tmo_heat_rocket_rocket`
  child, plus a dynamic SceneKit physical body;
- real parent +0xEC state 2 (flying), independently activated Engine
  child, genuine observed runtime `+0xFC` scalar, and native
  `Direction+0x30` vector plus observed body center.

The SceneKit physics coordinator now has a live input stream for
these **observed** Engine samples, consumes each sample **at most
once** per simulation frame, and calls actual
`SCNPhysicsBody.applyForce(_,asImpulse:false)` on the matching
original rocket child. It does not inject a 3.0 or 4.0 fake impulse,
invent thermal ignition or emit a puzzle GOAL. Stale inputs cannot
continue producing constant force because the queue is emptied.

**Unfinished producer:** the actual original renderer does not yet
observe +0xFC or an activated Engine child, so its new input is empty
by default. This patch establishes the real physical force delivery
path, not an authentic successfully flying rocket. Owner-real runtime
telemetry + genuine source heat regions remain necessary.
