import Foundation

// Standalone: swiftc ios/CMUCMModel.swift ios/CMPreviewFixture.swift tests/PreviewFixtureSmoke.swift -o /tmp/preview-smoke && /tmp/preview-smoke
@main
struct PreviewFixtureSmoke {
 static func main() throws {
  let model=try CMPreviewFixture.makeModel()
  precondition(model.vertexCount == 24)
  precondition(model.triangleCount == 12)
  precondition(model.indices.count == 36 && model.indices.allSatisfy { $0 < 24 })
  precondition(model.vertexData.count == 768)
  let second=try CMPreviewFixture.makeModel()
  precondition(model.vertexData == second.vertexData)
  print("Preview fixture OK: 24 vertices, 12 triangles, deterministic bytes")
 }
}
