import Foundation

/// Debug-only attachment projection. UCM matrix convention is not yet confirmed.
public enum CMAttachmentProjection {
 public struct Point: Equatable {
  public let x:Float,y:Float,z:Float
  public init(_ x:Float,_ y:Float,_ z:Float){self.x=x;self.y=y;self.z=z}
 }
 public enum ProjectionError:Error { case invalidMatrix,invalidViewport,behindCamera }
 public static func localOrigin(_ rows:[[Float]]) throws -> Point {
  guard rows.count==4,rows.allSatisfy({$0.count==4 && $0.allSatisfy(\.isFinite)}),
   abs(rows[3][3]-1)<0.0001 else {throw ProjectionError.invalidMatrix}
  return Point(rows[3][0],rows[3][1],rows[3][2])
 }
 public static func screenPoint(_ p:Point,aspect:Float,verticalFOV:Float = .pi/3) throws -> Point {
  guard aspect>0,aspect.isFinite,verticalFOV>0,verticalFOV < .pi else {throw ProjectionError.invalidViewport}
  guard p.z < -0.001 else {throw ProjectionError.behindCamera}
  let scale:Float=1/tan(verticalFOV/2)
  return Point(0.5+(p.x*scale/aspect / -p.z)*0.5,0.5-(p.y*scale / -p.z)*0.5,-p.z)
 }
}
