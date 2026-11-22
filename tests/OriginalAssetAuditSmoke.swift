import Foundation

@main
enum OriginalAssetAuditSmoke {
    private static func put32(_ data: inout Data, _ offset: Int, _ value: UInt32) {
        for byte in 0..<4 {
            data[offset + byte] = UInt8(truncatingIfNeeded: value >> (byte * 8))
        }
    }

    private static func validMesh() -> Data {
        // Minimal, independent UCM1 v2 triangle. No original game bytes.
        var data = Data(repeating: 0, count: 92 + 12 + 3 * 32 + 8)
        data.replaceSubrange(0..<4, with: [85, 67, 77, 49])
        put32(&data, 4, 2)
        put32(&data, 72, 1)
        put32(&data, 76, 1)
        put32(&data, 80, 3)
        put32(&data, 84, 0)
        put32(&data, 92, 0)
        put32(&data, 96, 1)
        put32(&data, 100, 2)
        return data
    }

    static func main() throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("cm-original-asset-audit-" + UUID().uuidString,
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        try validMesh().write(to: folder.appendingPathComponent("ball.ucm"))
        try Data([0, 1, 2]).write(to: folder.appendingPathComponent("broken.ucm"))
        let names = ["to_ball", "TO_BALL", "broken", "missing", "../unsafe",
                     "not-a-mesh.txt"]
        let report = CMOriginalAssetAudit.inspect(modelNames: names, directory: folder)
        precondition(report.entries.count == 5) // deduplicated case-insensitively
        precondition(report.readyCount == 1)
        precondition(!report.allReady)
        let byName = Dictionary(uniqueKeysWithValues:
            report.entries.map { ($0.reference, $0) })
        precondition(byName["to_ball"]?.status == .ready)
        precondition(byName["to_ball"]?.fileName == "ball.ucm") // original to_ alias
        precondition(byName["to_ball"]?.vertices == 3)
        precondition(byName["to_ball"]?.triangles == 1)
        precondition(byName["broken"]?.status == .invalidGeometry)
        precondition(byName["missing"]?.status == .missing)
        precondition(byName["../unsafe"]?.status == .invalidReference)
        precondition(byName["not-a-mesh.txt"]?.status == .invalidReference)
        let empty = CMOriginalAssetAudit.inspect(modelNames: [], directory: folder)
        precondition(empty.entries.isEmpty && !empty.allReady)
        let ready = CMOriginalAssetAudit.inspect(modelNames: ["to_ball"], directory: folder)
        precondition(ready.allReady)

        #if os(Linux)
        // Linux CI has a case-sensitive filesystem: two spellings of the
        // same basename must be rejected instead of picking one arbitrarily.
        try validMesh().write(to: folder.appendingPathComponent("Duplicate.ucm"))
        try validMesh().write(to: folder.appendingPathComponent("duplicate.UCM"))
        let conflict = CMOriginalAssetAudit.inspect(modelNames: ["duplicate"],
                                                    directory: folder)
        precondition(conflict.entries.count == 1)
        precondition(conflict.entries[0].status == .ambiguous)
        #endif
        print("PASS: original level UCM asset integrity and resolver diagnostics")
    }
}
