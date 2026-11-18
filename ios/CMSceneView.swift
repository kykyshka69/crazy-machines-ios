import SwiftUI
import MetalKit
import UIKit

/// Add a locally licensed UCM asset to the app bundle as sample.ucm to display it.
public struct CMSceneView: UIViewRepresentable {
 public init() {}
 public func makeUIView(context:Context)->MTKView {
  let view=MTKView(frame:.zero)
  view.preferredFramesPerSecond=60
  let status=UILabel()
  status.textColor=.white
  status.font=.systemFont(ofSize:14,weight:.medium)
  status.numberOfLines=0
  status.textAlignment=.center
  status.translatesAutoresizingMaskIntoConstraints=false
  view.addSubview(status)
  NSLayoutConstraint.activate([
   status.centerXAnchor.constraint(equalTo:view.centerXAnchor),
   status.centerYAnchor.constraint(equalTo:view.centerYAnchor),
   status.leadingAnchor.constraint(greaterThanOrEqualTo:view.leadingAnchor,constant:24),
   status.trailingAnchor.constraint(lessThanOrEqualTo:view.trailingAnchor,constant:-24)
  ])
  var modelLoaded=false
  do {
   let renderer=try CMSceneRenderer(view:view)
   context.coordinator.renderer=renderer
   if let url=Bundle.main.url(forResource:"sample",withExtension:"ucm") {
    try renderer.load(CMUCMModel(data:Data(contentsOf:url)))
    modelLoaded=true
   }
   let originalName=Bundle.main.url(forResource:"sample_model_name",withExtension:"txt")
     .flatMap { try? String(contentsOf:$0,encoding:.utf8) }
   let trimmed=originalName?.trimmingCharacters(in:.whitespacesAndNewlines) ?? ""
   let name=(trimmed.isEmpty ? "sample.ucm" : trimmed).lowercased()
   if let url=Bundle.main.url(forResource:"attachment_catalog",withExtension:"json") {
    // Debug data is optional: a corrupt catalog must not hide valid geometry.
    if let data=try? Data(contentsOf:url),
       let catalog=try? CMAttachmentCatalog(data:data) {
     let slots=catalog.attachments.filter {
      $0.model.lowercased() == name || $0.model.lowercased().hasSuffix("/"+name)
     }
     try? renderer.loadDebugMarkers(slots)
    }
   }
   // An explicit sample texture overrides the candidate texture, not its blend state.
   let manifest=Bundle.main.url(forResource:"material_candidates",withExtension:"json")
   let candidates:CMMaterialCandidates? = manifest.flatMap { url in
    guard let data=try? Data(contentsOf:url) else { return nil }
    return try? CMMaterialCandidates(data:data)
   }
   renderer.setPreviewBlend(candidates?.previewBlend(modelName:name))
   try? renderer.setPreviewAddress(candidates?.previewAddress(modelName:name))
   if let url=Bundle.main.url(forResource:"sample",withExtension:"tga") {
    if let data=try? Data(contentsOf:url),
       let texture=try? CMTGATexture(data:data) {
     try? renderer.loadTexture(texture)
    }
   } else if let texturePath=candidates?.previewTexture(modelName:name) {
    let normalized=texturePath.replacingOccurrences(of:"\\",with:"/")
    let parts=normalized.split(separator:"/").map(String.init)
    if let filename=parts.last {
     let subdir=parts.dropLast().joined(separator:"/")
     let base=(filename as NSString).deletingPathExtension
     if let textureURL=Bundle.main.url(forResource:base,withExtension:"tga",
                                        subdirectory:subdir.isEmpty ? nil : subdir) {
      if let data=try? Data(contentsOf:textureURL),
         let texture=try? CMTGATexture(data:data) {
       try? renderer.loadTexture(texture)
      }
     }
    }
   }
  } catch {
   context.coordinator.error=error.localizedDescription
   status.text="Cannot load 3D scene: \(error.localizedDescription)"
  }
  if context.coordinator.error == nil && !modelLoaded {
   status.text="No sample.ucm in app bundle. Add a locally owned UCM model to preview it."
  }
  return view
 }
 public func updateUIView(_ uiView:MTKView,context:Context) {}
 public func makeCoordinator()->Coordinator { Coordinator() }
 public final class Coordinator {
  var renderer:CMSceneRenderer?
  var error:String?
 }
}
