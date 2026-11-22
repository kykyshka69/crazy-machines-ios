# Crazy Machines — iOS Port: verified project status

Last evidence review: 2026-11-22 (GitHub `main`; latest documented code and local regression verification).
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

## Continued work — original asset verification in the iOS level browser (2026-11-21)

- `89e78c94`: `CMOriginalModelResolver.AssetIndex.locate` now distinguishes **found / missing / ambiguous / invalid reference**, retaining `resolve` for older callers.
- `59cc05cc`: added `ios/CMOriginalAssetAudit.swift`, validating UCM bytes using `CMUCMModel` rather than treating a matching filename as a renderable model. Reports malformed and oversized assets and caches repeated references within one audit.
- `dec3ce25` and `6df64c6e`: wired an **on-demand original geometry verification** control into the level details UI. It runs away from the main actor, displays usable meshes and specific missing/invalid references, and does not claim this validates textures or original physics.
- `97ed364d`: regression suite `tests/OriginalAssetAuditSmoke.swift` uses synthetic UCM v2 bytes and tests valid geometry, missing/corrupt files, unsafe names, case-insensitive de-duplication and ambiguous filenames on Linux.
- `c2163713`, `f74ecd36`: added this regression to GitHub portable CI and `scripts/run-local-checks.sh`.
- **Executed here:** a Foundation-only Swift 6.2.1 Linux *isolated reproduction* of the asset resolver/audit behavior compiled and passed, including missing, malformed, ambiguous and alias cases. The **exact full GitHub test target has not been executed in this environment**. The code compiles in isolation, but SwiftUI/SceneKit and an Xcode iOS app build require a macOS runner.
- GitHub combined commit status for `f74ecd36` currently returned **no statuses** from the connected API, so this is neither a verified CI success nor a failure. No actual first-level iPhone screenshot yet.

## Continued work — reproducible first ORIGINAL level Simulator capture (2026-11-22)

- `47d927f3`: assigned stable accessibility IDs to original level rows, so the UI test can open **original level 1**, not an invented playground.
- `10809541`: SceneKit original-level view now reports the number of **actually constructed imported UCM mesh nodes** through accessibility. A blank SceneKit canvas cannot satisfy the new screenshot assertion.
- `0ac9cf21`: added opt-in `testCaptureFirstRealLevel3DWhenSeeded` to navigate through the real app and attach a screenshot only after nonzero original meshes are loaded. In public CI without licensed game data it deliberately **skips**; a skip does not pass this milestone.
- `9e878ae6`: `tools/stage_original_first_level.py` validates the original level 1 JSON and every referenced original UCM file, rejects missing/corrupt/ambiguous models, and privately stages them for the app sandbox.
- `3139c582`, `5af0ecd3`, `24d26ad3`: added eight synthetic staging regressions, made duplicate detection tests case-sensitive-filesystem aware, and enabled them in Python CI.
- `e81b0f74`: `scripts/capture-original-first-level.sh` performs an actual macOS Xcode `build-for-testing`, boots an iPhone Simulator, seeds the app sandbox with privately staged original models/level JSON, runs the UI screenshot test and exports the screenshot plus logs.
- `b1781db2`: documented exact invocation and limitations in `docs/first-original-level-simulator.md`.
- **Actually executed in this session:** ran `python -m unittest -v test_stage_original_first_level.py` on matching-length local copies of the committed Python sources in Linux using synthetic UCM; **8 tests passed**. `ast.parse` succeeded on the staging/test source, and `bash -n` passed for a matching-length copy of `scripts/capture-original-first-level.sh`. The shell script's non-macOS guard was executed and correctly refused to proceed. This is **not** a run of the Mac/iPhone UI workflow. The original proprietary files were **not available in this runtime**.
- **Not yet executed/verified:** the macOS shell script, Xcode compilation, first-level UI test on iPhone Simulator, actual UCM geometry rendering on Apple SDK, and genuine iPhone screenshot. This environment has Swift/Linux but **no Xcode/iPhone Simulator**. Do not claim the screenshot has been produced.

**Next action:** execute the macOS capture script with a private exported original `level-001.json` and its UCM asset directory; inspect the resulting actual screenshot/coverage; then fix any SceneKit mismatch. See `docs/first-original-level-simulator.md`.

## Priority blockers / work order

1. **DONE IN CODE, AWAITING APP/CI VERIFICATION:** the original level model inventory now calls `CMOriginalModelResolver.allModelNames(in:)`; this collects UCM references from nested `tmo_*` owners, preserves object-local resolution, and de-duplicates case-insensitively. UI readiness and per-level preview selection use it. Regression assertions added, CI Swift compiler inputs corrected. Verify in the actual iOS level browser with user-owned original assets.
2. **Audit code/UI implemented; actual assets outstanding:** open the first real exported level, run *Verify original UCM geometry*, record missing/ambiguous/corrupt meshes, and confirm transforms by comparing the real 3D assembly to the PC game. No original asset files are committed.
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
