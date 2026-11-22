import Foundation

@main
struct OriginalElementsTemplateCatalogSmoke {
    struct Scene: Decodable { let root: Node }
    struct Node: Decodable { let name: String; let children: [Node] }
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            fatalError("Usage: templates-smoke decrypted-elements.fsc level-json-directory")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let catalogue = try CMOriginalElementsTemplateCatalog.parse(decodedBytes: data)
        precondition(catalogue.count == 157, "Original script must expose 157 distinct tmo templates")
        precondition(catalogue["tmo_bucket"]?.defaultBits == 104)
        precondition(catalogue["tmo_bucket"]?.defaultFloat == 0.125)
        precondition(catalogue["tmo_magnetic_permanent"]?.defaultBits == 64)
        precondition(catalogue["tmo_ball_tennis"]?.defaultBits == 72)
        precondition(catalogue["tmo_bucket"]?.modelReferences.contains("to_bucket") == true)
        let directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        var types = Set<String>()
        var count = 0
        func visit(_ node: Node) {
            if node.name.hasPrefix("tmo_") { types.insert(node.name); count += 1 }
            for child in node.children { visit(child) }
        }
        for index in 1...102 {
            let url = directory.appendingPathComponent(String(format:"level-%03d.json",index))
            let scene = try JSONDecoder().decode(Scene.self, from: Data(contentsOf: url))
            visit(scene.root)
        }
        precondition(count == 5313, "Must traverse every original imported PC object")
        let missing = types.subtracting(catalogue.keys)
        precondition(missing.isEmpty, "Unmapped real script templates: \(missing.sorted())")
        precondition(types.count == 122)
        print("PASS: Native Swift decoded original elements.fsc: \(catalogue.count) real templates")
        print("PASS: \(types.count) / \(types.count) original PC element types covered across all 102 scenes")
        print("PASS: \(count) original objects; authentic bucket, magnet, and tennis ball defaults")
        let altered = Data("no original script here".utf8)
        do {
            _ = try CMOriginalElementsTemplateCatalog.parse(decodedBytes: altered)
            fatalError("Unmarked arbitrary data must not be accepted")
        } catch CMOriginalElementsTemplateCatalog.ParseError.missingScriptHeader {}
    }
}