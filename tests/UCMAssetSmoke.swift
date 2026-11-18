import Foundation
@main struct UCMAssetSmoke {
 static func main() throws {
  guard CommandLine.arguments.count == 2 else {
   print("Usage: ucm-asset-smoke <directory-containing-locally-owned-ucm-files>")
   return
  }
  let folder=URL(fileURLWithPath:CommandLine.arguments[1])
  let files=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil)
   .filter { $0.pathExtension.lowercased()=="ucm" }
  var vertices=0,triangles=0
  for file in files {
   let model=try CMUCMModel(data:Data(contentsOf:file))
   vertices+=model.vertexCount;triangles+=model.triangleCount
   precondition(model.indices.count==model.triangleCount*3)
  }
  print("models=\(files.count) vertices=\(vertices) triangles=\(triangles)")
  precondition(files.count==160 && vertices==55342 && triangles==22497)
 }
}
