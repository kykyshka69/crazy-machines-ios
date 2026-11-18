# iOS textured geometry smoke scene

Files: `CMUCMModel.swift`, `CMShaders.metal`, `CMMetalPipeline.swift`, `CMSceneRenderer.swift`, `CMSceneView.swift`, `CMTGATexture.swift`.

Create an iOS SwiftUI Xcode app target, add all five files, and show `CMSceneView()` in the app's root view. Add a locally owned UCM model as `sample.ucm` in the app bundle, and an uncompressed true-color TGA as `sample.tga` to render it.

No game assets are checked in. A white 1×1 texture is used only when sample.tga is absent. This is a single texture smoke test, not the original shader-to-model material binding. Lighting is approximate, model transforms are uncalibrated, and the original material/physics/gameplay systems are not implemented. Compilation on an Apple SDK and actual iPhone rendering still require verification.
