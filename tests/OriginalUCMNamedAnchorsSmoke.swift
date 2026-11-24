import Foundation

@main
struct OriginalUCMNamedAnchorsSmoke {
    static func put32(_ data: inout Data, _ at: Int, _ n: UInt32) {
        for index in 0..<4 { data[at+index] = UInt8(truncatingIfNeeded: n >> (8*index)) }
    }
    static func main() throws {
        let markers = 2
        let matrixOffset = 92 + 12 + 3 * 32 + markers * 16
        var data = Data(repeating: 0, count: matrixOffset + markers * 64)
        data.replaceSubrange(0..<4, with: [85, 67, 77, 49])
        put32(&data, 4, 1)
        put32(&data, 72, 1)
        put32(&data, 76, 1)
        put32(&data, 80, 3)
        put32(&data, 84, UInt32(markers))
        put32(&data, 92, 0); put32(&data, 96, 1); put32(&data, 100, 2)
        data.replaceSubrange(matrixOffset-32..<(matrixOffset-32+4), with: [72, 101, 97, 116])
        data.replaceSubrange(matrixOffset-16..<(matrixOffset-16+6), with: [69,110,103,105,110,101])
        for i in 0..<markers {
            for axis in [0,5,10,15] { put32(&data, matrixOffset+i*64+axis*4, Float(1).bitPattern) }
        }
        put32(&data, matrixOffset+12*4, Float(0.2).bitPattern)
        put32(&data, matrixOffset+64+13*4, Float(0.35).bitPattern)
        // The authentic rocket includes oriented frames, not merely
        // translations. Preserve a nonidentity basis in the decoder.
        put32(&data, matrixOffset+64+5*4, Float(0).bitPattern)
        put32(&data, matrixOffset+64+6*4, Float(1).bitPattern)
        put32(&data, matrixOffset+64+9*4, Float(-1).bitPattern)
        put32(&data, matrixOffset+64+10*4, Float(0).bitPattern)
        let anchors = try CMOriginalUCMNamedAnchors.decode(data)
        precondition(anchors.count == 2)
        precondition(anchors[0].name == "Heat" && anchors[0].slot == 0)
        precondition(anchors[1].name == "Engine" && anchors[1].slot == 1)
        precondition(abs(anchors[0].localTranslationCandidate[0]-0.2)<0.00001)
        precondition(abs(anchors[1].localTranslationCandidate[1]-0.35)<0.00001)
        precondition(anchors[1].matrixRowMajor[6] == 1)
        precondition(anchors[1].matrixRowMajor[9] == -1)
        precondition(anchors[1].matrixRowMajor[5] == 0)
        precondition(anchors[1].matrixRowMajor[10] == 0)
        var corrupt = data; put32(&corrupt, matrixOffset+12*4, 0x7fc00000)
        do { _ = try CMOriginalUCMNamedAnchors.decode(corrupt); fatalError("accepted NaN") }
        catch CMOriginalUCMNamedAnchors.Error.invalidMatrix { }
        do { _ = try CMOriginalUCMNamedAnchors.decode(Data(data.dropLast())); fatalError("accepted truncated") }
        catch CMOriginalUCMNamedAnchors.Error.invalidLayout { }
        corrupt = data; corrupt[matrixOffset-32] = 0
        do { _ = try CMOriginalUCMNamedAnchors.decode(corrupt); fatalError("accepted missing marker") }
        catch CMOriginalUCMNamedAnchors.Error.invalidMarker { }
        // Original UCM collision tables must retain an authored scaled
        // orientation, and malformed collision bytes must not reach SceneKit.
        let empty = try CMOriginalUCMCollisionVolumes.decode(data)
        precondition(empty.isEmpty)
        var collision = data
        let tail = collision.count
        collision.append(Data(repeating: 0, count: 8 + 16 + 60))
        put32(&collision, tail, 1)
        put32(&collision, tail+4, 1)
        let sphere: [Float] = [0.1, -0.2, 0.3, 0.25]
        let box: [Float] = [0.2, 0.3, 0.4, 0.5, 0.2, 0.1,
                            0, 0.66, 0, -1, 0, 0, 0, 0, 1]
        for (i, value) in (sphere + box).enumerated() {
            put32(&collision, tail+8+4*i, value.bitPattern)
        }
        let volumes = try CMOriginalUCMCollisionVolumes.decode(collision)
        precondition(volumes.spheres.count == 1 && volumes.boxes.count == 1)
        precondition(volumes.spheres[0].center == [0.1,-0.2,0.3])
        precondition(volumes.spheres[0].radius == 0.25)
        precondition(abs(volumes.boxes[0].halfExtents[0]-0.33) < 0.00001)
        precondition(volumes.boxes[0].axes == [0,1,0,-1,0,0,0,0,1])
        var badVolume = collision
        put32(&badVolume, tail+20, Float(-1).bitPattern)
        do { _ = try CMOriginalUCMCollisionVolumes.decode(badVolume)
            fatalError("accepted negative sphere radius") }
        catch CMOriginalUCMNamedAnchors.Error.invalidLayout { }
        do { _ = try CMOriginalUCMCollisionVolumes.decode(Data(collision.dropLast()))
            fatalError("accepted truncated collision record") }
        catch CMOriginalUCMNamedAnchors.Error.invalidLayout { }
        for kind in ["tmo_board", "tmo_bucket", "tmo_rope_cage", "tmo_belt_gear",
                     "tmo_ball_steel", "tmo_magnetic_permanent", "tmo_power_motor"] {
            precondition(CMOriginalUCMCollisionVolumes.usesAuthoredVolumes(kind: kind))
        }
        precondition(!CMOriginalUCMCollisionVolumes.usesAuthoredVolumes(kind: "tmo_background_concrete"))
        precondition(!CMOriginalUCMCollisionVolumes.usesAuthoredVolumes(kind: "tmo_power_motor_rotor"))
        precondition(CMOriginalUCMCollisionVolumes.isBoundsHelper(kind: "tmo_bucket", model: "TO_DUMMY_BOUNDING"))
        precondition(!CMOriginalUCMCollisionVolumes.isBoundsHelper(kind: "tmo_bucket", model: "to_bucket"))
        precondition(!CMOriginalUCMCollisionVolumes.isBoundsHelper(kind: "tmo_board", model: "to_dummy_bounding"))
        typealias Overlap = CMOriginalVolumeOverlap
        typealias V = Overlap.V
        func pose(_ p: V, angle: Double = 0, scale: Double = 1) -> Overlap.Transform {
            .init(origin: p, x: V(cos(angle),sin(angle),0)*scale,
                  y: V(-sin(angle),cos(angle),0)*scale, z: V(0,0,scale))
        }
        let worldVolumes = Overlap.world(volumes, transform: pose(.zero))!
        precondition(worldVolumes.count == 2)
        let translated = Overlap.world(volumes, transform: pose(V(10,0,0)))!
        precondition(!Overlap.intersects(worldVolumes, translated))
        for i in 0..<24 {
            let angle = Double(i)*Double.pi/12
            let rotated = Overlap.world(volumes, transform: pose(.zero,angle:angle))!
            precondition(Overlap.intersects(rotated,worldVolumes))
            precondition(Overlap.intersects(worldVolumes,rotated))
        }
        let axes = [V(1,0,0),V(0,1,0),V(0,0,1)]
        let zone = Overlap.Primitive.box(center:.zero, axes:axes, half:V(0.5,0.5,0.1))
        let sphereNear = Overlap.Primitive.sphere(center:V(0.7,0,0),radius:0.25)
        let sphereFar = Overlap.Primitive.sphere(center:V(0.76,0,0),radius:0.25)
        let depthMiss = Overlap.Primitive.sphere(center:V(0,0,0.5),radius:0.25)
        precondition(Overlap.intersects(zone,sphereNear))
        precondition(!Overlap.intersects(zone,sphereFar))
        precondition(!Overlap.intersects(zone,depthMiss))
        precondition(Overlap.world(volumes, transform:.init(origin:.zero,
            x:V(2,0,0), y:V(0,1,0), z:V(0,0,1))) == nil)
        precondition(Overlap.world(volumes, transform:.init(origin:.zero,
            x:V(1,0,0), y:V(0.2,1,0), z:V(0,0,1))) == nil)
        precondition(!Overlap.intersects([zone], []))
        print("UCM1 named attachment records and matrices: valid/invalid tests passed")
        if CommandLine.arguments.count >= 3 {
            let candle = try CMOriginalUCMNamedAnchors.decode(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
            let rocket = try CMOriginalUCMNamedAnchors.decode(Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
            precondition(candle.map(\.name).contains("Heat"))
            precondition(Set(rocket.map(\.name)).isSuperset(of: ["Heat", "Engine", "Explode", "Direction"]))
            precondition(rocket.count == 7)
            let engine = rocket.first { $0.name == "Engine" }!
            let explode = rocket.first { $0.name == "Explode" }!
            precondition(abs(engine.localTranslationCandidate[1] - 0.05635856) < 0.00001)
            precondition(abs(explode.localTranslationCandidate[1] - 0.36828864) < 0.00001)
            let direction = rocket.first { $0.name == "Direction" }!
            precondition(engine.matrixRowMajor[6] > 0.99)
            precondition(direction.matrixRowMajor[6] < -0.99)
            precondition(engine.matrixRowMajor[9] < -0.99)
            precondition(direction.matrixRowMajor[9] > 0.99)
            print("Owner-original Candle and Rocket UCM1 markers verified")
        }
    }
}
