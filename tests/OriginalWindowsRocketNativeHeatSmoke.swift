import Foundation

@main struct OriginalWindowsRocketNativeHeatSmoke {
    static func main() {
        typealias H = CMOriginalWindowsRocketNativeHeat
        typealias R = CMOriginalWindowsRegionSelector
        let sources: [R.Entry] = [.init(linkedNativeSelector: nil),
                                  .init(linkedNativeSelector: 3),
                                  .init(linkedNativeSelector: 3)]
        let targets: [R.Entry] = [.init(linkedNativeSelector: 2),
                                  .init(linkedNativeSelector: 3)]
        let cone = CMOriginalWindowsWindRegion.Parameters(
            nativeAxis: .init(1, 0), minRadiusSquared: 1,
            maxRadiusSquared: 100, radialFalloff: 0.01,
            maximumAngle: .pi / 2, angularFalloff: 2 / .pi)
        func source(_ record: Int = 1, frame: String = "native-A") -> H.SourceCone {
            .init(selectedRecordIndex: record, coordinateFrameID: frame,
                  nativeOrigin: .init(10, 20, .nan), parameters: cone)
        }
        func receiver(_ record: Int = 1, frame: String = "native-A",
                      at: H.Point = .init(14, 20, .infinity)) -> H.Receiver {
            .init(selectedRecordIndex: record, coordinateFrameID: frame,
                  nativePosition: at)
        }
        func measure(_ s: H.SourceCone? = nil, _ t: H.Receiver? = nil,
                     lit: Bool = true, sourceType: String = "tmo_candle",
                     sourceRecords: [R.Entry]? = nil,
                     targetRecords: [R.Entry]? = nil,
                     parentType: String = "tmo_heat_rocket") -> H.Measurement? {
            H.measure(sourceID: "candle-1", sourceType: sourceType,
                originalCandleLit: lit,
                sourceNativeRecords: sourceRecords ?? sources,
                observedSourceCone: s ?? source(),
                rocketParentID: "rocket-1", originalRocketType: parentType,
                rocketNativeRecords: targetRecords ?? targets,
                observedRocketReceiver: t ?? receiver())
        }
        let hit = measure()
        precondition(hit?.sourceRecordIndex == 1)
        precondition(hit?.receiverRecordIndex == 1)
        precondition(abs((hit?.measuredNativeFraction ?? 0)-0.85) < 0.00001)
        precondition(measure(source(0)) == nil)
        precondition(measure(source(2)) == nil)
        precondition(measure(source(), receiver(0)) == nil)
        precondition(measure(source(frame: "A"), receiver(frame: "B")) == nil)
        precondition(measure(source(frame: "")) == nil)
        precondition(measure(lit: false) == nil)
        precondition(measure(sourceType: "tmo_candle_dyn") == nil)
        precondition(measure(sourceRecords: []) == nil)
        precondition(measure(targetRecords: [.init(linkedNativeSelector: nil)]) == nil)
        precondition(measure(parentType: "tmo_ball") == nil)
        precondition(measure(source(), receiver(at: .init(10, 20))) == nil)
        precondition(measure(source(), receiver(at: .init(.nan, 20))) == nil)
        precondition(measure(source(), receiver(at: .init(.infinity, 20))) == nil)
        precondition(abs((measure(source(), receiver(at: .init(15, 20)))?
            .measuredNativeFraction ?? 0)-0.76) < 0.00001)
        func ignition(_ s: H.SourceCone? = nil, _ t: H.Receiver? = nil,
                      lit: Bool = true, effect: Bool = true,
                      state: Float = 0,
                      clock: Double = 7) -> CMOriginalWindowsRocketTimer.ObservedIgnition? {
            H.ignitionAfterObservedEffect(
                sourceID: "candle-1", sourceType: "tmo_candle",
                originalCandleLit: lit, sourceNativeRecords: sources,
                observedSourceCone: s ?? source(),
                rocketParentID: "rocket-1", originalRocketType: "tmo_heat_rocket",
                rocketNativeRecords: targets,
                observedRocketReceiver: t ?? receiver(),
                nativeRocketState: state,
                actualIgnitionEffectObserved: effect,
                observedNativeClock: clock)
        }
        precondition(ignition()?.state == 1)
        precondition(ignition()?.ignitionTime == 7)
        precondition(ignition(effect: false) == nil)
        precondition(ignition(lit: false) == nil)
        precondition(ignition(state: 1) == nil)
        precondition(ignition(clock: .nan) == nil)
        precondition(ignition(source(2)) == nil)
        precondition(ignition(source(), receiver(at: .init(15, 20))) == nil)
        precondition(ignition(source(), receiver(at: .init(6, 20))) == nil)
        // Actual 17-degree candle cone passes through the SAME native
        // source +0x20 / receiver +0x24, selector and effect gate.
        let realCandleShape = H.SourceCone.originalCandle(
            selectedRecordIndex: 1, coordinateFrameID: "native-A",
            nativeOrigin: .init(10, 20),
            observedNativeAxis: .init(0, 1))!
        precondition(measure(realCandleShape, receiver(at: .init(10, 20.35))) != nil)
        precondition(ignition(realCandleShape, receiver(at: .init(10, 20.35)))?.state == 1)
        precondition(ignition(realCandleShape, receiver(at: .init(10, 20.6))) == nil)
        precondition(H.SourceCone.originalCandle(
            selectedRecordIndex: 1, coordinateFrameID: "native-A",
            nativeOrigin: .init(10, 20),
            observedNativeAxis: .init(0, 0)) == nil)
        precondition(H.SourceCone.originalCandle(
            selectedRecordIndex: -1, coordinateFrameID: "native-A",
            nativeOrigin: .init(10, 20),
            observedNativeAxis: .init(0, 1)) == nil)
        precondition(H.SourceCone.originalCandle(
            selectedRecordIndex: 1, coordinateFrameID: "",
            nativeOrigin: .init(10, 20),
            observedNativeAxis: .init(0, 1)) == nil)
        precondition(H.SourceCone.originalCandle(
            selectedRecordIndex: 1, coordinateFrameID: "native-A",
            nativeOrigin: .init(.nan, 20),
            observedNativeAxis: .init(0, 1)) == nil)
        print("Win32 native source cone +0x20 / rocket receiver +0x24 chain: PASS")
    }
}
