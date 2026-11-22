import Foundation

@main
struct OriginalWindowsOpticalSampleSmoke {
    static func main() {
        typealias B = CMOriginalWindowsBeamRegion
        typealias G = CMOriginalOpticalSightlineGeometry
        let from = G.Point(x: 0, y: 0, z: 0)
        let to = G.Point(x: 1, y: 0, z: 0)
        let clear = G.measure(
            emitterID: "lamp-A", receiverID: "solar-B",
            emitter: from, receiver: to,
            obstructingObjectIDs: ["lamp-A", "solar-B"])!
        let p = B.Parameters(innerSquaredDistance: 0,
            outerSquaredDistance: 25, distanceFalloff: 1/25,
            maximumAngle: .pi / 2, angleFalloff: 0)
        let origin = B.Vector(x: 0, y: 0)
        let point = B.Vector(x: 1, y: 0)
        func measure(_ sightline: CMOriginalOpticalSightline,
                     forward: B.Vector = .init(x: 1, y: 0),
                     power: Float = 10) -> Float? {
            CMOriginalWindowsOpticalSample.originalSolarContribution(
                sightline: sightline, beamOrigin: origin,
                beamForward: forward, receiverPoint: point,
                nativeBeamParameters: p, observedEmitterPower: power)
        }
        let ray = measure(clear)
        // Original Win32 beam weight .96 and solar ray weight .192:
        // (10 / 10) * .96 / (1 * 5).
        precondition(ray != nil && abs(ray! - 0.192) < 0.000001)
        precondition(CMOriginalWindowsSolarSignal.collectedPower(
            rayContributions: [ray!])! > 1)
        let blocked = G.measure(
            emitterID: "lamp-A", receiverID: "solar-B",
            emitter: from, receiver: to,
            obstructingObjectIDs: ["lamp-A", "wall-C", "solar-B"])!
        precondition(measure(blocked) == nil)
        precondition(measure(clear, forward: .init(x: -1, y: 0)) == nil)
        precondition(measure(clear, power: 0) == nil)
        precondition(measure(clear, power: -1) == nil)
        precondition(measure(clear, power: .nan) == nil)
        precondition(abs(measure(clear, power: 5)! - 0.096) < 0.000001)
        print("Real Win32 ray region + original solar attenuation requires non-blocked UCM light")
    }
}
