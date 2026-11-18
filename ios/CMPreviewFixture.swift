import Foundation

/// Original, synthetic 3D cube for first-launch rendering without game assets.
public enum CMPreviewFixture {
 public static func makeModel() throws -> CMUCMModel {
  // Four independent vertices per face preserve flat lighting normals.
  let faces:[(SIMD3<Float>,[SIMD3<Float>])]=[
   (SIMD3(0,0,1),[SIMD3(-1,-1,1),SIMD3(1,-1,1),SIMD3(1,1,1),SIMD3(-1,1,1)]),
   (SIMD3(0,0,-1),[SIMD3(1,-1,-1),SIMD3(-1,-1,-1),SIMD3(-1,1,-1),SIMD3(1,1,-1)]),
   (SIMD3(0,1,0),[SIMD3(-1,1,1),SIMD3(1,1,1),SIMD3(1,1,-1),SIMD3(-1,1,-1)]),
   (SIMD3(0,-1,0),[SIMD3(-1,-1,-1),SIMD3(1,-1,-1),SIMD3(1,-1,1),SIMD3(-1,-1,1)]),
   (SIMD3(1,0,0),[SIMD3(1,-1,1),SIMD3(1,-1,-1),SIMD3(1,1,-1),SIMD3(1,1,1)]),
   (SIMD3(-1,0,0),[SIMD3(-1,-1,-1),SIMD3(-1,-1,1),SIMD3(-1,1,1),SIMD3(-1,1,-1)])
  ]
  let vertices=faces.flatMap { $0.1 }
  let normals=faces.flatMap { face in Array(repeating:face.0,count:4) }
  let triangles:[UInt32]=(0..<6).flatMap { face -> [UInt32] in
   let i=UInt32(face*4)
   return [i,i+1,i+2,i,i+2,i+3]
  }
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
   let n=normals[i]
   // UVs are local to each face, avoiding collapsed texture coordinates
   // on the cube's top, bottom and side faces.
   let uv:[(Float,Float)]=[(0,0),(1,0),(1,1),(0,1)]
   let tex=uv[i % 4]
   let attributes:[Float]=[p.x,p.y,p.z,n.x,n.y,n.z,tex.0,tex.1]
   for (j,value) in attributes.enumerated() { put32(base+j*4,value.bitPattern) }
  }
  return try CMUCMModel(data:data)
 }
}
