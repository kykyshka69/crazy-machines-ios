# Original PC UCM1 named attachment frames

The original privately owned UCM1 models have a 92-byte header followed
by triangle indices, vertex arrays, 16-byte named attachment records,
and 64-byte Float32 4x4 matrices for every (group,slot) pair.
These were verified against the owner's actual game, including the
Candle model with a `Heat` frame and the Rocket model with `Rope`,
`Engine`, `Explode`, `Direction`, `Cut`, `Heat` and `Mechanic01`.
The rocket Engine marker's local translation Y candidate is about
0.05635856; Explode is 0.36828864.

`CMOriginalUCMNamedAnchors` safely decodes native names and raw matrices.
`CMOriginalAssembledSceneView` preserves group-zero local translation
candidates as invisible SceneKit child frames, belonging to the actual
original object and transformed with its mesh. No guessed physical
region, torque, explosion, GOAL signal or proprietary data is committed.

Original Win32 0x409650 thermal-region *shape* and effect/Engine thrust
remain to be recovered and wired. Local testing used both synthetic
malformed fixtures and the owner-private candle/rocket assets. Public
GitHub CI tests synthetic input only; 102 original puzzles are not solved.

## Restore the full original orientation rather than XYZ alone

The owner-authentic rocket UCM Engine and Direction markers have opposite
basis directions: Engine matrix flat index 6 is near +1, Direction
flat index 6 near -1; their index 9 values have the opposite signs.
A translation-only SceneKit marker loses this physically relevant
orientation. The production SceneKit group-zero frame now reads ALL
16 validated original UCM floats. Its original row-major axes are
passed as SIMD columns (the original fourth row becomes the translation
column), preserving both original position and orientation under the
imported UCM object transform.

The portable smoke and actual owner-private Candle+Rocket UCM decoder
tests now explicitly verify nonidentity basis and the opposed native
Engine/Direction axes. No native force, heat radius or GOAL is inferred.

## Live authentic SceneKit rocket anchor frame observation (2026-11-23)

`CMOriginalRocketAnchorTelemetry` validates the actual four named
world-space frames `Heat`, `Engine`, `Explode`, `Direction` from ONE
nested rocket child whose original parent is `tmo_heat_rocket`.
It rejects duplicate frames, missing models, wrong owners, nonfinite
positions and degenerate orientation axes. The real UCM Engine and
Direction markers have world-space Y axes that can point entirely
along Z, which is retained rather than being falsely discarded by
the planar heat intersection test.

The SceneKit renderer now samples the imported marker nodes' actual
`presentation.simdWorldTransform` at a bounded cadence during moving
physics, and passes unique complete sets back to the original level
view with strict scene-revision checks. This is live world-space
model ownership and marker motion — no fabricated thermal region,
Win32 `Direction +0x30` source, runtime `+0xFC`, physical impulse,
explosion, or GOAL.

## Actual SceneKit rocket physics body center is now observed

Original Win32 `0x44F264` reads the physics body center before
`0x44F27D` applies Engine force. On iOS the renderer now measures
the genuine nested `tmo_heat_rocket_rocket` **dynamic** physics
body center using its `SCNPhysicsBody.centerOfMassOffset` and
current presentation-node transform. This does not assume model
origin, bounding-box middle, or Engine/Heat markers are the COM.
`CMOriginalRocketAnchorTelemetry.Complete` now carries an optional
`worldDynamicBodyCenter`; malformed/nonfinite data are rejected.
UI distinguishes full observed original marker sets from actual
dynamic body centers. Also fixed its earlier literal escaped string
so the counters actually interpolate instead of showing raw syntax.

The real COM of SceneKit is measured; Win32 native `+0xFC`,
`Direction+0x30` and Engine activation are still separate missing
producers and puzzle GOAL is never inferred from this observation.

## Real lit candle source → rocket Heat geometry bridge (2026-11-23)

Added `CMOriginalRocketCandleHeatPair`: strict, fail-closed pairing
of the original active `tmo_candle +0xEC` from the player session,
exactly one source UCM `Heat` anchor and actual nested
`tmo_heat_rocket_rocket` UCM `Heat` anchor. The SceneKit renderer
samples moving world coordinates, reports true world XY displacements,
and sends bounded, revision-protected observations to the original
level player UI. Tests cover unlit sources, invalid types/owners,
nonfinite and missing frames, and XY-plane-only displacement.

These world-space UCM points do NOT reconstruct the Win32 selector-3
region +0x24 geometry or its local reference frame and must NEVER
trigger `CMOriginalWindowsRocketTimer` ignition or GOAL alone.
