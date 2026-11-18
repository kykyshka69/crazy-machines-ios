import Foundation

/// Original, synthetic triangle for first-launch rendering when game assets are absent.
public enum CMPreviewFixture {
 public static func makeModel() throws -> CMUCMModel {
  var data=Data(repeating:0,count:92+12+3*32)
  func put32(_ offset:Int,_ value:UInt32) {
   for i in 0..<4 { data[offset+i]=UInt8(truncatingIfNeeded:value >> (i*8)) }
  }
  for (i,byte) in [UInt8(85),67,77,49].enumerated() { data[i]=byte }
  put32(4,1)
  put32(72,1)
  put32(76,1)
  put32(80,3)
  for i in 0..<3 { put32(92+i*4,UInt32(i)) }
  let positions:[(Float,Float,Float)]=[(-1,-0.8,0),(1,-0.8,0),(0,1,0)]
  for (i,p) in positions.enumerated() {
   let base=104+i*32
   let attributes:[Float]=[p.0,p.1,p.2,0,0,1,0,0]
   for (j,value) in attributes.enumerated() {
    put32(base+j*4,value.bitPattern)
   }
  }
  return try CMUCMModel(data:data)
 }
}
