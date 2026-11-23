import Foundation

/// Measured real imported UCM Heat anchor displacement between one lit
/// original PC candle and one genuine nested rocket child. It is NEVER
/// a Win32 selector-3 region hit, thermal radius, ignition or GOAL.
public enum CMOriginalRocketCandleHeatPair {
    public struct Position: Equatable {
        public let x: Float, y: Float, z: Float
        public init(_ x: Float, _ y: Float, _ z: Float = 0) {
            self.x = x; self.y = y; self.z = z
        }
        public var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }
    }
    public struct Observation: Equatable {
        public let candleID: String
        public let rocketParentID: String
        public let rocketChildID: String
        public let sourceHeatWorld: Position
        public let targetHeatWorld: Position
        /// Only the observed source-to-target WORLD XY; a native
        /// region-local vector has NOT been established from this.
        public let sourceToTargetXY: Position
        public let xyDistanceSquared: Double
    }
    public static func measure(
        candleID: String, sourceType: String, sourceLit: Bool,
        sourceHeatWorld: Position?,
        rocketParentID: String, rocketChildID: String,
        parentType: String, childType: String,
        targetHeatWorld: Position?
    ) -> Observation? {
        guard !candleID.isEmpty, !rocketParentID.isEmpty,
              !rocketChildID.isEmpty,
              candleID != rocketParentID, candleID != rocketChildID,
              rocketParentID != rocketChildID,
              sourceType == "tmo_candle", sourceLit,
              parentType == "tmo_heat_rocket",
              childType == "tmo_heat_rocket_rocket",
              let sourceHeatWorld, sourceHeatWorld.isFinite,
              let targetHeatWorld, targetHeatWorld.isFinite
        else { return nil }
        let dx = Double(targetHeatWorld.x) - Double(sourceHeatWorld.x)
        let dy = Double(targetHeatWorld.y) - Double(sourceHeatWorld.y)
        let sq = dx * dx + dy * dy
        guard sq.isFinite, dx.isFinite, dy.isFinite,
              abs(dx) <= Double(Float.greatestFiniteMagnitude),
              abs(dy) <= Double(Float.greatestFiniteMagnitude)
        else { return nil }
        return Observation(
            candleID: candleID, rocketParentID: rocketParentID,
            rocketChildID: rocketChildID,
            sourceHeatWorld: sourceHeatWorld,
            targetHeatWorld: targetHeatWorld,
            sourceToTargetXY: .init(Float(dx), Float(dy), 0),
            xyDistanceSquared: sq)
    }
}
