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
