import Foundation

@main
struct OriginalOpticalSightlineSmoke {
    static func main() {
        typealias Geometry = CMOriginalOpticalSightlineGeometry
        let bulb = Geometry.Point(x: 1, y: 2, z: 0.5)
        let cell = Geometry.Point(x: 4, y: 6, z: 0.5)
        let clear = Geometry.measure(
            emitterID: "lamp-1", receiverID: "solar-1",
            emitter: bulb, receiver: cell,
            obstructingObjectIDs: ["lamp-1", "solar-1"]
        )
        precondition(clear?.isUnobstructed == true)
        precondition(clear?.pathLength == 5)
        precondition(clear?.emitterID == "lamp-1")
        precondition(clear?.receiverID == "solar-1")
        let blocked = Geometry.measure(
            emitterID: "lamp-1", receiverID: "solar-1",
            emitter: bulb, receiver: cell,
            obstructingObjectIDs: [
                "lamp-1", "wall-3", "mirror-8", "solar-1"
            ])
        precondition(blocked?.isUnobstructed == false)
        precondition(blocked?.firstBlockingObjectID == "wall-3")
        precondition(Geometry.measure(
            emitterID: "lamp-1", receiverID: "solar-1",
            emitter: bulb, receiver: bulb,
            obstructingObjectIDs: []
        ) == nil)
        precondition(Geometry.measure(
            emitterID: "lamp-1", receiverID: "lamp-1",
            emitter: bulb, receiver: cell,
            obstructingObjectIDs: []
        ) == nil)
        precondition(Geometry.measure(
            emitterID: "", receiverID: "solar-1",
            emitter: bulb, receiver: cell,
            obstructingObjectIDs: []
        ) == nil)
        precondition(Geometry.measure(
            emitterID: "lamp-1", receiverID: "solar-1",
            emitter: Geometry.Point(x: .infinity, y: 0, z: 0),
            receiver: cell, obstructingObjectIDs: []
        ) == nil)
        precondition(Geometry.measure(
            emitterID: "lamp-1", receiverID: "solar-1",
            emitter: Geometry.Point(x: .nan, y: 0, z: 0),
            receiver: cell, obstructingObjectIDs: []
        ) == nil)
        // A line-of-sight measurement never creates original solar power:
        // only the independently recovered Win32 scalar path could do so
        // after REAL ray direction, intersection weight and source power.
        precondition(clear?.isUnobstructed == true)
        print("Original UCM optical sightline geometry and blockers: OK")
    }
}
