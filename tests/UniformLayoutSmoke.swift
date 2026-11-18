import Foundation

// Portable ABI regression: matches CMUniforms in CMShaders.metal.
// Metal float4x4 is 64 bytes and float4 is 16 bytes.
struct CMTestMatrix {
 var c0:SIMD4<Float>
 var c1:SIMD4<Float>
 var c2:SIMD4<Float>
 var c3:SIMD4<Float>
}
struct CMTestUniforms {
 var modelViewProjection:CMTestMatrix
 var model:CMTestMatrix
 var lightDirectionAmbient:SIMD4<Float>
}
@main struct CMUniformLayoutSmoke {
 static func main() {
  precondition(MemoryLayout<CMTestMatrix>.stride==64)
  precondition(MemoryLayout<CMTestUniforms>.stride==144)
  precondition(MemoryLayout<CMTestUniforms>.alignment==16)
  print("Metal uniform ABI expected: 64+64+16=144 bytes")
 }
}
