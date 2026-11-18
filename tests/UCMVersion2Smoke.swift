import Foundation

/// Exercise UCM1 version 2's two variable-length trailer tables without game assets.
@main
struct UCMVersion2Smoke {
    static func put32(_ data: inout Data, _ offset: Int, _ value: UInt32) {
        for byte in 0..<4 {
            data[offset + byte] = UInt8(truncatingIfNeeded: value >> (byte * 8))
        }
    }

    static func fixture(first: UInt32, second: UInt32) -> Data {
        var data = Data(repeating: 0, count: 92 + 12 + 3 * 32 + 8)
        data.replaceSubrange(0..<4, with: [85, 67, 77, 49])
        put32(&data, 4, 2)
        put32(&data, 72, 1)
        put32(&data, 76, 1)
        put32(&data, 80, 3)
        put32(&data, 84, 0)
        put32(&data, 92, 0)
        put32(&data, 96, 1)
        put32(&data, 100, 2)
        let trailer = 92 + 12 + 3 * 32
        put32(&data, trailer, first)
        put32(&data, trailer + 4, second)
        data.append(Data(repeating: 0, count: Int(first) * 16 + Int(second) * 60))
        return data
    }

    static func rejects(_ data: Data) {
        do {
            _ = try CMUCMModel(data: data)
            fatalError("Accepted malformed UCM v2")
        } catch is CMUCMError {
            // Expected.
        } catch {
            fatalError("Unexpected error: \(error)")
        }
    }

    static func main() throws {
        for (first, second) in [(UInt32(0), UInt32(0)),
                                (UInt32(1), UInt32(0)),
                                (UInt32(0), UInt32(1)),
                                (UInt32(2), UInt32(3))] {
            let valid = fixture(first: first, second: second)
            let model = try CMUCMModel(data: valid)
            precondition(model.vertexCount == 3 && model.triangleCount == 1)
            rejects(Data(valid.dropLast()))
            var extra = valid
            extra.append(0)
            rejects(extra)
        }
        var oversized = fixture(first: 0, second: 0)
        put32(&oversized, 200, UInt32.max)
        rejects(oversized)
        print("PASS: UCM v2 trailer variants and malformed lengths")
    }
}
