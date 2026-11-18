import SwiftUI
import MetalKit

/// Add a locally licensed UCM asset to the app bundle as sample.ucm to display it.
public struct CMSceneView: UIViewRepresentable {
 public init() {}
 public func makeUIView(context:Context)->MTKView {
  let view=MTKView(frame:.zero)
  view.preferredFramesPerSecond=60
  do {
   let renderer=try CMSceneRenderer(view:view)
   context.coordinator.renderer=renderer
   if let url=Bundle.main.url(forResource:"sample",withExtension:"ucm") {
    try renderer.load(CMUCMModel(data:Data(contentsOf:url)))
   }
   if let url=Bundle.main.url(forResource:"attachment_catalog",withExtension:"json") {
    let catalog=try CMAttachmentCatalog(data:Data(contentsOf:url))
    let slots=catalog.attachments.filter { $0.model.lowercased().hasSuffix("/sample.ucm") }
    try renderer.loadDebugMarkers(slots)
   }
   if let url=Bundle.main.url(forResource:"sample",withExtension:"tga") {
    try renderer.loadTexture(CMTGATexture(data:Data(contentsOf:url)))
   }
  } catch { context.coordinator.error=error.localizedDescription }
  return view
 }
 public func updateUIView(_ uiView:MTKView,context:Context) {}
 public func makeCoordinator()->Coordinator { Coordinator() }
 public final class Coordinator {
  var renderer:CMSceneRenderer?
  var error:String?
 }
}
