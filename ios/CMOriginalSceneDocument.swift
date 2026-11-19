import Foundation

/// Read-only representation of a user-owned original Crazy Machines scene export.
/// This is intentionally separate from CMLevelDocument (the synthetic playground).
public struct CMOriginalSceneDocument: Decodable {
    public let schema: String
    public let index: Int
    public let title: String
    public let sceneSHA256: String
    public let root: Node

    enum CodingKeys: String, CodingKey {
        case schema, index, title, root
        case sceneSHA256 = "scene_sha256"
    }

    public struct Node: Decodable, Identifiable {
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

        public var objectCount: Int {
            (name.hasPrefix("tmo_") ? 1 : 0) +
            children.reduce(0) { $0 + $1.objectCount }
        }

        public var positionedObjectCount: Int {
            (name.hasPrefix("tmo_") && position != nil ? 1 : 0) +
            children.reduce(0) { $0 + $1.positionedObjectCount }
        }

        public var goalCount: Int {
            (name.hasPrefix("tmo_") && goalRaw == "1" ? 1 : 0) +
            children.reduce(0) { $0 + $1.goalCount }
        }
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
        try validate(document.root, depth: 0)
        return document
    }

    private static func validate(_ node: Node, depth: Int) throws {
        guard depth <= 64,
              node.name.count <= 256,
              node.fields.count <= 256,
              node.children.count <= 2048,
              node.fields.allSatisfy({ $0.count <= 4096 }) else { throw SceneError.invalid }
        if let p = node.position {
            guard p.count == 3 && p.allSatisfy({ $0.isFinite }) else { throw SceneError.invalid }
        }
        if let p = node.positionRelative {
            guard p.count == 3 && p.allSatisfy({ $0.isFinite }) else { throw SceneError.invalid }
        }
        for child in node.children { try validate(child, depth: depth + 1) }
    }

    public enum SceneError: Error { case invalid }
}
