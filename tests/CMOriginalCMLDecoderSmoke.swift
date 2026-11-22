import Foundation

/// Original byte stream decoder regression using exclusively synthetic data.
@main
enum CMOriginalCMLDecoderSmoke {
    static let key = Array("930%&g/2ANUBIS=!s?p$".utf8)

    static func encodeFrame(_ payload: [UInt8]) -> [UInt8] {
        // Independent inverse of the Windows decoder, as used in Python tests.
        var data = key + payload
        let control = Array(key.reversed())
        for i in stride(from: control.count - 2, through: 0, by: -2) {
            let signed = Int(Int8(bitPattern: control[i]))
            let parameter = control[i+1]
            switch signed % 3 {
            case 0: data.reverse()
            case 1:
                let length = data.count
                for j in data.indices {
                    data[j] = data[j] &+ parameter &+ UInt8(truncatingIfNeeded: length+j)
                }
            case 2:
                if data.count > 1 {
                    for j in 1..<data.count { data[j] = data[j] &+ data[j-1] }
                }
            default: break
            }
        }
        if data.count > 1 {
            for j in 1..<data.count { data[j] = data[j] &+ data[j-1] }
        }
        return data
    }

    static func le32(_ value: UInt32) -> [UInt8] {
        [UInt8(truncatingIfNeeded: value), UInt8(truncatingIfNeeded: value >> 8),
         UInt8(truncatingIfNeeded: value >> 16), UInt8(truncatingIfNeeded: value >> 24)]
    }

    static func pack12(_ source: [Int]) -> [UInt8] {
        var codes = source
        if codes.count % 2 != 0 { codes.append(0) }
        var data: [UInt8] = []
        for i in stride(from: 0, to: codes.count, by: 2) {
            let a = codes[i], b = codes[i+1]
            data += [UInt8(a >> 4), UInt8(((a & 15) << 4) | (b >> 8)), UInt8(b & 255)]
        }
        return data
    }

    static func syntheticLab(recordCount: UInt32, scene: [UInt8]? = nil) -> Data {
        var bytes: [UInt8] = encodeFrame(le32(recordCount)) +
            encodeFrame(Array(repeating: 0, count: 80)) +
            encodeFrame([0, 0, 0, 0])
        bytes += Array(repeating: 0, count: 256 - bytes.count)
        if let scene {
            let packed = pack12(scene.map(Int.init) + [4095])
            let payload = le32(UInt32(packed.count)) + packed
            let titleCP1251: [UInt8] = [0xCF, 0xF0, 0xE8, 0xE2, 0xE5, 0xF2]
            bytes += encodeFrame([0]) + encodeFrame(le32(UInt32(payload.count))) +
                encodeFrame(titleCP1251 + Array(repeating: 0, count: 74)) +
                encodeFrame(payload)
        }
        return Data(bytes)
    }

    static func main() throws {
        let abcSHA = CMOriginalSHA256.digest(Array("abc".utf8))
            .map { String(format: "%02x", $0) }.joined()
        precondition(abcSHA ==
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")

        // An independently generated Python-reference encoded 4-byte frame.
        let pythonFrame = Array<UInt8>([
            0x00, 0x32, 0x83, 0xD8, 0x11, 0x01, 0x7A, 0x8D,
            0x11, 0xDE, 0xD9, 0xF2, 0x1E, 0x3D, 0x34, 0xF0,
            0x46, 0xED, 0xEC, 0x14, 0x65, 0x91, 0x25, 0xAB
        ])
        precondition(encodeFrame([1, 0, 0, 0]) == pythonFrame)
        let fromReference = try CMOriginalCMLDecoder.decodeFrame(pythonFrame, size: 4)
        precondition(fromReference == [1, 0, 0, 0])
        for length in [0, 1, 4, 80, 1755, 6070] {
            let payload = (0..<length).map { UInt8(truncatingIfNeeded: $0 * 17 + 13) }
            let decoded = try CMOriginalCMLDecoder.decodeFrame(
                encodeFrame(payload), size: length
            )
            precondition(decoded == payload)
        }

        let scene = "level\r\n{\r\ntmo_board\r\n{\r\n" +
            "POS 1, 2, 3\r\nPOSREL 0.25, -0.5, 0\r\n" +
            "ROT xyz 0, 0, 1\r\nGOAL 1\r\n" +
            "3DO to_board\r\n{\r\n}\r\n}\r\n}\r\n"
        let raw = Array(scene.utf8)
        let lab = syntheticLab(recordCount: 1, scene: raw)
        let records = try CMOriginalCMLDecoder.readRecords(lab)
        precondition(records.count == 1 && records[0].sceneBytes == raw)
        let documents = try CMOriginalCMLDecoder.decode(lab)
        precondition(documents.count == 1)
        let first = documents[0]
        precondition(first.title == "Привет")
        precondition(first.index == 1)
        precondition(first.root.children.count == 1)
        precondition(first.root.children[0].models == ["to_board"])
        precondition(first.root.children[0].position == [1, 2, 3])
        precondition(first.root.children[0].goalRaw == "1")
        precondition(first.sceneSHA256 ==
            CMOriginalSHA256.digest(raw).map { String(format: "%02x", $0) }.joined())

        // The same validated native documents must roundtrip through the
        // original-level browser's private JSON store, without overwrites.
        let storage = FileManager.default.temporaryDirectory
            .appendingPathComponent("cm-native-cml-" + UUID().uuidString,
                                    isDirectory: true)
        defer { try? FileManager.default.removeItem(at: storage) }
        let initial = try CMOriginalCMLStorage.save(documents, to: storage)
        precondition(initial.saved == 1 && initial.conflicting == 0)
        let savedFile = storage.appendingPathComponent("level-001.json")
        let persisted = try CMOriginalSceneDocument.read(Data(contentsOf: savedFile))
        precondition(persisted.sceneSHA256 == first.sceneSHA256)
        precondition(persisted.root.children[0].models == ["to_board"])
        let duplicate = try CMOriginalCMLStorage.save(documents, to: storage)
        precondition(duplicate.saved == 0 && duplicate.alreadyPresent == 1)
        let emptyLaboratory = try CMOriginalCMLDecoder.decode(syntheticLab(recordCount: 0))
        precondition(emptyLaboratory.isEmpty)

        var corrupted = Array(lab)
        corrupted[0] ^= 0x80
        do {
            _ = try CMOriginalCMLDecoder.decode(Data(corrupted))
            fatalError("Accepted corrupted CML frame")
        } catch CMOriginalCMLDecoder.DecodeError.invalidFrame { }

        let literalPlusDictionary = try CMOriginalCMLDecoder.decompress12Bit(
            pack12([65, 66, 256, 4095]))
        precondition(literalPlusDictionary == Array("ABAB".utf8))
        do {
            _ = try CMOriginalCMLDecoder.decompress12Bit(pack12([65, 66]))
            fatalError("Accepted stream without LZW terminator")
        } catch CMOriginalCMLDecoder.DecodeError.invalidLevelStream { }

        print("PASS: native CML framing, original LZW, CP1251 and scene parsing")
    }
}
