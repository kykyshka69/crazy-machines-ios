import Foundation

@main
enum OriginalModelResolverSmoke {
    static func main() throws {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: folder) }

        // The scene exporter places all owned 3DO names in the tmo_
        // models array, including those below nested POSREL helpers.
        // Renderer must NOT load them a second time at the tmo_ origin.
        let fixture = """
        {
          "schema":"crazy-machines-original-scene-v1",
          "index":1,"title":"Model ownership",
          "scene_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "root":{"name":"level","fields":[],"children":[
            {"name":"tmo_machine","fields":[],"models":["to_motor","to_motor","to_extra","to_child"],
             "children":[
               {"name":"helper","fields":["POSREL 1, 2, 3"],"children":[
                 {"name":"3DO to_motor","fields":[],"children":[]}
               ]},
               {"name":"tmo_attachment","fields":[],"models":["to_child"],
                "children":[{"name":"3DO to_child","fields":[],"children":[]}]}
             ]}
          ]}
        }
        """
        let document = try CMOriginalSceneDocument.read(Data(fixture.utf8))
        let owner = document.root.children[0]
        let nested = owner.children[1]
        precondition(CMOriginalModelResolver.fallbackModelNames(in: owner) == ["to_extra", "to_child"])
        // 'to_child' is only in the parent models array here as an explicit
        // fallback, but its nested tmo_ is an independent owner. A real PC
        // exporter should never list child-owned models in its parent's list.
        precondition(CMOriginalModelResolver.fallbackModelNames(in: nested).isEmpty)
        precondition(CMOriginalModelResolver.modelNames(in: owner).contains("to_motor"))
        let noDuplicates = """
        {
          "schema":"crazy-machines-original-scene-v1",
          "index":1,"title":"No duplicate mesh",
          "scene_sha256":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
          "root":{"name":"level","fields":[],"children":[
            {"name":"tmo_machine","fields":[],"models":["to_motor","to_extra"],
             "children":[
               {"name":"helper","fields":["POSREL 1, 2, 3"],"children":[
                 {"name":"3DO to_motor","fields":[],"children":[]}
               ]}
             ]}
          ]}
        }
        """
        let nestedScene = try CMOriginalSceneDocument.read(Data(noDuplicates.utf8))
        precondition(CMOriginalModelResolver.fallbackModelNames(in: nestedScene.root.children[0]) == ["to_extra"])
        precondition(CMOriginalModelResolver.fallbackModelNames(in: nestedScene.root).isEmpty)

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

        for invalid in ["folder/../to_board", "folder//to_board", "folder/./to_board", "folder\nto_board", "folder\0to_board"] {
            guard case .invalidReference = index.resolution(for: invalid) else {
                preconditionFailure("Invalid PC model parent path was accepted")
            }
        }

        guard case .found(let withExtension) = index.resolution(for: "models\\to_board.ucm") else {
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
