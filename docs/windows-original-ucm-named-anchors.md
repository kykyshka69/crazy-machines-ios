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
