import Foundation

/// Original, synthetic 3D cube for first-launch rendering without game assets.
public enum CMPreviewFixture {
 public static func makeModel() throws -> CMUCMModel {
  let vertices:[SIMD3<Float>]=[
   SIMD3(-1,-1,-1),SIMD3(1,-1,-1),SIMD3(1,1,-1),SIMD3(-1,1,-1),
   SIMD3(-1,-1,1),SIMD3(1,-1,1),SIMD3(1,1,1),SIMD3(-1,1,1)
  ]
  let triangles:[UInt32]=[
   0,2,1, 0,3,2, 4,5,6, 4,6,7,
   0,1,5, 0,5,4, 3,7,6, 3,6,2,
   0,4,7, 0,7,3, 1,2,6, 1,6,5
  ]
  var data=Data(repeating:0,count:92+triangles.count*4+vertices.count*32)
  func put32(_ offset:Int,_ value:UInt32) {
   for i in 0..<4 { data[offset+i]=UInt8(truncatingIfNeeded:value >> (i*8)) }
  }
  for (i,byte) in [UInt8(85),67,77,49].enumerated() { data[i]=byte }
  put32(4,1)
  put32(72,1)
  put32(76,UInt32(triangles.count/3))
  put32(80,UInt32(vertices.count))
  for (i,index) in triangles.enumerated() { put32(92+i*4,index) }
  let vertexStart=92+triangles.count*4
  for (i,p) in vertices.enumerated() {
   let base=vertexStart+i*32
   let attributes:[Float]=[p.x,p.y,p.z,0,0,1,(p.x+1)/2,(p.y+1)/2]
   for (j,value) in attributes.enumerated() { put32(base+j*4,value.bitPattern) }
  }
  return try CMUCMModel(data:data)
 }
}
