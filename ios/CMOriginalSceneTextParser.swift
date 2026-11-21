import Foundation

/// Rebuild the same read-only original scene tree as the PC-side exporter.
/// This parser does not infer game physics, goals, or electrical wiring.
public enum CMOriginalSceneTextParser {
    public enum ParseError: Error, Equatable { case malformed }

    private final class Node {
        let name: String
        var fields: [String] = []
        var children: [Node] = []
        init(_ name: String) { self.name = name }

        func field(_ name: String) -> String? {
            let prefix = name + " "
            for line in fields {
                if line == name { return "" }
                if line.hasPrefix(prefix) { return String(line.dropFirst(prefix.count)) }
            }
            return nil
        }
    }

    private static func vector(_ text: String) throws -> [Double] {
        let segments = text.split(separator: ",", omittingEmptySubsequences: false)
        guard segments.count == 3 else { throw ParseError.malformed }
        var values: [Double] = []
        for item in segments {
            guard let value = Double(item.trimmingCharacters(in: .whitespaces)),
                  value.isFinite, abs(value) <= Double(Float.greatestFiniteMagnitude) else {
                throw ParseError.malformed
            }
            values.append(value)
        }
        return values
    }

    /// Return a validated original scene JSON document; hash is the SHA-256
    /// of the original CP1251 scene bytes, not the CML container or UTF-8 text.
    public static func export(_ scene: String, index: Int, title: String,
                              sceneSHA256: String) throws -> Data {
        guard scene.utf8.count <= 8_000_000 else { throw ParseError.malformed }
        var root: Node?
        var stack: [Node] = []
        var pending: String?
        var totalNodes = 0
        for raw in scene.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line == "{" {
                guard let name = pending, !name.isEmpty,
                      totalNodes < 20_000, stack.count <= 64 else {
                    throw ParseError.malformed
                }
                let child = Node(name)
                totalNodes += 1
                if let parent = stack.last {
                    guard parent.children.count < 2048 else { throw ParseError.malformed }
                    parent.children.append(child)
                } else {
                    guard root == nil else { throw ParseError.malformed }
                    root = child
                }
                stack.append(child)
                pending = nil
            } else if line == "}" {
                if let field = pending {
                    guard let owner = stack.last, owner.fields.count < 256 else {
                        throw ParseError.malformed
                    }
                    owner.fields.append(field)
                    pending = nil
                }
                guard !stack.isEmpty else { throw ParseError.malformed }
                stack.removeLast()
            } else {
                if let field = pending {
                    guard let owner = stack.last, owner.fields.count < 256 else {
                        throw ParseError.malformed
                    }
                    owner.fields.append(field)
                }
                pending = line
            }
        }
        guard stack.isEmpty, pending == nil, let root, root.name == "level" else {
            throw ParseError.malformed
        }

        func ownModels(_ node: Node) -> [String] {
            var names: [String] = []
            func visit(_ current: Node) {
                for child in current.children {
                    if child.name.hasPrefix("tmo_") { continue }
                    if child.name.hasPrefix("3DO ") {
                        names.append(String(child.name.dropFirst(4)))
                    }
                    visit(child)
                }
            }
            visit(node)
            return names
        }

        func serialize(_ node: Node) throws -> [String: Any] {
            var result: [String: Any] = [
                "name": node.name,
                "fields": node.fields,
                "children": try node.children.map { try serialize($0) }
            ]
            if let value = node.field("POS") { result["position"] = try vector(value) }
            if let value = node.field("POSREL") { result["position_relative"] = try vector(value) }
            if let value = node.field("ROT") { result["rotation_raw"] = value }
            if let value = node.field("ROTREL") { result["rotation_relative_raw"] = value }
            if node.name.hasPrefix("tmo_") {
                result["models"] = ownModels(node)
                if let value = node.field("GOAL") { result["goal_raw"] = value }
            }
            return result
        }
        let document: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": index, "title": title, "scene_sha256": sceneSHA256,
            "root": try serialize(root)
        ]
        guard JSONSerialization.isValidJSONObject(document) else { throw ParseError.malformed }
        let json = try JSONSerialization.data(withJSONObject: document)
        _ = try CMOriginalSceneDocument.read(json)
        return json
    }
}
