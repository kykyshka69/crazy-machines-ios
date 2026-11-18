import Foundation
@main struct MaterialCandidateSmoke {
 static func main() throws {
  func manifest(_ status:String,_ candidates:String)->Data {
   Data(("{\"schema\":\"cm-candidate-bindings-v1\",\"models\":[{\"model\":\"models/ball.ucm\",\"status\":\""+status+"\",\"candidates\":"+candidates+"}]}").utf8)
  }
  let good="[{\"shader_ordinal\":1,\"shader_name\":\"ball\",\"passes\":[{\"stages\":[{\"textures\":[{\"path\":\"textures/ball.tga\",\"exists\":true}]}]}]}]"
  let parsed=try CMMaterialCandidates(data:manifest("name_match_candidate",good))
  precondition(parsed.previewTexture(modelName:"ball.ucm")=="textures/ball.tga")
  precondition(parsed.previewTexture(modelName:"other.ucm")==nil)
  precondition(try CMMaterialCandidates(data:manifest("ambiguous",good)).previewTexture(modelName:"ball.ucm")==nil)
  precondition(try CMMaterialCandidates(data:manifest("name_match_candidate","[]")).previewTexture(modelName:"ball.ucm")==nil)
  let missing=good.replacingOccurrences(of:"\"exists\":true",with:"\"exists\":false")
  precondition(try CMMaterialCandidates(data:manifest("name_match_candidate",missing)).previewTexture(modelName:"ball.ucm")==nil)
  let traversal=good.replacingOccurrences(of:"textures/ball.tga",with:"../secret.tga")
  precondition(try CMMaterialCandidates(data:manifest("name_match_candidate",traversal)).previewTexture(modelName:"ball.ucm")==nil)
  print("Material candidate preview selection checks passed")
 }
}
