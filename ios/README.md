# iOS textured geometry smoke scene

Files: `CMUCMModel.swift`, `CMShaders.metal`, `CMMetalPipeline.swift`, `CMSceneRenderer.swift`, `CMSceneView.swift`, `CMTGATexture.swift`.

Create an iOS SwiftUI Xcode app target, add all five files, and show `CMSceneView()` in the app's root view. Add a locally owned UCM model as `sample.ucm` in the app bundle, and an uncompressed true-color TGA as `sample.tga` to render it.

No game assets are checked in. A white 1×1 texture is used only when sample.tga is absent. This is a single texture smoke test, not the original shader-to-model material binding. Lighting is approximate, model transforms are uncalibrated, and the original material/physics/gameplay systems are not implemented. Compilation on an Apple SDK and actual iPhone rendering still require verification.


## Private build using the original 102-level game pack

The original PC game resources are **not** in this repository and must not
be committed or redistributed. To build a *local* iPhone application that can
open the first authentic scene without manually importing hundreds of files:

1. Obtain your own extracted `CrazyMachines_Original_102Levels.cmassets` file.
2. Copy it to `ios/CrazyMachines_Original_102Levels.cmassets` in your local
   checkout. The `*.cmassets` Git ignore rule prevents committing the file.
3. Run `xcodegen generate --spec project.yml`. XcodeGen adds the custom
   resource under the `ios` sources directory to the app's Resources phase.
4. Build and run on an iPhone/iOS simulator. On first launch, the app checks
   for a bundled pack, imports its validated original models/textures/scenes
   into its own Application Support directory, and shows the home menu.
5. Tap **Play** to open the authentic first scene in 3D if its models resolve.
   The built-in experimental SceneKit physics is **not** the original Windows
   engine and cannot yet reproduce complete original puzzle gameplay.

If the pack is not bundled, use **Game files → Install original game pack
(102 levels)** in the running application to import the private pack from
the Files app. No original files are packaged in the public CI builds.

## Import original levels directly from a PC laboratory

If you have extracted the original `data/models`, `data/textures`,
and `data/labs` but do not have pre-exported JSON levels, build the
private pack with a literal `-` as the second argument:

```bash
python3 tools/build_original_asset_pack.py EXTRACTED_INSTALLATION - CrazyMachines_Original_102Levels.cmassets
```

This smaller pack contains 160 UCM models, 181 TGA textures and the
original laboratory files. On import, the iOS app validates and decodes
the Professor Laboratory CML into playable 102 level documents before
writing any files to the user's app sandbox. A pack with pre-exported
JSON scenes still imports those exact 102 documents unchanged.

Keep `.cmassets` private: game resources must not be pushed to GitHub.

## Verify the actual first original level in a PRIVATE iPhone Simulator build

The public GitHub Actions checks intentionally use a copyright-free UCM
triangle. To capture a real 30-object first Professor Laboratory level
on your own Mac without uploading game assets:

1. Place your own `CrazyMachines_Original_102Levels.cmassets` inside
   `ios/` **only in your local checkout**. It is ignored by Git.
2. Run `xcodegen generate --spec project.yml`.
3. Boot an iPhone simulator in Xcode, then run:

```bash
CM_PRIVATE_ORIGINAL_PACK_TEST=1 xcodebuild \
  -project CrazyMachinesIOS.xcodeproj -scheme CrazyMachinesIOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:CrazyMachinesUITests/CrazyMachinesLaunchUITests/testPrivateOriginalLevelOneWhenOptedIn \
  test
```

The optional UI test installs the *private* original asset pack, opens
Professor level 1 from Play, verifies at least 25 original UCM mesh
instances were attached, and captures arrangement/physics screenshots.
It is automatically **skipped** in public GitHub Actions. Do not push
the `cmassets` file, private screenshots, or `xcresult` containing the
original artwork to public CI/artifacts.
