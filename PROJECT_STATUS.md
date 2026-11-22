# Crazy Machines — iOS Port: verified project status

Last evidence review: 2026-11-22 (GitHub main; native CML decoder code and local Foundation tests reviewed).
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

## Continued work — first-level screenshot authenticity guard (2026-11-22)

- **Issue fixed:** the existing macOS screenshot script copied the *first arbitrary PNG* exported by `xcresulttool`, risking a startup/diagnostic image being presented as the first original puzzle.
- `34a1a162`: new `tools/select_first_level_screenshot.py` validates the actual Xcode test summary (exactly one test passed, zero failed/skipped) and the export `manifest.json`, requiring the uniquely named attachment `04-real-first-original-level-3d` from the real first-level UI test. Invalid/ambiguous images, unsupported filenames, and overwrite attempts are rejected.
- `958450ff`: added 10 synthetic regression tests covering the intended attachment, skipped or failed tests, wrong test/attachment, ambiguous matches, traversal attempts, invalid PNG and overwrite.
- `00cefa02`: integrated the strict screenshot selection into `scripts/capture-original-first-level.sh`. An arbitrary Xcode screenshot can no longer be called the first original level by the script.
- `9bf5af52`: enabled screenshot-selection tests in portable Python CI.
- `941edc45`: documented the strict capture gate in `docs/first-original-level-simulator.md`.
- **Verified here:** 10/10 screenshot-selector Python unit tests passed on Linux, and `py_compile` succeeded for the selector and tests. GitHub-published selector was re-fetched to verify content; no macOS/Xcode/SceneKit runtime was available, so **real screenshot still not captured**.
- **Next:** run the existing private first-level script on a Mac with the original level JSON + UCM assets, inspect Xcode test logs and exact screenshot, and fix the first actual Apple-SDK or renderer defect revealed.

## Continued work — native original CML decoding on iPhone (2026-11-22)

**Major functional change:** the iOS app no longer requires a separate Windows/Python JSON export to discover original level scenes. Import original `.cml` directly in **Original levels**, or import CML through **Original files** then use **Decode previously imported CML**.

- `33fe4c1d`: portable SHA-256 for exact `scene_sha256` of decompressed original scene bytes.
- `e5b325bc`, `7dda11d6`: native Swift original CML decoder: validates all three framed header fields, reads per-level flag/length/CP1251 title, decompresses 12-bit big-endian LZW with terminator 4095, parses original brace-structured scene nodes and preserves POS/POSREL/ROT/ROTREL, GOAL and 3DO model ownership. All decoded JSON passes the same bounded `CMOriginalSceneDocument.read` validation as imported files.
- `a1e1aba3`: scene document / nested node structures are `Codable`, supporting exact JSON persistence of natively recovered data.
- `f4eddab5`: saves validated native CML level metadata to `OriginalScenes/level-XXX.json` without overwriting an existing different export.
- `1f611b76`, `ec7a1551`, `d2c1c17a`: direct on-device CML file import and import from already copied original resources; decode occurs off the UI thread. CML candidates previously imported into Original files are selected by validated nonempty record count.
- `c276a34b`, `736be995`, `e01d9169`: synthetic original-format CML regression: decoded framing (including independently Python-generated golden frame), CP1251 Cyrillic title, LZW literal/dictionary codes, original scene hierarchy/fields, SHA-256, atomic persistence and idempotent reimport. Malformed frame and missing LZW terminator rejected.
- `4bfe8c89`, `e71b096f`: portable GitHub Actions job and local check script updated to compile/run the native decoder smoke.
- `84efccaf`, `0cb9b51f`, `828bd85b`: app labels and UI navigation smoke updated for on-device original CML import.
- `7fb5b938`, `8b6cb29b`: user/workflow guidance in `docs/native-cml-on-iphone.md` and updated root README, removing stale claims that the loader is only a research candidate.
- **Executed here:** a local Swift 6.2.1/Linux standalone Foundation build and execution of the native CML decoder, SHA-256 and storage against a synthetic 1-level original-format CML file **passed**. The fixture roundtrips original byte framing and 12-bit LZW to a structured original object with transforms and model references. No copyrighted game bytes used. The GitHub source was re-fetched after commit and the new component files/identifiers confirmed.
- **Still unverified:** decoding the genuine 102-level original CML *in the iOS Simulator or on an iPhone*, a full macOS/Xcode app build, genuine first-level screenshot, complete UCM materials and original puzzle physics. Portable synthetic tests are not proof of gameplay parity.

**Next action:** perform an Apple-SDK build and native import of the original user-owned Professor Laboratory CML, verify 102 scenes/model availability and capture the actual first puzzle. Use `docs/native-cml-on-iphone.md`; do not restart reverse-engineering from scratch.

## CRITICAL: branch divergence / avoid duplicated implementation (2026-11-22)

Verified GitHub branch comparison (merge base `ef3151d6c2fef5248501d645ded3b7dd1aa4f9a2`):

- `main` at `e8ce55e1` had **64 commits not in** `work/original-3d-scene-batch`.
- `work/original-3d-scene-batch` at `d4793cc0` had **168 commits not in** `main`.
- These are divergent branches, **not** one ahead of the other. Do not erase either branch or fast-forward blindly.
- **Actual feature overlap:** both independently implement CML decoding, 12-bit LZW, Windows-1251 scene parsing, original-level import and 3D scene UI. The `main` implementation `CMOriginalCMLDecoder.swift` duplicates the work branch's separate `CMOriginalCMLContainer.swift`, `CMOriginalLZW12.swift`, `CMOriginalWindows1251.swift`, `CMOriginalSceneTextParser.swift` and `CMOriginalLaboratorySceneInstaller.swift`. Both also implement original model resolution/3D assembly and first-level screenshots.
- **Important code unique to work branch:** `CMOriginalQuickPlayView.swift`, `CMOriginalAssetPackImporter.swift`, `CMOriginalFirstLevelRun.swift`, scene/physics role planners, collision/contact components, native game start flow and a private original-resource-pack test + signed-device build script.
- **Important work unique to main:** `CMOriginalAssetAudit.swift`, `CMOriginalAssetAuditView.swift`, `tools/select_first_level_screenshot.py`, the strict screenshot authenticity checks and standalone user-owned CML staging/selection scripts.
- **Integration decision needed before further overlapping code:** use `work/original-3d-scene-batch` as the provisional integration baseline because it includes the richer in-app game flow. Make a separate integration branch, bring over compatible main-only safety checks and workflows, and resolve overlapping SwiftUI/SceneKit/CML changes explicitly. Run portable tests, then Xcode/iPhone Simulator checks before moving `main`.
- **Do not treat work-branch CI or screenshots as verified passes:** connected GitHub combined status returned no status checks for either branch head during this review. Read real logs/artifacts before making claims.
- Avoid writing a third CML decoder, a third original-level screen or a separate first-level launch path before this reconciliation.

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
