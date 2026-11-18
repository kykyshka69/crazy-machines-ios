import Foundation

/// 1000 deterministic malformed UCM cases against one generated valid fixture.
@main
struct UCMThousandSmoke {
 static func write32(_ data: inout Data, _ offset: Int, _ value: UInt32) {
  for i in 0..<4 { data[offset+i] = UInt8(truncatingIfNeeded: value >> (i*8)) }
 }
 static func main() throws {
  guard CommandLine.arguments.count == 2 else { fatalError("Expected fixture path") }
  let original = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
  let parsed = try CMUCMModel(data: original)
  precondition(parsed.vertexCount == 3 && parsed.triangleCount == 1)
  var rejected = 0
  for i in 0..<1000 {
   var corrupted = original
   switch i % 4 {
   case 0:
    // Every changed first index is outside the 3-vertex fixture.
    write32(&corrupted, 92, UInt32(3 + i))
   case 1:
    // Missing data, from one byte to nearly the entire payload.
    corrupted = Data(original.prefix(1 + (i % (original.count - 1))))
   case 2:
    // Invalid magic while keeping the rest of the payload intact.
    corrupted[i % 4] = 0
   default:
    // Unexpected extra trailing bytes must be rejected.
    corrupted.append(contentsOf: repeatElement(UInt8(i % 256), count: 1 + (i % 13)))
   }
   do {
    _ = try CMUCMModel(data: corrupted)
    fatalError("Accepted malformed UCM case \(i)")
   } catch is CMUCMError {
    rejected += 1
   }
  }
  precondition(rejected == 1000)
  print("PASS: \(rejected) malformed UCM cases rejected")
 }
}
