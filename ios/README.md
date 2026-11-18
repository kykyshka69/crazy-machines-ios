# iOS geometry-only smoke scene

Files: `CMUCMModel.swift`, `CMShaders.metal`, `CMMetalPipeline.swift`, `CMSceneRenderer.swift`, `CMSceneView.swift`.

Create an iOS SwiftUI Xcode app target, add all five files, and show `CMSceneView()` in the app's root view. Add a locally owned UCM model as `sample.ucm` in the app bundle to render it.

No game assets are checked in. The fallback is a white 1×1 texture. Lighting is approximate, model transforms are uncalibrated, and the original material/physics/gameplay systems are not implemented. Compilation on an Apple SDK and actual iPhone rendering still require verification.
