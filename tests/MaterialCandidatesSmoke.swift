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
  let missingCatalog=try CMMaterialCandidates(data:manifest(missing))
  precondition(missingCatalog.previewTexture(modelName:"a.ucm")==nil)
  let unsafe=model("a.ucm","name_match_candidate","[{\"stages\":[{\"textures\":[{\"path\":\"../escape.tga\",\"exists\":true}]}]}]")
  let unsafeCatalog=try CMMaterialCandidates(data:manifest(unsafe))
  precondition(unsafeCatalog.previewTexture(modelName:"a.ucm")==nil)
  let windows=model("a.ucm","name_match_candidate","[{\"stages\":[{\"textures\":[{\"path\":\"textures\\\\\\\\metal.tga\",\"exists\":true}]}]}]")
  let windowsCatalog=try CMMaterialCandidates(data:manifest(windows))
  precondition(windowsCatalog.previewTexture(modelName:"a.ucm")=="textures/metal.tga")
  let badAddress=model("a.ucm","name_match_candidate","[{\"stages\":[{\"states\":{\"address\":[[\"invalid\",\"clamp\"]]},\"textures\":[{\"path\":\"a.tga\",\"exists\":true}]}]}]")
  let badAddressCatalog=try CMMaterialCandidates(data:manifest(badAddress))
  precondition(badAddressCatalog.previewAddress(modelName:"a.ucm")==nil)
  let additiveCatalog=try CMMaterialCandidates(data:manifest(model("a.ucm","name_match_candidate","[{\"states\":{\"blend\":[[\"one\",\"one\"]]},\"stages\":[{\"states\":{\"address\":[[\"mirror\",\"clamp\"]]},\"textures\":[{\"path\":\"textures/metal.tga\",\"exists\":true}]}]}]")))
  precondition(additiveCatalog.previewBlend(modelName:"a.ucm")== .additive)
  precondition(additiveCatalog.previewAddress(modelName:"a.ucm")==CMMaterialCandidates.TextureAddressPair(u:.mirror,v:.clamp))
  let alphaCatalog=try CMMaterialCandidates(data:manifest(model("a.ucm","name_match_candidate","[{\"states\":{\"blend\":[[\"srcalpha\",\"invsrcalpha\"]]},\"stages\":[{\"states\":{\"address\":[[\"mirror\",\"clamp\"]]},\"textures\":[{\"path\":\"textures/metal.tga\",\"exists\":true}]}]}]")))
  precondition(alphaCatalog.previewBlend(modelName:"a.ucm")== .alpha)
  precondition(alphaCatalog.previewAddress(modelName:"a.ucm")==CMMaterialCandidates.TextureAddressPair(u:.mirror,v:.clamp))
  let multiplyCatalog=try CMMaterialCandidates(data:manifest(model("a.ucm","name_match_candidate","[{\"states\":{\"blend\":[[\"zero\",\"srccolor\"]]},\"stages\":[{\"states\":{\"address\":[[\"mirror\",\"clamp\"]]},\"textures\":[{\"path\":\"textures/metal.tga\",\"exists\":true}]}]}]")))
  precondition(multiplyCatalog.previewBlend(modelName:"a.ucm")== .multiply)
  precondition(multiplyCatalog.previewAddress(modelName:"a.ucm")==CMMaterialCandidates.TextureAddressPair(u:.mirror,v:.clamp))
  print("Material selection smoke tests passed")
 }
}
