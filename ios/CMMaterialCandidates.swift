import Foundation

/// Conservative preview-only material selection. Never asserts original submesh bindings.
public struct CMMaterialCandidates: Decodable {
 public struct Texture: Decodable { public let path:String; public let exists:Bool }
 public struct Stage: Decodable { public let textures:[Texture] }
 public struct Pass: Decodable { public let stages:[Stage] }
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
 public func previewTexture(modelName:String)->String? {
  let name=modelName.lowercased()
  let matches=models.filter {
   let path=$0.model.lowercased()
   return path==name || path.hasSuffix("/"+name)
  }
  guard matches.count==1,let entry=matches.first,
        entry.status=="name_match_candidate",entry.candidates.count==1 else { return nil }
  let candidate=entry.candidates[0]
  guard candidate.passes.count==1,
        candidate.passes[0].stages.count==1 else { return nil }
  let textures=candidate.passes[0].stages[0].textures
  guard textures.count==1,textures[0].exists else { return nil }
  let path=textures[0].path
  guard !path.isEmpty,!path.hasPrefix("/"),!path.contains(".."),
        path.lowercased().hasSuffix(".tga") else { return nil }
  return path
 }
}
