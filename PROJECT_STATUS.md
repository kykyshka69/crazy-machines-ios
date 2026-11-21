# Crazy Machines — iOS Port: verified project status

Last evidence review: 2026-11-21 (GitHub `main`; latest implementation commit `d0326376`, following baseline `fd3ceca6`).
Primary goal: load and play the **original PC Crazy Machines puzzles on iPhone**. This is not yet a playable port.

## Verified work present in the repository

- **Original PC formats:** reverse-engineering notes and scripts for UCM, CML and original scenes in `docs/` and `tools/`. The structural audit reports exact lengths for **160/160 original UCM models** (`docs/ucm-structural-audit.md`); the semantics of all UCM material/extension fields are **not** proven.
- **Original laboratories:** `docs/original-cml-windows-loader.md` documents a verified decoded header field value of **102** for the Professor laboratory and local decoder investigations. Tools for scene export, parsing, and auditing exist, but this is not proof that all puzzles play on iOS.
- **iOS original-file importer:** `ios/CMOriginalResourcesView.swift` imports user-owned `.cml`, `.ucm`, `.tga` and other supported assets to app storage. UCM files are validated at import.
- **Original scene browser:** `ios/CMOriginalLevelBrowserView.swift` imports exported original JSON scenes, shows objects/annotations and opens read-only map and 3D views.
- **3D:** `ios/CMOriginalAssembledSceneView.swift` builds a SceneKit scene using imported UCM meshes and original transforms where available. Unavailable meshes are omitted. This is **not** proven pixel-accurate original rendering.
- **Physics/gameplay infrastructure:** `ios/CMOriginalGameplaySession.swift` tracks original object identities, lifecycle, contact activations and explicitly configured experimental reactions. `ios/CMPhysics2D.swift` and joint implementations provide a separate prototype. **Original puzzle mechanics and winning conditions are not yet verified or complete.**
- **Build/test infrastructure:** `project.yml`, `.github/workflows/source-checks.yml`, `.github/workflows/ios-simulator-build.yml`, `scripts/run-local-checks.sh`, and fixture-based tests exist.

## Verification boundaries (do not confuse code with successful execution)

- Confirmed by repository inspection: the above files and implementations exist.
- Repository CI workflows have build, simulator launch, screenshots and UI tests configured, **but the current GitHub connector returned no status checks and no PR-triggered workflow runs for baseline `fd3ceca6`**. This is *not* evidence of a pass or a failure; latest run results are unverified here.
- **No verified screenshot of the first original puzzle on an iPhone or iPhone simulator** in this review. A screenshot of a synthetic preview or launch screen is not sufficient.
- Actual iOS SDK compilation, real-device installation, original textures/material mapping, complete puzzle physics, win/next-level transitions, save/audio and IPA delivery remain unverified or incomplete.
- Original game binaries/assets are deliberately **not committed**; imported from a user's licensed copy.

## Implemented fixes after the baseline (2026-11-21)

- `5d721eeb`: added `CMOriginalModelResolver.allModelNames(in:)` to collect models across all original level objects rather than incorrectly treating only the `level` root as their owner.
- `44614dc2`: original level browser now uses the whole-level inventory in both **Original 3D asset readiness** and **Original 3D models**.
- `8a48712d`: regression checks added to `tests/OriginalSceneDocumentSmoke.swift` for root-only, nested, mixed-case, and two-object model inventories.
- `534b0ccc`: repaired `.github/workflows/source-checks.yml` original-scene Swift compile command by including `ios/CMOriginalModelResolver.swift`, which the test imports.
- **Check executed here:** an isolated Swift 6.2.1 (Linux) smoke compiled and passed whole-level collection with 3 original object owners, nested owner and mixed-case duplicates. **Not** a full Xcode/SceneKit run, and **not** a run of the complete repository test suite.
- GitHub Actions results and the screenshot of an actual original level on an iPhone remain unverified.

## Continued work — metadata-only original meshes and first-level access (2026-11-21)

- `551fc230`: `CMOriginalModelResolver.metadataOnlyModelNames(in:)` distinguishes genuine `3DO` mesh nodes from model names preserved only in an object's metadata. Nested `tmo_*` objects are not accidentally assigned to the parent.
- `7e651997`: the SceneKit assembly renders metadata-only original model references at the owner's transform, through the existing UCM loader. This is a **fallback** only: without an original `3DO` transform, placement precision cannot be guaranteed; explicit `3DO` geometry is not duplicated.
- `b7093cb9`: Swift original-scene regression assertions cover explicit meshes, mixed-case duplicates, nested ownership, and metadata-only models.
- `d0326376`: added a direct **3D view** navigation-bar action inside original level details so the first original level's preview is reachable without scrolling through all properties.
- Local run: `swiftc` compiled and executed a **standalone Foundation-only reproduction of the new metadata fallback logic** against explicit, metadata-only, nested and casing fixtures (PASS). This did **not** execute the full repository tests, compile SceneKit/SwiftUI, or start the iPhone Simulator.
- Device/simulator screenshots, CI job results, genuine first-level asset coverage, exact materials and gameplay parity: **not confirmed**.

## Priority blockers / work order

1. **DONE IN CODE, AWAITING APP/CI VERIFICATION:** the original level model inventory now calls `CMOriginalModelResolver.allModelNames(in:)`; this collects UCM references from nested `tmo_*` owners, preserves object-local resolution, and de-duplicates case-insensitively. UI readiness and per-level preview selection use it. Regression assertions added, CI Swift compiler inputs corrected. Verify in the actual iOS level browser with user-owned original assets.
2. Confirm the first *real* exported level's full mesh coverage: which referenced UCM models resolve, which are missing/ambiguous and whether transforms are consistent.
3. Finish materials/UV binding and level rendering parity, then demonstrate an actual first-level screenshot from the iPhone Simulator.
4. Implement and validate original puzzle-specific object physics and win/failure logic; do not replace with generic toy physics and claim gameplay parity.
5. Compile with Xcode on macOS, review CI logs, launch on a real iPhone, verify controls/performance and prepare signed distribution.

## Next-session handoff

Read this file **and inspect current `main` / CI** before making any change. Do not restart the UCM/CML investigation from scratch. Favor a reproducible first original puzzle on iPhone over adding broad unrelated tests. Only call something 'verified on iPhone' if device/simulator output actually proves it. Update this file after confirmed fixes. Do not report completion percentages.

## Evidence links

- `docs/ucm-structural-audit.md`
- `docs/original-cml-windows-loader.md`
- `ios/CMOriginalLevelBrowserView.swift`
- `ios/CMOriginalModelResolver.swift`
- `ios/CMOriginalAssembledSceneView.swift`
- `ios/CMOriginalGameplaySession.swift`
- `.github/workflows/ios-simulator-build.yml`
