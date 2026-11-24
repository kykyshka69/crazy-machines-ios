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
