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

## First native selector-3 region identity for candle and rocket (2026-11-23)

Disassembled the user's verified original CrazyMachines.exe:
- `0x44E12E` candle and `0x44E3A4` receiver both call `0x420360`
  with **selector 3, occurrence 0**. They select separate object regions.
- `0x4204FC` advances native `0x54`-byte region records.
  `0x420508` rejects records with a null linked-object pointer
  at `+0x44`, `0x420522` reads the linked object's `+0x10`
  selector, and `0x420530/0x42054B` compare/increment the ordinal
  **only for matching** selector records.
- New `CMOriginalWindowsRegionSelector.matchingEntryIndex` reproduces
  that lookup for observed original region metadata. Rocket ignition
  now has a high-level path requiring source AND target selector-3
  first-record indices to match actual measured original geometry.
  Failed/mismatched/unlinked records cannot ignite via this path.

No real SceneKit region records or actual original effect/engine
observations are synthesized here. The producer and actual 102-level
gameplay verification remain unfinished.
