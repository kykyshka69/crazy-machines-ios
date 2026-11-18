import Foundation

/// 125 deterministic image patterns × 2 pixel depths × 4 origins = 1000 cases.
/// Uses generated pixels only; no copyrighted game assets.
@main
struct TGAThousandSmoke {
 static func main() throws {
  var passed = 0
  for variant in 0..<125 {
   let w = 1 + (variant % 17)
   let h = 1 + ((variant * 7) % 19)
   for depth in [24, 32] {
    for top in [false, true] {
     for right in [false, true] {
      var header = [UInt8](repeating: 0, count: 18)
      header[2] = 2; header[12] = UInt8(w); header[14] = UInt8(h)
      header[16] = UInt8(depth)
      header[17] = (top ? 0x20 : 0) | (right ? 0x10 : 0)
      var expected: [UInt8] = []
      for y in 0..<h {
       for x in 0..<w {
        expected += [UInt8((x*19+y*7+variant)%256), UInt8((x*3+y*31+variant)%256), UInt8((x*47+y*11+variant)%256), depth == 32 ? UInt8((x*13+y*17+variant)%256) : 255]
       }
      }
      var payload: [UInt8] = []
      for sy in 0..<h {
       for sx in 0..<w {
        let x = right ? w-1-sx : sx
        let y = top ? sy : h-1-sy
        let i = (y*w+x)*4
        payload += [expected[i+2], expected[i+1], expected[i]]
        if depth == 32 { payload.append(expected[i+3]) }
       }
      }
      let result = try CMTGATexture(data: Data(header + payload))
      precondition(result.width == w && result.height == h)
      precondition([UInt8](result.rgba) == expected, "Mismatch case \(passed)")
      passed += 1
     }
    }
   }
  }
  precondition(passed == 1000)
  print("PASS: \(passed) deterministic TGA decoder cases")
 }
}
