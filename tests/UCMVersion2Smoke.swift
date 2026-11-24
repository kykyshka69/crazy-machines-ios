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
        // Both trailer table lengths are attacker-controlled; neither may
        // cause the decoder to read beyond the end of the input buffer.
        oversized = fixture(first: 0, second: 0)
        put32(&oversized, 204, UInt32.max)
        rejects(oversized)
        oversized = fixture(first: 0, second: 0)
        put32(&oversized, 200, UInt32.max)
        put32(&oversized, 204, UInt32.max)
        rejects(oversized)
        // Copyright-free two-frame UCM layout. Both groups must
        // address the same triangle and share identical UV attributes.
        var morph = Data(repeating: 0, count: 92 + 12 + 6 * 32)
        morph.replaceSubrange(0..<4, with: [85, 67, 77, 49])
        put32(&morph, 4, 1)
        put32(&morph, 72, 2)
        put32(&morph, 76, 1)
        put32(&morph, 80, 3)
        put32(&morph, 92, 0)
        put32(&morph, 96, 1)
        put32(&morph, 100, 2)
        put32(&morph, 104 + 3*32 + 4, Float(0.5).bitPattern)
        let paired = try CMUCMModel(data: morph)
        precondition(paired.vertexGroupCount == 2 && paired.verticesPerGroup == 3)
        precondition(paired.pairedMorphVertexData(group: 0)?.count == 96)
        precondition(paired.pairedMorphVertexData(group: 1)?.count == 96)
        precondition(paired.pairedMorphVertexData(group: 0) != paired.pairedMorphVertexData(group: 1))
        precondition(paired.pairedMorphVertexData(group: 2) == nil)
        var badUV = morph
        put32(&badUV, 104 + 3*32 + 24, Float(0.25).bitPattern)
        let badUVModel = try CMUCMModel(data: badUV)
        precondition(badUVModel.pairedMorphVertexData(group: 0) == nil)
        var badIndex = morph
        put32(&badIndex, 92, 3)
        let badIndexModel = try CMUCMModel(data: badIndex)
        precondition(badIndexModel.pairedMorphVertexData(group: 0) == nil)
        let single = try CMUCMModel(data: fixture(first: 0, second: 0))
        precondition(single.pairedMorphVertexData(group: 0) == nil)
        print("PASS: UCM v2 trailer variants and malformed lengths")
    }
}
