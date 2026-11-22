import Foundation

@main
struct Original102WindowsElementRulesSmoke {
    struct Scene: Decodable { let root: Node }
    struct Node: Decodable {
        let name: String
        let fields: [String]
        let children: [Node]
    }
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            fatalError("Usage: rules-smoke decoded-elements.fsc original-scenes-dir")
        }
        let script = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let catalogue = try CMOriginalElementsTemplateCatalog.parse(decodedBytes: script)
        let folder = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
        var objects = 0, overrides = 0, inherited = 0, explicitMovable = 0
        func visit(_ node: Node) {
            if node.name.hasPrefix("tmo_") {
                guard let rule = CMOriginalWindowsElementRules(
                    type: node.name, sceneFields: node.fields,
                    catalogue: catalogue
                ) else { fatalError("Missing original template: \(node.name)") }
                objects += 1
                if rule.hasOriginalFlagOverride { overrides += 1 }
                if rule.cameFromTemplateBits { inherited += 1 }
                if rule.hasMovableBit == true { explicitMovable += 1 }
                if node.name == "tmo_bucket" && node.fields.contains("GOAL 1") {
                    precondition(rule.goalMarker == "1")
                }
            }
            node.children.forEach(visit)
        }
        for index in 1...102 {
            let file = folder.appendingPathComponent(
                String(format: "level-%03d.json", index))
            visit(try JSONDecoder().decode(Scene.self, from: Data(contentsOf: file)).root)
        }
        precondition(objects == 5313)
        precondition(overrides == 37,
                     "Do not erase real per-scene Windows bit-mask overrides")
        precondition(inherited == 6,
                     "Windows template defaults restore six scene-omitted flags")
        precondition(explicitMovable > 200)
        precondition(CMOriginalWindowsElementRules(
            type: "tmo_unknown", sceneFields: [], catalogue: catalogue) == nil)
        // PC puzzle 2 explicitly makes a domino dynamic even though its
        // generic elements.fsc type template has movable bit 8 only.
        let domino = CMOriginalWindowsElementRules(
            type: "tmo_domino", sceneFields: ["VALB 72", "UNLOCKED 1"],
            catalogue: catalogue)!
        precondition(domino.effectiveBits == 72 && domino.hasOriginalFlagOverride)
        precondition(domino.isEditable)
        let baseline = CMOriginalWindowsElementRules(
            type: "tmo_domino", sceneFields: [], catalogue: catalogue)!
        precondition(baseline.effectiveBits == 8 && baseline.cameFromTemplateBits)
        let test = CMOriginalWindowsElementRules(
            type: "tmo_bucket", sceneFields: ["VALB 64", "GOAL 1"],
            catalogue: catalogue)!
        precondition(test.effectiveBits == 64 && test.goalMarker == "1")
        print("PASS: all 102 original levels, \(objects) original objects merged")
        print("PASS: \(overrides) authentic scenario overrides, \(inherited) original defaults restored")
        print("PASS: \(explicitMovable) explicit movable-bit objects; no invented scene roles")
    }
}