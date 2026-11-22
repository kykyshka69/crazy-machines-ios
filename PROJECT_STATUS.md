# Crazy Machines — original iOS port: working branch

## Verified original PC resources and private simulator handoff (2026-11-22)

- The user-owned, **private** `CrazyMachines_Original_102Levels.cmassets` has been recovered from the user's ChatGPT Library and inspected *outside GitHub*. Size **33,369,110 bytes**, SHA-256 `936e025b512452fb6767643bc5762bb713c7ab0d604ac4fbb963fec67d9ac532`. Its **445 entries** have valid SHA-256 checksums and comprise **160 UCMs, 181 TGAs, 102 JSON level scenes and 2 CMLs**. Do NOT upload the pack or original game meshes into the public GitHub repository.
- **Authentic first PC Professor level** (`level-001.json`) contains **30 original tmo objects / 30 actual 3DO mesh references** (7 boards, 14 mounts, 3 arrows, 3 balls, 1 crate, 1 capture zone, 1 background); exactly **2 boards are UNLOCKED** and **4 source objects target the same zone** via `CONNECTED_TO 11`. All **9 unique original UCM references** resolve successfully to the private pack, with **1,761 triangles** across the 30 drawable instances. A private local offline renderer reconstructed the board from real positions/models; this is *NOT* an iPhone screenshot and uses approximate shader/texture colors.
- Cross-level private audit: **102 genuine levels**, **5,626 3DO references**, **125 distinct model names**. **5 glow/effect names** do not have UCM meshes (85 referenced instances): `to_candle_glow`, `to_power_lamp_bulb_bb`, `to_light_magnifier_glow_left`, `to_light_magnifier_glow_right`, `to_light_pocketlamp_glow`. Corresponding original glow TGAs exist for some effects; their PC billboard rendering semantics have not yet been reconstructed. **The original first level has zero unresolved references**.
- **iPhone simulator app with private pack:** a private local ZIP has been created from the unsigned Simulator app artifact of commit `efa3230e` and the exact user-owned `.cmassets`. It can be installed via `xcrun simctl install` on a Mac with Xcode, but **this combined private app has not itself been booted/tested on a Mac**. It is *not* a signed physical-iPhone IPA.
- **Latest UI fix:** `efa3230e` moves user-selected `.cmassets` pack validation and installation away from the main thread, with a progress indicator and reentry guard. Its Source checks and Portable checks succeeded and its Xcode iOS Simulator compilation succeeded. CI [run 45009481504](https://github.com/kykyshka69/crazy-machines-ios/actions/runs/45009481504) attempt 1 failed **after compilation** due hosted macOS CoreSimulator `bootstatus` timing out on two iPhone 17 Pro devices. A same-commit re-run was initiated; no new code errors were observed in the failing attempt.
- **Future integration constraints:** never replace actual original PC puzzle screenshots with synthetic CI UCM fixtures or an offline QA projection. A true first-level iPhone Simulator screenshot still requires running the **private combined app** on macOS. Test-first is preferable to guessing recovered PC physics or shader behavior.

## Working-branch verified handoff (2026-11-22)

- **Single active development branch:** `work/original-3d-scene-batch`. The old integration work was incorporated previously; do not restart a second implementation on `main`.
- **Gameplay UI/renderer already committed:** one-finger direct drag of authentic `UNLOCKED` original pieces, two-finger camera pan, camera recenter, flexible 3D viewport, and a scene-scoped decoded TGA cache. Commits `b3d653d`, `2297d82`, `d517221`, `3994e9c`, `b33fa5f`, `f656c8f`. These changes preserve original CML imports and experimental SceneKit physics.
- **Specific simulator failure diagnosed:** run [45001077011](https://github.com/kykyshka69/crazy-machines-ios/actions/runs/45001077011) **successfully compiled** both simulator architectures, but the hosted macOS CoreSimulator command `simctl list devices booted -j` stalled **after the targeted `bootstatus` returned**. The follow-up device boot command also timed out; consequently no UI tests or new screen captures were produced in that run. This was not an Xcode compile failure.
- **Fix committed:** `91b331f` avoids re-querying the global simulator inventory after the selected device's successful `bootstatus -b`; removes an extra unbounded `simctl list` in CI; adds an explicit regression test for the stalled global-list scenario.
- **Fully verified for `91b331f`:** [Source checks](https://github.com/kykyshka69/crazy-machines-ios/actions/runs/45006370267), [Portable checks](https://github.com/kykyshka69/crazy-machines-ios/actions/runs/45006370242), and [macOS iPhone Simulator build + boot + UI tests](https://github.com/kykyshka69/crazy-machines-ios/actions/runs/45006370276) all **SUCCEEDED**. A genuine **iPhone 16e Simulator** booted the app; Xcode UI tests executed **6 cases: 5 passed, 1 intentionally skipped (private authentic first level), 0 failures**. Real iPhone Simulator CI screenshots were exported as GitHub artifacts: `CrazyMachinesIOS-ui-screenshots` ID `14748287443`, `CrazyMachinesIOS-iphone-launch-screenshot` ID `14748381593`. They show the home menu plus a visible orange nonproprietary UCM triangle and cyan calibration sphere (arrangement and running physics), **not an authentic Crazy Machines PC level**. Do not present the synthetic fixture as a PC-level screenshot.
- **Authentic original level 1 still needs private verification:** Public CI intentionally has no copyrighted PC asset pack. Real original Professor level-one screenshot requires the user-owned `CrazyMachines_Original_102Levels.cmassets`, 25+ original UCM meshes and the private XCTest. Previous public screenshots are a synthetic orange SceneKit UCM fixture, *not* screenshots of the authentic original PC level.

Older integration and CI notes remain below as historical milestones, not the current test status.

**Primary development branch: `work/original-3d-scene-batch`.**
The former `integration/original-game-unified` changes were merged into this
branch via [PR #4](https://github.com/kykyshka69/crazy-machines-ios/pull/4),
merge commit `f86fb90ca34fc13b4883f696a4db9c35d11b0ba4`. The redundant draft
PR #3 against `main` was closed without merging; `main` remains unchanged.
Do not resume two independent CML/SceneKit implementations.

**Actual connected GitHub Actions evidence for PR #4 at integration commit
`1a744a9e`**: `Source checks` — all **16 jobs passed**; `Portable checks`
— passed. This includes the new UCM integrity smoke and screenshot-selector
regressions. The macOS `iOS simulator build` job has now **successfully completed its Xcode compilation** for the iPhone Simulator (GitHub run `44993963653`, job `137120900299`, step `Build for iOS Simulator without signing`: success). Simulator boot/launch, UI tests and screenshot artifacts were **not yet confirmed** at this review. This is **not** a genuine original level-one screenshot.

## Confirmed iPhone 17 Pro SceneKit UI screenshots and private-pack readiness (2026-11-22)

**Runtime evidence from macOS GitHub Actions run `44993963653`, job `137120900299`: SUCCESS.** Real Xcode compilation, iPhone **17 Pro** simulator boot, app launch, and UI navigation/SceneKit tests passed. XCTest log reports **6 executed, 5 passed, 1 deliberately skipped, 0 failures**. The skipped test was `testPrivateOriginalLevelOneWhenOptedIn`, because licensed original PC game resources are not present on public CI.

**Actual extracted Simulator screenshots**, artifact `CrazyMachinesIOS-ui-screenshots` ID `14743416604`: `05-imported-original-3D-SceneKit-fixture` demonstrates the original UCM-loading/SceneKit path rendering a visible **synthetic orange triangle** and cyan calibration sphere; `05b-running-3D-SceneKit-fixture` demonstrates that the same SceneKit scene remains visible with experimental physics switched on. These are **real simulator screenshots of the app, not screenshots of a real copyrighted Crazy Machines puzzle**. Public CI also provides menu, imported-scene browser, and file importer screenshots.

**Player-facing fixes after that successful run** (require new Apple-SDK CI confirmation):
- `0a466287`, `211c131c`: private `CrazyMachines_Original_102Levels.cmassets` now installs and validates **off the main thread**, preventing a lengthy 445-file import from freezing the initial iPhone UI. Play/Game files are disabled from the very first frame until installation completes; a ProgressView explains the work. The private simulator diagnostic is emitted only after installation finishes.
- `d2d182c8`: genuine original level-one UI test now waits for the verified import before tapping Play rather than racing the background installation.
- `4395d8ac`, `b7599a14`: bounded Simulator boot helper now honors a requested `CM_SIMULATOR_UDID` and has two additional synthetic regression tests.
- `650e05d6`: private original level-one macOS capture script now reuses the bounded boot helper, preserves the requested iPhone target and cleans up **only** the proprietary `.cmassets` file it copied into the checkout; it never deletes a pre-existing user-owned pack.

**Next required actual milestone:** run the private first-level test on macOS with a user-owned `CrazyMachines_Original_102Levels.cmassets`. Confirm 25+ original UCM mesh instances and review a genuine first original Professor level screenshot; this has **not** happened in public CI. Do not confuse synthetic triangle rendering with original puzzle rendering.

## Simulator startup reliability and direct work-branch CI (2026-11-22)

- `6f54dded`: new `tools/boot_iphone_simulator_ci.py` selects a booted/available iPhone, limits blocking `simctl bootstatus` to 130 seconds per attempt and tries one additional iPhone rather than hanging forever.
- `0d23ceed`: nine tests for simulator selection, retry, invalid device lists and timeout handling, using fake `simctl` responses (no Apple SDK or copyrighted game assets needed).
- `9effab1b`: iOS workflow uses that bounded boot helper, preserves the selected simulator ID for UI tests, and enables simulator UI tests on pushes to the **work branch**.
- `e46efd7f`, `08bc87f3`: source and portable GitHub Actions now run on pushes to the work branch (instead of waiting for a separate PR to `main`). The new boot tests are in Python CI.
- **Verified from the earlier PR #4 macOS run** `44993963653`: compilation succeeded, and the Simulator boot/initial launch step later also reported success. The UI test step was still **running** at the last check; the actual scene screenshots and final UI result were not yet available.
- **Verification limits:** the newly committed timeout/retry code and nine CI tests still need their own fresh run results. The earlier successful Xcode build was for integration commit `1a744a9e`, not these subsequent workflow changes. The original user-owned PC game resources remain unavailable in public CI.

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
