import Foundation

/// The owner's original UCM1 packs store 16-byte named markers immediately
/// after vertices and one 4x4 matrix for each (group, marker) binding.
/// These are authentic Heat/Engine/Explode/Direction attachment transforms,
/// NOT native heat-region radii, Win32 GOAL events, or physics impulses.
public enum CMOriginalUCMNamedAnchors {
    public enum Error: Swift.Error {
        case invalidHeader, invalidLayout, invalidMarker, invalidMatrix
    }

    public struct Anchor {
        public let group: Int
        public let slot: Int
        public let name: String
        /// The exact sixteen little-endian Float32 values from the UCM.
        public let matrixRowMajor: [Float]
        /// Candidate local XYZ is the final matrix row, not a guessed radius.
        public var localTranslationCandidate: [Float] {
            Array(matrixRowMajor[12..<15])
        }
    }

    public static func decode(_ data: Data) throws -> [Anchor] {
        guard data.count >= 92,
              data.prefix(4).elementsEqual([85, 67, 77, 49]) else {
            throw Error.invalidHeader
        }
        func u32(_ at: Int) throws -> UInt32 {
            guard at >= 0, at <= data.count - 4 else { throw Error.invalidLayout }
            return UInt32(data[at]) | UInt32(data[at+1]) << 8
                | UInt32(data[at+2]) << 16 | UInt32(data[at+3]) << 24
        }
        let version = try u32(4)
        guard version == 1 || version == 2 else { throw Error.invalidHeader }
        let groups = Int(try u32(72))
        let faces = Int(try u32(76))
        let verticesPerGroup = Int(try u32(80))
        let markers = Int(try u32(84))
        guard groups > 0 && groups <= 10_000,
              faces > 0 && faces <= 1_000_000,
              verticesPerGroup > 0 && verticesPerGroup <= 100_000,
              markers <= 1_000_000 else { throw Error.invalidLayout }
        func checkedMultiply(_ a: Int, _ b: Int) throws -> Int {
            let (result, bad) = a.multipliedReportingOverflow(by: b)
            if bad { throw Error.invalidLayout }
            return result
        }
        func checkedAdd(_ a: Int, _ b: Int) throws -> Int {
            let (result, bad) = a.addingReportingOverflow(b)
            if bad { throw Error.invalidLayout }
            return result
        }
        let bindings = try checkedMultiply(groups, markers)
        guard bindings <= 50_000 else { throw Error.invalidLayout }
        let namesOffset = try checkedAdd(
            try checkedAdd(92, checkedMultiply(faces, 12)),
            checkedMultiply(try checkedMultiply(groups, verticesPerGroup), 32))
        let matrixOffset = try checkedAdd(namesOffset, checkedMultiply(markers, 16))
        let end = try checkedAdd(matrixOffset, checkedMultiply(bindings, 64))
        guard end <= data.count else { throw Error.invalidLayout }
        var names: [String] = []
        names.reserveCapacity(markers)
        for index in 0..<markers {
            let start = namesOffset + 16 * index
            let raw = Array(data[start..<(start + 16)])
            let nameBytes = Array(raw.prefix(while: { $0 != 0 }))
            guard !nameBytes.isEmpty,
                  nameBytes.allSatisfy({ $0 >= 33 && $0 <= 126 }),
                  let name = String(bytes: nameBytes, encoding: .ascii)
            else { throw Error.invalidMarker }
            names.append(name)
        }
        var result: [Anchor] = []
        result.reserveCapacity(bindings)
        for group in 0..<groups {
            for slot in 0..<markers {
                let offset = matrixOffset + 64 * (group * markers + slot)
                var components: [Float] = []
                components.reserveCapacity(16)
                for component in 0..<16 {
                    let value = Float(bitPattern: try u32(offset + component * 4))
                    guard value.isFinite else { throw Error.invalidMatrix }
                    components.append(value)
                }
                result.append(Anchor(group: group, slot: slot,
                                     name: names[slot], matrixRowMajor: components))
            }
        }
        return result
    }
}


/// Authored collision primitives in the UCM1 tail, following marker matrices.
/// Native 0x46AAE0 uses 16-byte sphere and 60-byte oriented-box records.
/// No collision geometry is manufactured for absent or empty tables.
public enum CMOriginalUCMCollisionVolumes {
    /// Limit the first native-shape integration to verified gameplay models.
    /// Containers and weights have a separate selection/bounds helper 3DO;
    /// it is not part of the solid collision assembly.
    public static func usesAuthoredVolumes(kind: String) -> Bool {
        kind.hasPrefix("tmo_ball_") || [
            "tmo_zone", "tmo_crate", "tmo_balloon", "tmo_domino",
            "tmo_weight", "tmo_nail", "tmo_board", "tmo_trunk",
            "tmo_h_iron", "tmo_bucket", "tmo_rope_cage",
            "tmo_magnetic_permanent", "tmo_spring", "tmo_rope_seesaw_lever",
            "tmo_belt_gear", "tmo_rope_hook", "tmo_pipe", "tmo_pipe_corner",
            "tmo_pipe_distributor", "tmo_pipe_ventil", "tmo_pipe_ventil_lever",
            "tmo_pipe_whistle", "tmo_pipe_whistle_lever",
            "tmo_power_battery", "tmo_power_distributor", "tmo_power_motor",
            "tmo_power_generator", "tmo_power_switch", "tmo_power_switch_lever",
            "tmo_power_solarcell", "tmo_power_lightning", "tmo_power_disrupter",
            "tmo_power_disrupter_wheel", "tmo_windmill_base", "tmo_windmill_wheel",
            "tmo_windmill_wings", "tmo_steam_body", "tmo_steam_wheel",
            "tmo_steam_pleul", "tmo_steam_piston", "tmo_hammer", "tmo_hammer_hammer",
            "tmo_hammer_nail", "tmo_hammer_wheel", "tmo_catapult", "tmo_catapult_sling",
            "tmo_heat_rocket_rocket", "tmo_heat_cannon_ball", "tmo_heat_dynamite",
            "tmo_rope_crossbow", "tmo_rope_crossbow_arrow", "tmo_rope_crossbow_lever",
            "tmo_rope_scissors_1", "tmo_rope_scissors_2"
        ].contains(kind)
    }

    public static func isBoundsHelper(kind: String, model: String) -> Bool {
        ["tmo_bucket", "tmo_rope_cage", "tmo_weight", "tmo_nail",
         "tmo_rope_scissors_1"].contains(kind)
            && model.lowercased() == "to_dummy_bounding"
    }

    public struct Sphere {
        public let center: [Float]
        public let radius: Float
    }
    public struct Box {
        public let center: [Float]
        public let halfExtents: [Float]
        public let axes: [Float]
    }
    public struct Volumes {
        public let spheres: [Sphere]
        public let boxes: [Box]
        public var isEmpty: Bool { spheres.isEmpty && boxes.isEmpty }
    }

    public static func decode(_ data: Data) throws -> Volumes {
        typealias ParseError = CMOriginalUCMNamedAnchors.Error
        guard data.count >= 92, data.prefix(4).elementsEqual([85,67,77,49])
            else { throw ParseError.invalidHeader }
        func u32(_ at: Int) throws -> UInt32 {
            guard at >= 0, at <= data.count - 4 else { throw ParseError.invalidLayout }
            return UInt32(data[at]) | UInt32(data[at+1]) << 8
                | UInt32(data[at+2]) << 16 | UInt32(data[at+3]) << 24
        }
        let version = try u32(4)
        guard version == 1 || version == 2 else { throw ParseError.invalidHeader }
        let g = Int(try u32(72)), f = Int(try u32(76))
        let v = Int(try u32(80)), m = Int(try u32(84))
        guard (1...10000).contains(g), (1...1000000).contains(f),
              (1...100000).contains(v), m <= 1000000, g*m <= 50000
            else { throw ParseError.invalidLayout }
        var offset = 92 + 12*f + 32*g*v + 16*m + 64*g*m
        guard offset <= data.count else { throw ParseError.invalidLayout }
        if offset == data.count { return Volumes(spheres: [], boxes: []) }
        let ns = Int(try u32(offset)), nb = Int(try u32(offset+4))
        offset += 8
        guard ns <= 10000, nb <= 10000,
              offset + 16*ns + 60*nb == data.count
            else { throw ParseError.invalidLayout }
        func floats(_ count: Int) throws -> [Float] {
            var a: [Float] = []
            for _ in 0..<count {
                let value = Float(bitPattern: try u32(offset))
                guard value.isFinite else { throw ParseError.invalidMatrix }
                a.append(value)
                offset += 4
            }
            return a
        }
        var spheres: [Sphere] = []
        var boxes: [Box] = []
        for _ in 0..<ns {
            let a = try floats(4)
            guard a[3] > 0 else { throw ParseError.invalidLayout }
            spheres.append(Sphere(center: Array(a[0..<3]), radius: a[3]))
        }
        for _ in 0..<nb {
            let a = try floats(15)
            var axes = Array(a[6..<15])
            var halfExtents = Array(a[3..<6])
            // Native box transform normalizes each basis vector and
            // multiplies its extent by that vector's length (0x46C210).
            // The original fuze_dummy contains an authored 0.66 basis.
            for i in 0..<3 {
                let length = sqrt((0..<3).reduce(Float(0)) {
                    $0 + axes[i*3+$1]*axes[i*3+$1]
                })
                guard length.isFinite, length > 0, halfExtents[i] > 0
                    else { throw ParseError.invalidMatrix }
                halfExtents[i] *= length
                guard halfExtents[i].isFinite, halfExtents[i] > 0
                    else { throw ParseError.invalidMatrix }
                for j in 0..<3 { axes[i*3+j] /= length }
            }
            func dot(_ i: Int, _ j: Int) -> Float {
                (0..<3).reduce(Float(0)) { $0 + axes[i*3+$1]*axes[j*3+$1] }
            }
            guard abs(dot(0,1)) < 0.002, abs(dot(0,2)) < 0.002, abs(dot(1,2)) < 0.002
                else { throw ParseError.invalidMatrix }
            boxes.append(Box(center: Array(a[0..<3]), halfExtents: halfExtents, axes: axes))
        }
        return Volumes(spheres: spheres, boxes: boxes)
    }
}


/// Portable overlap of the authored collision primitives after applying
/// the live model transform. This is a geometric SAT adapter, not the
/// Windows rigid-body solver. Invalid/sheared transforms return nil.
public enum CMOriginalVolumeOverlap {
    public typealias V = SIMD3<Double>
    public enum Primitive {
        case sphere(center: V, radius: Double)
        case box(center: V, axes: [V], half: V)
    }

    public struct Transform {
        public let origin: V
        public let x: V
        public let y: V
        public let z: V
        public init(origin: V, x: V, y: V, z: V) {
            self.origin = origin; self.x = x; self.y = y; self.z = z
        }
        func vector(_ v: V) -> V { x*v.x + y*v.y + z*v.z }
        func point(_ v: V) -> V { origin + vector(v) }
    }
    private static func dot(_ a: V, _ b: V) -> Double {
        a.x*b.x + a.y*b.y + a.z*b.z
    }
    private static func cross(_ a: V, _ b: V) -> V {
        V(a.y*b.z-a.z*b.y, a.z*b.x-a.x*b.z, a.x*b.y-a.y*b.x)
    }
    private static func length(_ a: V) -> Double { sqrt(dot(a,a)) }
    private static func finite(_ a: V) -> Bool {
        a.x.isFinite && a.y.isFinite && a.z.isFinite
    }
    private static func v(_ a: [Float], _ start: Int = 0) -> V {
        V(Double(a[start]),Double(a[start+1]),Double(a[start+2]))
    }
    private static func orthogonal(_ axes: [V]) -> Bool {
        abs(dot(axes[0],axes[1])) < 0.002 &&
        abs(dot(axes[0],axes[2])) < 0.002 &&
        abs(dot(axes[1],axes[2])) < 0.002
    }

    public static func world(_ volumes: CMOriginalUCMCollisionVolumes.Volumes,
                             transform t: Transform) -> [Primitive]? {
        guard finite(t.origin), finite(t.x), finite(t.y), finite(t.z) else { return nil }
        let lengths = [length(t.x),length(t.y),length(t.z)]
        guard lengths.allSatisfy({ $0.isFinite && $0 > 1e-8 }),
              orthogonal([t.x/lengths[0], t.y/lengths[1], t.z/lengths[2]])
            else { return nil }
        var result: [Primitive] = []
        for s in volumes.spheres {
            // A nonuniformly scaled sphere becomes an ellipsoid; do not
            // substitute a guessed inflated sphere for an exact observation.
            guard let lo = lengths.min(), let hi = lengths.max(),
                  hi-lo <= hi*0.002 else { return nil }
            let c = t.point(v(s.center)), radius = Double(s.radius)*hi
            guard finite(c), radius.isFinite, radius > 0 else { return nil }
            result.append(.sphere(center: c, radius: radius))
        }
        for b in volumes.boxes {
            var axes: [V] = []
            var half = v(b.halfExtents)
            for i in 0..<3 {
                let axis = t.vector(v(b.axes, i*3)), size = length(axis)
                guard size.isFinite, size > 1e-8 else { return nil }
                axes.append(axis/size)
                half[i] *= size
            }
            let c = t.point(v(b.center))
            guard orthogonal(axes), finite(half), finite(c),
                  half.x > 0, half.y > 0, half.z > 0 else { return nil }
            result.append(.box(center: c, axes: axes, half: half))
        }
        return result
    }

    public static func intersects(_ a: Primitive, _ b: Primitive) -> Bool {
        switch (a,b) {
        case let (.sphere(c,r),.sphere(d,s)):
            return dot(c-d,c-d) <= (r+s)*(r+s)
        case let (.sphere(c,r),.box(d,axes,h)), let (.box(d,axes,h),.sphere(c,r)):
            let delta = c-d
            var residual = delta
            for i in 0..<3 {
                residual -= axes[i]*max(-h[i],min(h[i],dot(delta,axes[i])))
            }
            return dot(residual,residual) <= r*r
        case let (.box(c,aa,ha),.box(d,bb,hb)):
            // Six face axes plus nine pairwise edge cross products.
            let candidates = aa + bb + aa.flatMap { u in bb.map { cross(u,$0) } }
            for axis in candidates {
                let size = length(axis)
                if size <= 1e-10 { continue }
                let n = axis/size
                let ra = (0..<3).reduce(0.0) { $0 + abs(dot(n,aa[$1]))*ha[$1] }
                let rb = (0..<3).reduce(0.0) { $0 + abs(dot(n,bb[$1]))*hb[$1] }
                if abs(dot(d-c,n)) > ra+rb { return false }
            }
            return true
        }
    }

    public static func intersects(_ a: [Primitive], _ b: [Primitive]) -> Bool {
        a.contains { x in b.contains { intersects(x,$0) } }
    }

    /// nil means unavailable geometry and permits the legacy contact
    /// fallback. A known inactive/retired owner is an empty array, which
    /// must never be resurrected by a residual SceneKit contact.
    public static func linkedZoneDecision(_ source: [Primitive]?,
                                          _ target: [Primitive]?) -> Bool? {
        if source?.isEmpty == true || target?.isEmpty == true { return false }
        guard let source, let target else { return nil }
        return intersects(source, target)
    }
}


/// Material values recovered from the native body setup at
/// 0x455976..0x456EA1. +0x54 is density (sphere/box mass routines
/// 0x48B470/0x48B4A0); +0x68 is bounce and +0x6C is friction
/// (ODE contact surface at 0x428075..0x4280D9).
public enum CMOriginalBodyMaterial {
    // 0x427BA9 -> 0x4869B0 sets the original ODE world Y gravity.
    public static let gravityY = Double(Float(bitPattern: 0xc11cf5c3))
    // SceneKit adapter only; apply the same factor to mass, inertia, and
    // recovered native force/torque. Native ODE values themselves are unscaled.
    public static let massUnit = 1000.0

    public struct Material {
        public let density: Double
        public let bounce: Double
        public let friction: Double
        public let linearDrag: Double
        public let angularDrag: Double
        init(_ density: Double, _ bounce: Double, _ friction: Double,
             _ linearDrag: Double = 0, _ angularDrag: Double = 0) {
            self.density = density; self.bounce = bounce; self.friction = friction
            self.linearDrag = linearDrag; self.angularDrag = angularDrag
        }
    }
    public static func material(for kind: String) -> Material? {
        switch kind {
        case "tmo_rope_cage": return .init(0.4, 0.1, 0.2)
        case "tmo_nail": return .init(0.25, 0.1, 0.2)
        case "tmo_weight": return .init(1, 0.1, 0.3)
        case "tmo_balloon": return .init(0.5, 0.2, 0.5, 0.3, 0.1)
        case "tmo_crate": return .init(0.2, 0.2, 0.3)
        case "tmo_bucket": return .init(0.7, 0.1, 0.2)
        case "tmo_domino": return .init(0.3, 0.1, 0.3)
        case "tmo_heat_dynamite": return .init(0.2, 0.1, 0.3)
        case "tmo_ball_billard", "tmo_ball_steel": return .init(0.7, 0.2, 0.2)
        case "tmo_ball_basket": return .init(0.3, 0.7, 0.3)
        case "tmo_ball_tt": return .init(0.1, 0.9, 0.01, 0.00002)
        case "tmo_ball_tennis": return .init(0.5, 0.7, 0.2)
        case "tmo_ball_beach": return .init(0.1, 0.5, 0.2, 0.007)
        case "tmo_rope_crossbow_arrow": return .init(1, 0.1, 0)
        case "tmo_heat_cannon_ball": return .init(5, 0.2, 0.2)
        case "tmo_heat_rocket_rocket": return .init(2, 0.25, 0, 0.001, 0.01)
        case "tmo_catapult_sling": return .init(100, 0, 0)
        default: return nil
        }
    }

    public struct MassProperties {
        public let nativeMass: Double
        public let nativeInertia: SIMD3<Double>
        // Native 0x42594A zeroes the aggregate. Sphere/box initializers
        // produce zero centers and the setup adds their masses/inertias
        // without translating by the geom offsets. Geom placement is separate.
        public var center: SIMD3<Double> { .zero }
        public var sceneKitMass: Double { nativeMass * massUnit }
        public var sceneKitInertia: SIMD3<Double> { nativeInertia * massUnit }
    }

    /// 0x425A16 uses a sphere mass, whereas 0x425CBC..0x425CEA
    /// passes two full XY dimensions and an exact constant depth of 1.
    /// The original UCM depth remains available for rendered zone queries.
    public static func massProperties(
        material: Material, primitives: [CMOriginalVolumeOverlap.Primitive]
    ) -> MassProperties? {
        var total = 0.0
        var inertia = SIMD3<Double>.zero
        for primitive in primitives {
            let mass: Double
            let i: SIMD3<Double>
            switch primitive {
            case let .sphere(_, r):
                guard r.isFinite, r > 0 else { return nil }
                mass = material.density * (4 * Double.pi / 3) * r*r*r
                i = SIMD3<Double>(repeating: 0.4 * mass*r*r)
            case let .box(_, axes, h):
                guard h.x > 0, h.y > 0, h.z > 0, axes.count == 3,
                      abs(axes[0].z) < 0.002, abs(axes[1].z) < 0.002,
                      abs(abs(axes[2].z)-1) < 0.002 else { return nil }
                let w = 2*h.x, d = 2*h.y
                mass = material.density * w*d
                i = mass/12 * SIMD3<Double>(d*d+1, w*w+1, w*w+d*d)
            }
            guard mass.isFinite, mass > 0, i.x.isFinite, i.y.isFinite, i.z.isFinite,
                  i.x > 0, i.y > 0, i.z > 0 else { return nil }
            total += mass
            inertia += i
        }
        guard total.isFinite, (0.00001...10000).contains(total * massUnit),
              inertia.x.isFinite, inertia.y.isFinite, inertia.z.isFinite,
              inertia.x > 0, inertia.y > 0, inertia.z > 0 else { return nil }
        return MassProperties(nativeMass: total, nativeInertia: inertia)
    }

    /// Stable adapter for the native post-step drag F=-k*v, T=-k*w
    /// (0x4255A8..0x42564D). Avoid reversing velocity on a large dt.
    public static func dragRetention(coefficient: Double, nativeMassOrInertia: Double,
                                     delta: Double) -> Double? {
        guard coefficient.isFinite, coefficient >= 0,
              nativeMassOrInertia.isFinite, nativeMassOrInertia > 0,
              delta.isFinite, delta >= 0, delta <= 0.25 else { return nil }
        return exp(-coefficient * delta / nativeMassOrInertia)
    }

    // 0x4516DF..0x45170A applies world +Y force 1.6 at the
    // selector-4 marker (Wind, registered at 0x42FF94..0x42FFB1),
    // displaced by transformed model +Y times -0.09 (0x45168C).
    public static let balloonNativeLift = Double(Float(bitPattern: 0x3FCCCCCD))
    public static let balloonLiftOffset = Double(Float(bitPattern: 0xBDB851EC))

    public static func balloonLiftPoint(windMarker: SIMD3<Double>,
                                        modelY: SIMD3<Double>) -> SIMD3<Double>? {
        guard [windMarker.x,windMarker.y,windMarker.z,
               modelY.x,modelY.y,modelY.z].allSatisfy(\.isFinite),
              modelY.x*modelY.x + modelY.y*modelY.y + modelY.z*modelY.z > 1e-16
              else { return nil }
        let point = windMarker + modelY * balloonLiftOffset
        return [point.x,point.y,point.z].allSatisfy(\.isFinite) ? point : nil
    }
}
