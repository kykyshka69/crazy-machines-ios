import Foundation

@main
enum OriginalModelResolverSmoke {
    static func main() throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: folder) }

        let mesh = folder.appendingPathComponent("to_board.ucm")
        try Data([1]).write(to: mesh)
        var index = CMOriginalModelResolver.AssetIndex(directory: folder)
        guard case .found(let found) = index.resolution(for: "to_board") else {
            preconditionFailure("Exact PC model was not resolved")
        }
        precondition(found == mesh)
        guard case .missing = index.resolution(for: "missing") else {
            preconditionFailure("Missing mesh should be reported")
        }
        for invalid in ["../to_board", "/to_board", "C:\\to_board", "to_board.obj", "to_board\n"] {
            guard case .invalidReference = index.resolution(for: invalid) else {
                preconditionFailure("Unsafe original model reference was accepted")
            }
        }

        for invalid in ["folder/../to_board", "folder//to_board", "folder/./to_board", "folder\\nto_board", "folder\\0to_board"] {
            guard case .invalidReference = index.resolution(for: invalid) else {
                preconditionFailure("Invalid PC model parent path was accepted")
            }
        }

        guard case .found(let withExtension) = index.resolution(for: "models\\\\to_board.ucm") else {
            preconditionFailure("Safe Windows-relative model paths should resolve")
        }
        precondition(withExtension == mesh)
        guard case .missing = index.resolution(for: "board") else {
            preconditionFailure("Unprefixed names must not silently alias to to_ models")
        }

        let aliasMesh = folder.appendingPathComponent("wheel.ucm")
        try Data([3]).write(to: aliasMesh)
        index = CMOriginalModelResolver.AssetIndex(directory: folder)
        guard case .found(let alias) = index.resolution(for: "to_wheel") else {
            preconditionFailure("Original to_ prefix fallback should resolve when unique")
        }
        precondition(alias == aliasMesh)

        let duplicate = folder.appendingPathComponent("TO_BOARD.UCM")
        try Data([2]).write(to: duplicate)
        index = CMOriginalModelResolver.AssetIndex(directory: folder)
        guard case .ambiguous = index.resolution(for: "to_board") else {
            preconditionFailure("Case-insensitive collision must be ambiguous")
        }
        precondition(index.resolve("to_board") == nil)
        // A direct filename collision must never fall back to a different
        // alias, and an alias collision must not pick a random mesh.
        let aliasCollision = folder.appendingPathComponent("WHEEL.UCM")
        try Data([4]).write(to: aliasCollision)
        index = CMOriginalModelResolver.AssetIndex(directory: folder)
        guard case .ambiguous = index.resolution(for: "to_wheel") else {
            preconditionFailure("Duplicate to_ alias targets must remain ambiguous")
        }
        precondition(index.resolve("to_wheel") == nil)
        // An exact to_wheel file takes precedence over the ambiguous
        // unprefixed alias: explicit original references are authoritative.
        let exactWheel = folder.appendingPathComponent("to_wheel.ucm")
        try Data([5]).write(to: exactWheel)
        index = CMOriginalModelResolver.AssetIndex(directory: folder)
        guard case .found(let preferred) = index.resolution(for: "to_wheel") else {
            preconditionFailure("Exact original model must win over alias collisions")
        }
        precondition(preferred == exactWheel)
    }
}
