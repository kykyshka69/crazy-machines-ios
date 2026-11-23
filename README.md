# Crazy Machines — original PC game to iOS

**Active working branch:** [`work/original-3d-scene-batch`](https://github.com/kykyshka69/crazy-machines-ios/tree/work/original-3d-scene-batch).

**READ THIS FIRST BEFORE EDITING ANYTHING:** [`PROJECT_STATUS.md`](PROJECT_STATUS.md), especially the **START HERE** section. It records verified commits and GitHub Actions outcomes, exact unfinished Stage 1 mechanics, and the next coding task. The `main` branch is divergent and must not be used for a duplicate port.

## What already exists

This is an actual SwiftUI/SceneKit iOS application project with original CML scene decoding, original UCM 3D mesh and TGA texture loading, 102 privately imported Professor scenes, user placement controls, a Windows GOAL/CONNECTED_TO counter and evidence-limited experimental mechanics. **It builds and its public iOS Simulator UI tests run.** Public CI uses copyright-free synthetic scene fixtures and intentionally skips private original-level tests. This does **NOT** mean all 102 original puzzles are playable with faithful Windows physics or have been completed.

## Current work

**Stage 1 remains OPEN.** Finish original electrical power routing and blocking, physical transmission between motors/gears/belts and other mechanisms, event dispatch, and original start/run/stop/victory behavior. Run authentic owner-only original levels in an actual iOS Simulator and verify all 102 end-to-end before marking Stage 1 complete. Do not announce percentages or replace the PC game with a synthetic imitation.

## Code and test entrypoints

- `PROJECT_STATUS.md` — canonical continuation and evidence log.
- `ios/CMOriginalQuickPlayView.swift` — original level player and event coordination.
- `ios/CMOriginalAssembledSceneView.swift` — original UCM SceneKit assembly and physics.
- `ios/CMOriginalPowerCircuit.swift` — experimental explicit plug topology.
- `ios/CMOriginalWindowsGoalCounter.swift` — recovered dual-channel Win32 completion gate.
- `scripts/run-local-checks.sh` — portable tests; `.github/workflows/` — iOS Simulator, iPhone ARM64 and source checks.

## Copyright and resource safety

Keep the user's proprietary PC installer, executable, `.cmassets` pack, CML, UCM, TGA, scripts and original level contents **out of public Git commits and public CI**. Synthetic fixture art is test-only and cannot be presented as a screenshot from a genuine PC level.
