# Capturing the first original Crazy Machines level on an iPhone Simulator

**This is an optional private macOS/Xcode workflow.** It deliberately does not
bundle or publish any original game assets, and it is not equivalent to proof
that original puzzle mechanics work.

## Requirements

- Mac with an installed compatible Xcode, iPhone Simulator and `xcodegen`
  (`brew install xcodegen`).
- An actual `level-001.json` exported from your **own original Professor
  Laboratory CML** by the repository's original-scene export tools.
- A directory containing original `.ucm` meshes extracted from your own
  installation of Crazy Machines. Nested folders are accepted.
- Do not use synthetic playground objects as substitutes for original meshes.

## One-command attempt

From the repository root:

```bash
bash scripts/capture-original-first-level.sh \
  "/private/path/level-001.json" \
  "/private/path/original-game/data/models"
```

By default all private inputs, build results and captures are staged under a
new temporary directory **outside the repository**. Set
`CM_FIRST_LEVEL_OUTPUT=/private/path/out` to select an empty output
directory, or `CM_SIMULATOR_UDID` to target a specific iPhone Simulator.

## What the command actually checks

1. `tools/stage_original_first_level.py` checks the original level schema
   and index, inventories original `3DO` references, and matches them against
   case-insensitive, unambiguous original UCM basenames. It supports the
   original `to_foo` to `foo.ucm` alias only when an exact match is absent.
2. Referenced original UCM files are structurally decoded and checked for
   unsupported index counts and non-finite vertex values before copying.
   Missing or invalid original geometry **fails the command**, rather than
   silently taking a screenshot of substitute objects.
3. `xcodebuild build-for-testing` compiles the actual iOS app and UI tests
   with an Apple SDK, then the original resources are staged inside the
   installed Simulator app's private `Application Support` directory.
4. `testCaptureFirstRealLevel3DWhenSeeded` opens **level 1** through the
   genuine UI, presents the SceneKit scene, and asserts that the scene has
   at least one loaded UCM mesh.
5. XCTest attaches an actual Simulator screenshot and
   `xcresulttool` exports it. A successful run writes
   `original-level-001-iphone-simulator.png` next to the build/test logs.

If Xcode compilation, asset staging, navigation, geometry loading or screenshot
export fails, inspect `build.log` / `ui-test.log`; **do not call this
milestone complete**. When no original scene is staged, the optional UI test
skips in normal CI; that skip is **not evidence of successful rendering**.

## Limits

- Parsed UCM geometry is not yet equivalent to correctly mapped original
  materials, textures or lighting.
- Camera alignment and 3D transforms still require comparison to the PC game.
- The experiment does not validate original physics, mechanisms, level victory
  conditions, audio, signed iPhone IPA or App Store compatibility.
- The repository's standard CI screenshot of the startup menu **is not** a
  screenshot of the original first puzzle.
