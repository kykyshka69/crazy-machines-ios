import Foundation

/// Install original PC CML scene documents into the same sandbox used by Play.
/// All 102 records are decoded and validated before the first destination
/// file is changed. Copyrighted scene bytes remain on the user's device.
enum CMOriginalLaboratorySceneInstaller {
    struct Result {
        let total: Int
        let installed: Int
        let existing: Int
    }

    enum ImportError: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            switch self {
            case .invalid(let message): return message
            }
        }
    }

    /// Hash calculation is injected by the iOS caller (CryptoKit), keeping
    /// the archive decoder and file-transaction logic testable with Swift on
    /// Linux without shipping or fabricating an original game scene.
    static func install(_ data: Data, into sceneDirectory: URL,
                        sha256: (Data) -> String) throws -> Result {
        let records = try CMOriginalCMLContainer.read(data)
        guard !records.isEmpty else {
            return Result(total: 0, installed: 0, existing: 0)
        }

        struct Prepared {
            let path: URL
            let bytes: Data
            let index: Int
            let title: String
            let hash: String
        }

        var prepared: [Prepared] = []
        prepared.reserveCapacity(records.count)
        for record in records {
            let sceneBytes = try CMOriginalLZW12.decodeLevelSection(record.payload)
            guard let text = CMOriginalWindows1251.decode(sceneBytes) else {
                throw CMOriginalCMLContainer.DecodeError.invalidText
            }
            let hash = sha256(sceneBytes)
            guard hash.count == 64 && hash.allSatisfy({ $0.isHexDigit }) else {
                throw ImportError.invalid("Invalid original scene digest")
            }
            let json = try CMOriginalSceneTextParser.export(
                text, index: record.index, title: record.title, sceneSHA256: hash
            )
            let filename = String(format: "level-%03d.json", record.index)
            prepared.append(Prepared(
                path: sceneDirectory.appendingPathComponent(filename),
                bytes: json, index: record.index, title: record.title, hash: hash
            ))
        }

        // Do not replace an older imported level, even when its filename
        // matches. Compare original scene identity rather than JSON ordering.
        var newDocuments: [Prepared] = []
        var existing = 0
        for item in prepared {
            if FileManager.default.fileExists(atPath: item.path.path) {
                let oldBytes = try Data(contentsOf: item.path)
                let old = try CMOriginalSceneDocument.read(oldBytes)
                guard old.index == item.index,
                      old.sceneSHA256.caseInsensitiveCompare(item.hash) == .orderedSame,
                      old.title == item.title else {
                    throw ImportError.invalid(
                        "A different original level already exists: \(item.path.lastPathComponent)"
                    )
                }
                existing += 1
            } else {
                newDocuments.append(item)
            }
        }

        try FileManager.default.createDirectory(
            at: sceneDirectory, withIntermediateDirectories: true
        )

        // Keep a retryable import: if the device runs out of storage midway,
        // roll back only files created by this invocation, never older levels.
        var written: [URL] = []
        do {
            for item in newDocuments {
                try item.bytes.write(to: item.path, options: .atomic)
                written.append(item.path)
            }
        } catch {
            for file in written {
                try? FileManager.default.removeItem(at: file)
            }
            throw error
        }
        return Result(total: records.count,
                      installed: newDocuments.count, existing: existing)
    }
}
