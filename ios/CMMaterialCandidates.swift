import Foundation

/// Conservative preview-only material selection. Never asserts original submesh bindings.
public struct CMMaterialCandidates: Decodable {
 public struct Texture: Decodable { public let path:String; public let exists:Bool }
 public struct Stage: Decodable {
  public let textures:[Texture]
  public let states:[String:[[String]]]?
 }
 public struct Pass: Decodable {
  public let stages:[Stage]
  public let states:[String:[[String]]]?
 }
 public struct Candidate: Decodable {
  public let shader_ordinal:Int
  public let shader_name:String
  public let passes:[Pass]
 }
 public struct Model: Decodable {
  public let model:String
  public let status:String
  public let candidates:[Candidate]
 }
 public let schema:String
 public let models:[Model]
 public enum SelectionError:Error { case invalidSchema,duplicateModel }
 public init(data:Data) throws {
  self=try JSONDecoder().decode(Self.self,from:data)
  guard schema=="cm-candidate-bindings-v1" else { throw SelectionError.invalidSchema }
  let names=models.map { $0.model.lowercased() }
  guard Set(names).count==names.count else { throw SelectionError.duplicateModel }
 }
 /// Returns nil unless a model has exactly one filename-matched shader and one existing texture.
 /// Multiple passes/stages/textures cannot safely be flattened into one Metal texture.
 private func matchingModel(_ modelName:String)->Model? {
  // Original resource paths may contain Windows separators. Match exact paths
  // first, then a unique basename only; never choose an ambiguous basename.
  func canonical(_ path:String)->String {
   path.replacingOccurrences(of:"\\\\",with:"/").lowercased()
  }
  let query=canonical(modelName)
  let exact=models.filter { canonical($0.model)==query }
  if exact.count==1 { return exact[0] }
  if !exact.isEmpty { return nil }
  let basename=query.split(separator:"/").last.map(String.init) ?? query
  let matches=models.filter {
   canonical($0.model).split(separator:"/").last.map(String.init)==basename
  }
  return matches.count==1 ? matches[0] : nil
 }
 public enum PreviewBlend: String { case opaque, additive, alpha, multiply }
 /// The blend setting is used only for a uniquely identified one-pass preview.
 /// Missing or unrecognized original states are deliberately left unresolved.
 public func previewBlend(modelName:String)->PreviewBlend? {
  guard let entry=matchingModel(modelName),
        entry.status=="name_match_candidate",entry.candidates.count==1,
        entry.candidates[0].passes.count==1 else { return nil }
  let state=entry.candidates[0].passes[0].states?["blend"]
  guard let state, state.count==1 else { return nil }
  let tokens=state[0].map { $0.lowercased() }
  switch tokens {
  case ["one","one"]: return .additive
  case ["srcalpha","invsrcalpha"]: return .alpha
  case ["zero","srccolor"]: return .multiply
  default: return nil
  }
 }
 public enum TextureAddress:String { case wrap, clamp, mirror }
 public struct TextureAddressPair:Equatable {
  public let u:TextureAddress
  public let v:TextureAddress
 }
 /// Returns nil for unknown or ambiguous shader stages. No address declaration
 /// means the engine default (wrap) is used for this preview.
 public func previewAddress(modelName:String)->TextureAddressPair? {
  guard let entry=matchingModel(modelName),
        entry.status=="name_match_candidate",entry.candidates.count==1,
        entry.candidates[0].passes.count==1,
        entry.candidates[0].passes[0].stages.count==1 else { return nil }
  let stage=entry.candidates[0].passes[0].stages[0]
  guard stage.textures.count==1,stage.textures[0].exists else { return nil }
  guard let values=stage.states?["address"] else {
   return TextureAddressPair(u:.wrap,v:.wrap)
  }
  guard values.count==1,values[0].count==2,
        let u=TextureAddress(rawValue:values[0][0].lowercased()),
        let v=TextureAddress(rawValue:values[0][1].lowercased()) else { return nil }
  return TextureAddressPair(u:u,v:v)
 }
 public func previewTexture(modelName:String)->String? {
  guard let entry=matchingModel(modelName),
        entry.status=="name_match_candidate",entry.candidates.count==1 else { return nil }
  let candidate=entry.candidates[0]
  guard candidate.passes.count==1,
        candidate.passes[0].stages.count==1 else { return nil }
  let textures=candidate.passes[0].stages[0].textures
  guard textures.count==1,textures[0].exists else { return nil }
  let path=textures[0].path
  let normalized=path.replacingOccurrences(of:"\\",with:"/")
  let components=normalized.split(separator:"/",omittingEmptySubsequences:false)
  guard !normalized.isEmpty,!normalized.hasPrefix("/"),
        components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
        !normalized.contains(":"),
        normalized.lowercased().hasSuffix(".tga") else { return nil }
  return normalized
 }
}
