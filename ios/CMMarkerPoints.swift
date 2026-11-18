import Foundation
import simd
/// Debug-only translation candidates; coordinate convention remains unverified.
public enum CMMarkerPoints {
 public static func positions(_ slots:[CMAttachmentCatalog.Attachment])->[SIMD3<Float>] {
  slots.compactMap { item in
   guard item.translation_candidate.count==3 else { return nil }
   let t=item.translation_candidate
   guard t.allSatisfy(\.isFinite) else { return nil }
   return SIMD3<Float>(t[0],t[1],t[2])
  }
 }
}
