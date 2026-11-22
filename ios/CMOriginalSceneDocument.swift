import Foundation

/// Read-only representation of a user-owned original Crazy Machines scene export.
/// This is intentionally separate from CMLevelDocument (the synthetic playground).
public struct CMOriginalSceneDocument: Codable {
    public let schema: String
    public let index: Int
    public let title: String
    public let sceneSHA256: String
    public let root: Node

    enum CodingKeys: String, CodingKey {
        case schema, index, title, root
        case sceneSHA256 = "scene_sha256"
    }

    public struct Node: Codable, Identifiable {
        public let name: String
        public let fields: [String]
        public let children: [Node]
        public let position: [Double]?
        public let positionRelative: [Double]?
        public let rotationRaw: String?
        public let rotationRelativeRaw: String?
        public let models: [String]?
        public let goalRaw: String?

        enum CodingKeys: String, CodingKey {
            case name, fields, children, position, models
            case positionRelative = "position_relative"
            case rotationRelativeRaw = "rotation_relative_raw"
            case rotationRaw = "rotation_raw"
            case goalRaw = "goal_raw"
        }

        // Stable only within a displayed document's hierarchy, not globally.
        public var id: String { name + ":" + fields.joined(separator: "|") }

        /// Preserve all original scalar field values, including repeated keys.
        /// A field's presence does not establish its gameplay semantics.
        public var originalFieldValues: [String: [String]] {
            var result: [String: [String]] = [:]
            for field in fields {
                let parts = field.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
                guard let first = parts.first else { continue }
                let key = String(first)
                let value = parts.count > 1 ? String(parts[1]) : ""
                result[key, default: []].append(value)
            }
            return result
        }

        public var objectCount: Int {
            (name.hasPrefix("tmo_") ? 1 : 0) +
            children.reduce(0) { $0 + $1.objectCount }
        }

        public var positionedObjectCount: Int {
            (name.hasPrefix("tmo_") && (position != nil || positionRelative != nil) ? 1 : 0) +
            children.reduce(0) { $0 + $1.positionedObjectCount }
        }

        public var goalCount: Int {
            (name.hasPrefix("tmo_") && goalRaw == "1" ? 1 : 0) +
            children.reduce(0) { $0 + $1.goalCount }
        }
    }

    /// A conservative inventory for rebuilding original gameplay.
    /// These are scene facts, not inferred physics or victory rules.
    public struct GameplayInventory {
        public let objectTypes: [String: Int]
        public let goalObjectTypes: [String: Int]
        public let objectsWithoutModels: [String: Int]
        public let objectsWithoutPosition: [String: Int]
    }

    public var gameplayInventory: GameplayInventory {
        var objects: [String: Int] = [:]
        var goals: [String: Int] = [:]
        var missingModels: [String: Int] = [:]
        var missingPositions: [String: Int] = [:]

        // Original 3DO references may be nested below transform/helper
        // nodes. A nested tmo_* belongs to a different original object.
        func hasOwnModel(_ node: Node) -> Bool {
            if !(node.models ?? []).isEmpty { return true }
            for child in node.children {
                if child.name.hasPrefix("3DO ") { return true }
                if !child.name.hasPrefix("tmo_") && hasOwnModel(child) {
                    return true
                }
            }
            return false
        }

        func visit(_ node: Node) {
            if node.name.hasPrefix("tmo_") {
                objects[node.name, default: 0] += 1
                if node.goalRaw == "1" {
                    goals[node.name, default: 0] += 1
                }
                if !hasOwnModel(node) {
                    missingModels[node.name, default: 0] += 1
                }
                if node.position == nil && node.positionRelative == nil {
                    missingPositions[node.name, default: 0] += 1
                }
            }
            for child in node.children { visit(child) }
        }
        visit(root)
        return GameplayInventory(
            objectTypes: objects,
            goalObjectTypes: goals,
            objectsWithoutModels: missingModels,
            objectsWithoutPosition: missingPositions
        )
    }

    public static func read(_ data: Data) throws -> Self {
        guard data.count <= 8_000_000 else { throw SceneError.invalid }
        let document = try JSONDecoder().decode(Self.self, from: data)
        guard document.schema == "crazy-machines-original-scene-v1",
              (1...102).contains(document.index),
              !document.title.isEmpty,
              document.title.count <= 160,
              document.sceneSHA256.count == 64,
              document.sceneSHA256.allSatisfy({ $0.isHexDigit }),
              document.root.name == "level" else { throw SceneError.invalid }
        var nodeCount = 0
        try validate(document.root, depth: 0, nodeCount: &nodeCount)
        return document
    }

    private static func validate(_ node: Node, depth: Int, nodeCount: inout Int) throws {
        nodeCount += 1
        guard nodeCount <= 20_000, depth <= 64,
              node.name.count <= 256,
              node.fields.count <= 256,
              node.children.count <= 2048,
              (node.models?.count ?? 0) <= 256,
              (node.models ?? []).allSatisfy({ !$0.isEmpty && $0.count <= 512 && !$0.contains(where: { $0.isNewline || $0 == "\0" }) }),
              (node.rotationRaw?.count ?? 0) <= 4096,
              (node.rotationRelativeRaw?.count ?? 0) <= 4096,
              (node.goalRaw?.count ?? 0) <= 256,
              node.fields.allSatisfy({ $0.count <= 4096 }) else { throw SceneError.invalid }
        if let p = node.position {
            guard p.count == 3 && p.allSatisfy({ $0.isFinite && abs($0) <= Double(Float.greatestFiniteMagnitude) }) else { throw SceneError.invalid }
        }
        if let p = node.positionRelative {
            guard p.count == 3 && p.allSatisfy({ $0.isFinite && abs($0) <= Double(Float.greatestFiniteMagnitude) }) else { throw SceneError.invalid }
        }
        for child in node.children {
            try validate(child, depth: depth + 1, nodeCount: &nodeCount)
        }
    }

    public enum SceneError: Error { case invalid }
}
