import Foundation

@main struct MaterialCandidatesSmoke {
 static func main() throws {
  func manifest(_ entries:String)->Data {
   Data(("{\"schema\":\"cm-candidate-bindings-v1\",\"models\":[" + entries + "]}").utf8)
  }
  func model(_ name:String,_ status:String,_ passes:String)->String {
   "{\"model\":\""+name+"\",\"status\":\""+status+"\",\"candidates\":[{\"shader_ordinal\":0,\"shader_name\":\"test\",\"passes\":"+passes+"}]}"
  }
  let stage="{\"stages\":[{\"textures\":[{\"path\":\"textures/metal.tga\",\"exists\":true}]}]}"
  let one=model("models/metal.ucm","name_match_candidate","["+stage+"]")
  let good=try CMMaterialCandidates(data:manifest(one))
  precondition(good.previewTexture(modelName:"metal.ucm")=="textures/metal.tga")
  precondition(good.previewTexture(modelName:"METAL.UCM")=="textures/metal.tga")
  precondition(good.previewTexture(modelName:"other.ucm")==nil)
  let unresolved=try CMMaterialCandidates(data:manifest(model("a.ucm","unresolved","["+stage+"]")))
  precondition(unresolved.previewTexture(modelName:"a.ucm")==nil)
  let multi=try CMMaterialCandidates(data:manifest(model("a.ucm","name_match_candidate","["+stage+","+stage+"]")))
  precondition(multi.previewTexture(modelName:"a.ucm")==nil)
  let missing=model("a.ucm","name_match_candidate","[{\"stages\":[{\"textures\":[{\"path\":\"textures/a.tga\",\"exists\":false}]}]}]")
  precondition(try CMMaterialCandidates(data:manifest(missing)).previewTexture(modelName:"a.ucm")==nil)
  let unsafe=model("a.ucm","name_match_candidate","[{\"stages\":[{\"textures\":[{\"path\":\"../escape.tga\",\"exists\":true}]}]}]")
  precondition(try CMMaterialCandidates(data:manifest(unsafe)).previewTexture(modelName:"a.ucm")==nil)
  print("Material selection smoke tests passed")
 }
}
