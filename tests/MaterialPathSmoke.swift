import Foundation

@main
struct MaterialPathSmoke {
 static func entry(_ name:String,_ texture:String)->[String:Any] {
  ["model":name,"status":"name_match_candidate","candidates":[
   ["shader_ordinal":0,"shader_name":"test","passes":[
    ["stages":[["textures":[["path":texture,"exists":true]]]]]
   ]]
  ]]
 }
 static func catalog(_ entries:[[String:Any]]) throws -> CMMaterialCandidates {
  let data=try JSONSerialization.data(withJSONObject:[
   "schema":"cm-candidate-bindings-v1","models":entries
  ])
  return try CMMaterialCandidates(data:data)
 }
 static func main() throws {
  let a=try catalog([entry("data\\models\\ball.ucm","textures/ball.tga")])
  precondition(a.previewTexture(modelName:"ball.ucm")=="textures/ball.tga")
  precondition(a.previewTexture(modelName:"data/models/ball.ucm")=="textures/ball.tga")
  precondition(a.previewTexture(modelName:"DATA\\MODELS\\BALL.UCM")=="textures/ball.tga")
  let ambiguous=try catalog([
   entry("data/models/ball.ucm","textures/a.tga"),
   entry("extras/models/ball.ucm","textures/b.tga")
  ])
  precondition(ambiguous.previewTexture(modelName:"ball.ucm")==nil)
  precondition(ambiguous.previewTexture(modelName:"data/models/ball.ucm")=="textures/a.tga")
  precondition(ambiguous.previewTexture(modelName:"extras/models/ball.ucm")=="textures/b.tga")
  print("PASS: original path normalization and ambiguity checks")
 }
}
