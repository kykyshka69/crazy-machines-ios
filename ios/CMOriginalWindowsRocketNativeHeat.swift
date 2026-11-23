import Foundation

/// Exact Win32 0x44E12E -> 0x44E17A -> 0x44E3A4 -> 0x44E3BD:
/// the CANDLE's own first linked selector-3 region owns a +0x20 cone.
/// The rocket's separate first linked selector-3 region has the +0x24
/// receiver coordinate. All values must share a NATIVE reference frame.
/// A nearby SceneKit UCM Heat marker is NEVER proof of native ignition.
public enum CMOriginalWindowsRocketNativeHeat {
    public struct Point {
        public let x: Float
        public let y: Float
        public let z: Float
        public init(_ x: Float, _ y: Float, _ z: Float = 0) {
            self.x = x; self.y = y; self.z = z
        }
    }

    public struct SourceCone {
        public let selectedRecordIndex: Int
        public let coordinateFrameID: String
        public let nativeOrigin: Point // native source cone +0x00
        public let parameters: CMOriginalWindowsWindRegion.Parameters
        /// Source cone shape reconstructed from original candle constants.
        /// Actual native region origin and rotated axis still must be read
        /// from original runtime, never inferred from UCM proximity.
        public static func originalCandle(
            selectedRecordIndex: Int, coordinateFrameID: String,
            nativeOrigin: Point,
            observedNativeAxis: CMOriginalWindowsWindRegion.Vector3
        ) -> SourceCone? {
            // A native selector record must come from an identified
            // original reference frame and have finite planar position.
            // Original 0x409650 deliberately ignores source Z.
            guard selectedRecordIndex >= 0,
                  !coordinateFrameID.isEmpty,
                  nativeOrigin.x.isFinite, nativeOrigin.y.isFinite else {
                return nil
            }
            guard let shape = CMOriginalWindowsCandleHeatFactory.parameters(
                observedNativeAxis: observedNativeAxis) else { return nil }
            return SourceCone(selectedRecordIndex: selectedRecordIndex,
                              coordinateFrameID: coordinateFrameID,
                              nativeOrigin: nativeOrigin, parameters: shape)
        }

        public init(selectedRecordIndex: Int, coordinateFrameID: String,
                    nativeOrigin: Point,
                    parameters: CMOriginalWindowsWindRegion.Parameters) {
            self.selectedRecordIndex = selectedRecordIndex
            self.coordinateFrameID = coordinateFrameID
            self.nativeOrigin = nativeOrigin
            self.parameters = parameters
        }
    }

    public struct Receiver {
        public let selectedRecordIndex: Int
        public let coordinateFrameID: String
        public let nativePosition: Point // native rocket region +0x24
        public init(selectedRecordIndex: Int, coordinateFrameID: String,
                    nativePosition: Point) {
            self.selectedRecordIndex = selectedRecordIndex
            self.coordinateFrameID = coordinateFrameID
            self.nativePosition = nativePosition
        }
    }

    /// Apply the ORIGINAL candle thermal cone SHAPE to genuinely moving
    /// imported SceneKit UCM source/receiver coordinates. Unlike `measure`,
    /// this is only a WORLD-space projection: the native Win32 +0x20/+0x24
    /// region reference frame and original effect state remain unobserved.
    /// Never use this candidate alone as native ignition or GOAL.
    public static func projectedUCMHeatFraction(
        observedSourceWorldYAxis: CMOriginalWindowsWindRegion.Vector3,
        observedSourceToTargetWorldXY: CMOriginalWindowsWindRegion.Vector3
    ) -> Float? {
        guard let cone = CMOriginalWindowsCandleHeatFactory.parameters(
            observedNativeAxis: observedSourceWorldYAxis) else { return nil }
        return CMOriginalWindowsWindRegion.measuredFraction(
            nativeDisplacement: observedSourceToTargetWorldXY, region: cone)
    }

    public struct Measurement {
        public let sourceRecordIndex: Int
        public let receiverRecordIndex: Int
        public let measuredNativeFraction: Float
    }

    /// Nil: missing/ambiguous native record evidence. Zero: observed
    /// receiver outside the verified native source cone. NO implicit GOAL.
    public static func measure(
        sourceID: String, sourceType: String, originalCandleLit: Bool,
        sourceNativeRecords: [CMOriginalWindowsRegionSelector.Entry],
        observedSourceCone: SourceCone?,
        rocketParentID: String, originalRocketType: String,
        rocketNativeRecords: [CMOriginalWindowsRegionSelector.Entry],
        observedRocketReceiver: Receiver?
    ) -> Measurement? {
        guard !sourceID.isEmpty, !rocketParentID.isEmpty,
              sourceID != rocketParentID,
              sourceType == "tmo_candle", originalCandleLit,
              originalRocketType == "tmo_heat_rocket",
              let source = observedSourceCone,
              let target = observedRocketReceiver,
              !source.coordinateFrameID.isEmpty,
              source.coordinateFrameID == target.coordinateFrameID,
              let sourceIndex = CMOriginalWindowsRegionSelector.matchingEntryIndex(
                  in: sourceNativeRecords, selector: 3, occurrence: 0),
              let targetIndex = CMOriginalWindowsRegionSelector.matchingEntryIndex(
                  in: rocketNativeRecords, selector: 3, occurrence: 0),
              sourceIndex == source.selectedRecordIndex,
              targetIndex == target.selectedRecordIndex
        else { return nil }

        // The original region kernel 0x409650 zeroes the Z component
        // BEFORE comparing angle and squared distance in the physical XY.
        let dx = Double(target.nativePosition.x) - Double(source.nativeOrigin.x)
        let dy = Double(target.nativePosition.y) - Double(source.nativeOrigin.y)
        guard dx.isFinite, dy.isFinite,
              abs(dx) <= Double(Float.greatestFiniteMagnitude),
              abs(dy) <= Double(Float.greatestFiniteMagnitude),
              let fraction = CMOriginalWindowsWindRegion.measuredFraction(
                nativeDisplacement: .init(Float(dx), Float(dy), 0),
                region: source.parameters)
        else { return nil }
        return Measurement(sourceRecordIndex: sourceIndex,
                           receiverRecordIndex: targetIndex,
                           measuredNativeFraction: fraction)
    }

    /// The verified >0.84 region hit can change Win32 parent state 0 -> 1
    /// ONLY after real original ignition effect and clock are observed.
    public static func ignitionAfterObservedEffect(
        sourceID: String, sourceType: String, originalCandleLit: Bool,
        sourceNativeRecords: [CMOriginalWindowsRegionSelector.Entry],
        observedSourceCone: SourceCone?,
        rocketParentID: String, originalRocketType: String,
        rocketNativeRecords: [CMOriginalWindowsRegionSelector.Entry],
        observedRocketReceiver: Receiver?,
        nativeRocketState: Float,
        actualIgnitionEffectObserved: Bool,
        observedNativeClock: Double
    ) -> CMOriginalWindowsRocketTimer.ObservedIgnition? {
        guard let coverage = measure(
            sourceID: sourceID, sourceType: sourceType,
            originalCandleLit: originalCandleLit,
            sourceNativeRecords: sourceNativeRecords,
            observedSourceCone: observedSourceCone,
            rocketParentID: rocketParentID,
            originalRocketType: originalRocketType,
            rocketNativeRecords: rocketNativeRecords,
            observedRocketReceiver: observedRocketReceiver)
        else { return nil }
        return CMOriginalWindowsRocketTimer.ignitionAfterObservedCandleEffect(
            nativeRocketType: originalRocketType,
            nativeRocketState: nativeRocketState,
            nativeHeatSourceType: sourceType,
            originalCandleLit: originalCandleLit,
            measuredNativeHeatFraction: coverage.measuredNativeFraction,
            originalIgnitionEffectObserved: actualIgnitionEffectObserved,
            observedNativeClock: observedNativeClock)
    }
}
