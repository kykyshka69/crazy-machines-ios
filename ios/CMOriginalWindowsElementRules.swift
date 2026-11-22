import Foundation

/// A faithful merge of user-owned Windows elements.fsc defaults and actual
/// per-instance CML fields. An override in a particular Professor puzzle
/// wins over the generic original template; do NOT make every domino or
/// bucket share an invented physical role.
public struct CMOriginalWindowsElementRules: Sendable {
    public let type: String
    public let effectiveBits: Int?
    public let effectiveFloat: Double?
    public let goalMarker: String?
    public let isEditable: Bool
    public let hasOriginalFlagOverride: Bool
    public let cameFromTemplateBits: Bool
    public let originalModelReferences: [String]

    /// The only confirmed movable indicator is bit 8 (from original VALB).
    /// Other Windows physics flags and game-specific win rules remain
    /// reverse-engineering work; a missing flag is NOT proof of immobility.
    public var hasMovableBit: Bool? {
        effectiveBits.map { ($0 & 8) != 0 }
    }

    public init?(type: String, sceneFields: [String],
                 catalogue: [String: CMOriginalElementsTemplateCatalog.Template]) {
        guard let originalTemplate = catalogue[type] else { return nil }
        self.type = type
        var raw: [String: [String]] = [:]
        for field in sceneFields {
            let parts = field.split(maxSplits: 1, whereSeparator: \.isWhitespace)
            guard let name = parts.first else { continue }
            let key = String(name).uppercased()
            let value = parts.count == 2
                ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
                : ""
            raw[key, default: []].append(value)
        }
        let sceneBits = raw["VALB"]?.first.flatMap(Int.init)
            .flatMap { (0...255).contains($0) ? $0 : nil }
        let sceneFloat = raw["VALF"]?.first.flatMap(Double.init)
            .flatMap { $0.isFinite ? $0 : nil }
        let originalBits = originalTemplate.defaultBits
        self.effectiveBits = sceneBits ?? originalBits
        self.effectiveFloat = sceneFloat ?? originalTemplate.defaultFloat
        self.goalMarker = raw["GOAL"]?.first
        self.isEditable = (raw["UNLOCKED"] ?? []).contains("1")
        self.hasOriginalFlagOverride = sceneBits != nil && originalBits != nil
            && sceneBits != originalBits
        self.cameFromTemplateBits = sceneBits == nil && originalBits != nil
        self.originalModelReferences = originalTemplate.modelReferences
    }
}