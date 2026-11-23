# Original Crazy Machines flag: real WIND-driven GOAL, level 34

**Verified PC executable:** the owner's `CrazyMachines.exe` SHA-256
`51f9beecd9842c67834da9c4fc73be7a1452c9e8149d059729b130a2b9d601e6`.
**Verified private level:** `level-034.json`, title `Важный визит`,
from the original 445-entry owner-owned `CMASSET1` archive. Includes
one GOAL-marked `tmo_belt_flag` and its four telescopic children,
plus a separate `tmo_belt_flag_wheel` with authored VALF 0.125.

## Critical correction to earlier interpretation

Earlier notes incorrectly described `[ebp-0x284]` as an object's
`+0x284` accumulated **travel**. This is false. x86 uses **EBP-relative
stack addressing**: `0x44F813` writes ZERO to a per-invocation
temporary at `[ebp-0x284]`, then wind-source contributions are added to it
at `0x44F926`. The GOAL at `0x44FA58`/`0x44FAA1` checks the
**absolute summed instantaneous wind pressure**, not distance travelled,
gear rotation or a persistent variable.

The inspected PE32 `.rdata` confirms `0x4F3C3C` is exactly **0.5**,
the wind-source contribution multiplier. The type literal addresses
`0x4ECB7C` and `0x4ECB8C` identify **`tmo_windmill`** and
**`tmo_wind_bellows`**. The original code:

- `0x44F7CF–0x44F813`: find the flag's native region, initialize
  the float sum to zero for this native call.
- `0x44F858–0x44F892`: allow the two authentic wind-emitter kinds;
  no other scene object is considered a wind source.
- `0x44F894–0x44F8E6`: retrieve emitter selector-4 region and evaluate
  true intersection via `0x409650`.
- `0x44F8EA–0x44F90B`: choose the contribution's direction sign from
  compared original source/target depths.
- `0x44F911–0x44F92C`: add
  `signedIntersection * observedSource.+0x40 * 0.5`
  to the **local** instantaneous wind sum.
- `0x44F9FB–0x44FA14`: second telescope `+0x90` is compared with
  the exact float `0x3EC28F5C` = 0.3799999952316284.
- `0x44FA16–0x44FA58`: if `flag.+0xEC == 0` and telescope equals
  marker, the channel-0 GOAL requires `abs(netWind) >= 2.0`.
- `0x44FA5F–0x44FAA1`: if `flag.+0xEC == 0` and telescope differs
  from marker, the channel-0 GOAL requires `abs(netWind) < 2.0`.

## Actual iOS implementation and remaining gap

`CMOriginalWindowsBeltFlag.nativeWindSum` accepts separately observed
wind source identity/type, signed intersection and native `+0x40`
power. The aggregator rejects unknown source kinds, duplicate source
IDs and invalid readings. A complete observation with no wind
correctly yields zero; an **incomplete observation yields nil**, so
absence of sensor information cannot make the low-wind branch succeed.

`CMOriginalWindowsBeltFlag.ObservedState` now uses
`observedNetWindForce` instead of the incorrectly named
`accumulatedTravel`. The preexisting Win32 GOAL dispatcher still
requires **both** native telescope and actual wind observations; no
fake automatic GOAL from SceneKit angular velocity, a CML GOAL flag or
a merely visible UCM wheel. The native beam/airfield intersection
parameter mapping and live emitter `+0x40` observation remain
to be recovered before level 34 can be tested as fully playable.

Reproduce directly on the owner-owned EXE:

```bash
sha256sum CrazyMachines.exe
objdump -d -Mintel --start-address=0x44f7cf --stop-address=0x44faa6 CrazyMachines.exe
objdump -s -j .rdata --start-address=0x4ecb60 --stop-address=0x4ecba0 CrazyMachines.exe
```

No licensed original executable, JSON, mesh or texture is committed.

## Native wind-region attenuation and exact level-34 wind-source inventory (2026-11-23)

The owner-verified original PE32 routine at **0x409650–0x40985B**
calculates the intersection fraction supplied to flag wind aggregation:
- Compute displacement and its squared norm (native 0x408BE0 / 0x409D00).
- Reject squared distances outside native region **+0x34..+0x38**.
- Compute `acos(clamp(dot(displacement, region axis+0x18) /
  (|displacement|*|axis|), -1, 1))`; reject angles larger than +0x40.
- Calculate `(1 - (angle * region+0x44)^2) *
  (1 - (distanceSquared - region+0x34)*region+0x3C)`;
  clamp measured intersection fraction to **[0,1]**.
- Original flag at 0x44F8EA–0x44F911 signs the measured
  intersection by original source/target depth before multiplying
  source +0x40 power and the original 0.5 scalar.

`CMOriginalWindowsWindRegion` implements this **pure** Win32
distance/angle/attenuation function from real supplied native region
parameters. `CMOriginalWindowsBeltFlag.observedSource` combines it with
verified original emitter kind, actually measured power and depth ordering;
no UCM proximity guess, fake SceneKit source power, or fabricated
native region field is inserted.

Important **source completeness**: authentic `level-034.json` has exactly
one `tmo_windmill` and no `tmo_wind_bellows`. The flag's low-wind GOAL
branch must not activate merely because a sampler omitted that windmill.
`nativeWindSum` now requires the full set of expected **original source
IDs**; missing, extra or duplicate observations fail closed. The
scene's real native region parameters / emitter +0x40 values still
require a live original-to-SceneKit measurement pipeline. Therefore
**no claim of solving level 34 or all 102 authentic puzzles**.
