import Foundation
#if canImport(Metal)
import Metal
#endif

public enum CMUCMError: Error {
    case invalidHeader, unsupportedVersion, truncated, invalidGeometry, invalidIndex, invalidLength
}

/// Geometry-only UCM1 reader. The material and additional record semantics remain unresolved.
public struct CMUCMModel {
    public let vertexData: Data
    public let indices: [UInt16]
    public let vertexCount: Int
    public let triangleCount: Int

    public init(data: Data) throws {
        func u32(_ offset: Int) throws -> UInt32 {
            guard offset >= 0, offset <= data.count - 4 else { throw CMUCMError.truncated }
            return data.withUnsafeBytes { raw in
                let bytes = raw.bindMemory(to: UInt8.self)
                let a = UInt32(bytes[offset])
                let b = UInt32(bytes[offset + 1]) << 8
                let c = UInt32(bytes[offset + 2]) << 16
                let d = UInt32(bytes[offset + 3]) << 24
                return a | b | c | d
            }
        }
        guard data.count >= 92, data.prefix(4) == Data([85, 67, 77, 49]) else {
            throw CMUCMError.invalidHeader
        }
        let version = try u32(4)
        guard version == 1 || version == 2 else { throw CMUCMError.unsupportedVersion }
        let groups = Int(try u32(72)), faces = Int(try u32(76))
        let verticesPerGroup = Int(try u32(80)), records = Int(try u32(84))
        guard groups > 0, faces > 0, verticesPerGroup > 0, groups <= 10000,
              verticesPerGroup <= 100000, faces <= 1000000, records <= 1000000 else {
            throw CMUCMError.invalidGeometry
        }
        func mul(_ a: Int, _ b: Int) throws -> Int {
            let (v, overflow) = a.multipliedReportingOverflow(by: b)
            if overflow { throw CMUCMError.invalidGeometry }
            return v
        }
        func add(_ a: Int, _ b: Int) throws -> Int {
            let (v, overflow) = a.addingReportingOverflow(b)
            if overflow { throw CMUCMError.invalidGeometry }
            return v
        }
        let count = try mul(groups, verticesPerGroup)
        let indexCount = try mul(faces, 3)
        let indexBytes = try mul(indexCount, 4)
        let vertexBytes = try mul(count, 32)
        let vertexStart = try add(92, indexBytes)
        var cursor = try add(vertexStart, vertexBytes)
        guard cursor <= data.count else { throw CMUCMError.truncated }
        var parsedIndices: [UInt16] = []
        parsedIndices.reserveCapacity(indexCount)
        for i in 0..<indexCount {
            let value = try u32(92 + i * 4)
            guard Int(value) < count && value <= UInt32(UInt16.max) else { throw CMUCMError.invalidIndex }
            parsedIndices.append(UInt16(value))
        }
        cursor = try add(cursor, try mul(records, 16))
        cursor = try add(cursor, try mul(try mul(groups, records), 64))
        guard cursor <= data.count else { throw CMUCMError.truncated }
        if version == 2 {
            let a = Int(try u32(cursor)), b = Int(try u32(cursor + 4))
            cursor = try add(cursor, 8)
            cursor = try add(cursor, try mul(a, 16))
            cursor = try add(cursor, try mul(b, 60))
        }
        guard cursor == data.count else { throw CMUCMError.invalidLength }
        self.vertexData = data.subdata(in: vertexStart..<(vertexStart + vertexBytes))
        self.indices = parsedIndices
        self.vertexCount = count
        self.triangleCount = faces
    }

#if canImport(Metal)
    public func makeVertexBuffer(device: MTLDevice) throws -> MTLBuffer {
        guard !vertexData.isEmpty else { throw CMUCMError.invalidGeometry }
        let buffer = vertexData.withUnsafeBytes { bytes -> MTLBuffer? in
            guard let base = bytes.baseAddress else { return nil }
            return device.makeBuffer(bytes: base, length: bytes.count, options: [])
        }
        guard let buffer else { throw CMUCMError.invalidGeometry }
        return buffer
    }

    public func makeIndexBuffer(device: MTLDevice) throws -> MTLBuffer {
        guard !indices.isEmpty else { throw CMUCMError.invalidGeometry }
        let buffer = indices.withUnsafeBytes { bytes -> MTLBuffer? in
            guard let base = bytes.baseAddress else { return nil }
            return device.makeBuffer(bytes: base, length: bytes.count, options: [])
        }
        guard let buffer else { throw CMUCMError.invalidGeometry }
        return buffer
    }
#endif
}
