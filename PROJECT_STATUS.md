# Crazy Machines — original iOS port: working branch

**Primary development branch: `work/original-3d-scene-batch`.**
The former `integration/original-game-unified` changes were merged into this
branch via [PR #4](https://github.com/kykyshka69/crazy-machines-ios/pull/4),
merge commit `f86fb90ca34fc13b4883f696a4db9c35d11b0ba4`. The redundant draft
PR #3 against `main` was closed without merging; `main` remains unchanged.
Do not resume two independent CML/SceneKit implementations.

**Actual connected GitHub Actions evidence for PR #4 at integration commit
`1a744a9e`**: `Source checks` — all **16 jobs passed**; `Portable checks`
— passed. This includes the new UCM integrity smoke and screenshot-selector
regressions. The macOS `iOS simulator build` job was **in progress** at this
review; its Xcode build/UI test result is **not yet confirmed**. This is
not a genuine original level-one screenshot.

**New player-facing fixes**: imported CML now decrypts and converts the
original levels away from the SwiftUI main thread; original first-level
Play requires parsed, valid UCM geometry rather than checking only filenames.
The original Quick Play, CML import, 3D renderer and prototype physics were
retained from the main work branch.


Updated: 2026-11-22. Branch: `integration/original-game-unified`.

## Authoritative starting point

This integration branch is based on `work/original-3d-scene-batch` at `d4793cc0`. It **preserves** the work branch's original 3D assembly, Quick Play, original CML container/LZW/scene parser, asset packs, experimental contacts/physics, first-level run state, iOS menu and private original Professor level-one test.

The branches `main` and `work/original-3d-scene-batch` diverged after `ef3151d6`. At the comparison date the work branch was 168 commits ahead / 64 behind `main`. Their overlapping CML/scene/3D changes must NOT be blindly merged or reimplemented a third time.

## Main-only improvements now integrated

- `CMOriginalAssetAudit.swift`, `CMOriginalAssetAuditView.swift`, `OriginalAssetAuditSmoke.swift`: validate actual referenced UCM mesh geometry instead of only matching asset filenames. Integrated with the work branch's `AssetIndex.resolution(for:)` API and visible in the **Original UCM geometry verification** section of the original level browser. The existing detailed missing-model report and Quick Play navigation remain.
- `tools/select_first_level_screenshot.py`, `tools/test_select_first_level_screenshot.py`: strict named screenshot selection from Xcode test results. Adapted to the work branch's stronger original Professor private UI test `testPrivateOriginalLevelOneWhenOptedIn` and actual attachment name `07-PRIVATE-original-professor-level-001`.
- `scripts/capture-private-professor-level-one.sh`: optional macOS workflow, uses a user-owned original `.cmassets` pack outside Git, real Xcode/iPhone Simulator and the existing private UI test (minimum 25 original UCM meshes). Rejects skipped/failed tests or unrelated PNGs. See `ios/README.md`.
- Linux CI source checks updated to run the integrated asset-audit Swift smoke and screenshot-selector Python regression.

## Not duplicated

- Do **not** copy `CMOriginalCMLDecoder.swift`, `CMOriginalCMLStorage.swift`, `CMOriginalSHA256.swift` from `main`: the work branch's established `CMOriginalCMLContainer`, `CMOriginalLZW12`, `CMOriginalWindows1251`, `CMOriginalSceneTextParser`, `CMOriginalLaboratorySceneInstaller` provide that pipeline and already feed Quick Play.
- Do **not** overwrite the work branch's larger `CMOriginalAssembledSceneView.swift` or `CMOriginalGameplaySession.swift` with `main`'s smaller prototypes. Existing work-branch mechanics and original level-to-level flow are the integration baseline.
- `main`'s separate JSON staging/screenshot scripts are not transplanted blindly: their UI-test identifiers and the app start flow are incompatible with the work branch.

## Verification boundaries and remaining work

- Confirmed through GitHub API: actual file content was committed to this integration branch, the UI audit was wired to the level browser, and tests were added to CI configuration.
- **Not yet confirmed:** current branch's passing Swift/Python CI job results, Xcode compilation on macOS, real first-level Simulator screen, Apple-device performance, accurate original physics and winning rules.
- The genuine Crazy Machines proprietary game assets and screenshots are not in this repository.
- The integration is **not yet merged** into `main`. A GitHub PR should be reviewed for conflicts; do not delete either original branch before both implementations are safely reconciled.

## Next engineering action

Run Linux portable source checks and Xcode/iPhone Simulator PR checks. Fix any failures, then complete the integration PR into `main` with all unique work preserved. For an authentic private level-one capture, run `scripts/capture-private-professor-level-one.sh` on macOS with the user's private `CrazyMachines_Original_102Levels.cmassets`. Do not claim a genuine screenshot until the actual Xcode test and artifact have been examined.
