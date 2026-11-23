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
