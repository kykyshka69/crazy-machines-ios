import Foundation

// Standalone: swiftc ios/CMUCMModel.swift ios/CMPreviewFixture.swift tests/PreviewFixtureSmoke.swift -o /tmp/preview-smoke && /tmp/preview-smoke
@main
struct PreviewFixtureSmoke {
 static func main() throws {
  let model=try CMPreviewFixture.makeModel()
  precondition(model.vertexCount == 3)
  precondition(model.triangleCount == 1)
  precondition(model.indices == [0,1,2])
  precondition(model.vertexData.count == 96)
  let second=try CMPreviewFixture.makeModel()
  precondition(model.vertexData == second.vertexData)
  print("Preview fixture OK: 3 vertices, 1 triangle, deterministic bytes")
 }
}
