import SwiftUI
import MetalKit

/// Previews one authentic user-imported UCM model referenced by an original scene.
/// The preview intentionally does not claim to render a complete level.
struct CMOriginalModelPreview: UIViewRepresentable {
    let modelURL: URL

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero)
        view.preferredFramesPerSecond = 60
        do {
            let renderer = try CMSceneRenderer(view: view)
            try renderer.load(CMUCMModel(data: Data(contentsOf: modelURL)))
            context.coordinator.renderer = renderer
        } catch {
            context.coordinator.error = error.localizedDescription
            view.isPaused = true
        }
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var renderer: CMSceneRenderer?
        var error: String?
    }
}
