import Foundation

/// Original UCM named transform candidates. Matrix orientation and gameplay semantics remain unverified.
public struct CMAttachmentCatalog: Decodable {
 public struct Summary: Decodable {
  public let models:Int
  public let named_slots:Int
  public let matrix_bindings:Int
  public let unique_names:Int
 }
 public struct Attachment: Decodable {
  public let model:String
  public let group:Int
  public let slot:Int
  public let name:String
  public let matrix_index:Int
  public let matrix_row_major:[[Float]]
  public let translation_candidate:[Float]
 }
 public let summary:Summary
 public let attachments:[Attachment]
 public enum CatalogError:Error { case invalidCount,invalidMatrix }
 public init(data:Data) throws {
  self=try JSONDecoder().decode(Self.self,from:data)
  guard attachments.count==summary.matrix_bindings else { throw CatalogError.invalidCount }
  for item in attachments {
   guard item.group>=0,item.slot>=0,item.matrix_index>=0,
    item.matrix_row_major.count==4,
    item.matrix_row_major.allSatisfy({ $0.count==4 && $0.allSatisfy(\.isFinite) }),
    item.translation_candidate.count==3,item.translation_candidate.allSatisfy(\.isFinite),
    zip(item.matrix_row_major[3].prefix(3),item.translation_candidate).allSatisfy({ pair in abs(pair.0-pair.1)<0.00001 })
   else { throw CatalogError.invalidMatrix }
  }
 }
 public func slots(model:String,group:Int?=nil)->[Attachment] {
  attachments.filter { $0.model.caseInsensitiveCompare(model) == .orderedSame && (group == nil || $0.group == group!) }
 }
}
