import Foundation
import CryptoKit

/// Installs a single user-owned local asset pack into the app's private sandbox.
/// The pack is assembled off-device from the user's original Windows installation.
/// No copyrighted game resources are checked into the iOS source repository.
///
/// Binary format: ASCII "CMASSET1", UInt32 LE entry count, then repeated:
/// UInt16 LE UTF-8 basename length, basename, UInt32 LE payload length,
/// 32 SHA-256 bytes, payload. All records are checked before any file is written.
enum CMOriginalAssetPackImporter {
    struct Result {
        let installed: Int
        let existing: Int
        let models: Int
        let textures: Int
        let levels: Int
    }

    enum PackError: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            if case .invalid(let detail) = self { return detail }
            return "Invalid Crazy Machines pack"
        }
    }

    private struct Entry {
        let name: String
        let kind: String
        let bytes: Data
    }

    static func install(_ data: Data) throws -> Result {
        guard data.count <= 128 * 1024 * 1024 else {
            throw PackError.invalid("Original game pack exceeds the 128 MB safety limit")
        }
        var offset = 0
        func take(_ length: Int) throws -> Data {
            guard length >= 0, offset <= data.count,
                  length <= data.count - offset else {
                throw PackError.invalid("Truncated original game pack")
            }
            defer { offset += length }
            return data.subdata(in: offset..<(offset + length))
        }
        func uint16() throws -> Int {
            let raw = try take(2)
            return Int(raw[raw.startIndex]) | (Int(raw[raw.startIndex + 1]) << 8)
        }
        func uint32() throws -> Int {
            let raw = try take(4)
            return Int(raw[raw.startIndex])
                | (Int(raw[raw.startIndex + 1]) << 8)
                | (Int(raw[raw.startIndex + 2]) << 16)
                | (Int(raw[raw.startIndex + 3]) << 24)
        }

        guard try take(8) == Data("CMASSET1".utf8) else {
            throw PackError.invalid("Not a Crazy Machines original asset pack")
        }
        let count = try uint32()
        guard count > 0 && count <= 1024 else {
            throw PackError.invalid("Invalid game pack entry count")
        }
        let allowed = Set(["ucm", "tga", "cml", "json", "fsc", "vsc"])
        var entries: [Entry] = []
        entries.reserveCapacity(count)
        var names = Set<String>()
        var models = 0
        var textures = 0
        var levels = 0

        for _ in 0..<count {
            let nameLength = try uint16()
            guard (1...255).contains(nameLength),
                  let name = String(data: try take(nameLength), encoding: .utf8),
                  !name.isEmpty, name != ".", name != "..",
                  !name.contains("/") && !name.contains("\\"),
                  !name.contains(":") && !name.contains("\0"),
                  !name.contains("\r") && !name.contains("\n") else {
                throw PackError.invalid("Invalid original resource name")
            }
            let kind = (name as NSString).pathExtension.lowercased()
            guard allowed.contains(kind), names.insert(name.lowercased()).inserted else {
                throw PackError.invalid("Unexpected or duplicate resource in game pack")
            }
            let length = try uint32()
            guard length > 0 && length <= 64 * 1024 * 1024 else {
                throw PackError.invalid("Invalid original resource length")
            }
            let expectedHash = try take(32)
            let bytes = try take(length)
            let actualHash = Data(SHA256.hash(data: bytes))
            guard actualHash == expectedHash else {
                throw PackError.invalid("Checksum mismatch: \(name)")
            }
            if kind == "ucm" {
                guard bytes.prefix(4) == Data("UCM1".utf8),
                      (try? CMUCMModel(data: bytes)) != nil else {
                    throw PackError.invalid("Invalid original 3D model: \(name)")
                }
                models += 1
            } else if kind == "tga" {
                guard (try? CMTGATexture(data: bytes)) != nil else {
                    throw PackError.invalid("Invalid original texture: \(name)")
                }
                textures += 1
            } else if kind == "fsc" && name.lowercased() == "elements.fsc" {
                guard let source = try? CMOriginalElementsScriptDecoder.decode(bytes),
                      let scripts = try? CMOriginalElementsTemplateCatalog
                        .parse(decodedBytes: source), scripts.count >= 100 else {
                    throw PackError.invalid("Invalid original elements.fsc")
                }
            } else if kind == "vsc" {
                // The original game uses a distinct 8-byte VSC key,
                // not the 20-byte encrypted FSC/CML laboratory key.
                // Reject malformed scripts before installing any files.
                guard (try? CMOriginalVSCDecoder.read(bytes)) != nil else {
                    throw PackError.invalid("Invalid original Windows Value Script: \(name)")
                }
            } else if kind == "json" {
                guard (try? CMOriginalSceneDocument.read(bytes)) != nil else {
                    throw PackError.invalid("Invalid original level: \(name)")
                }
                levels += 1
            }
            entries.append(Entry(name: name, kind: kind, bytes: bytes))
        }
        guard offset == data.count else {
            throw PackError.invalid("Trailing bytes after original game pack")
        }

        // Some genuine PC installations have only the encrypted Professor
        // Laboratory .cml and the UCM/TGA assets. Decode 102 scenes BEFORE
        // writing the pack so importing them on iPhone works without a
        // separate desktop JSON export. Existing packs containing scene JSON
        // (including the user's 445-entry original pack) retain their exact
        // bytes and are never re-exported from CML.
        if levels == 0 {
            let labs = entries.filter { $0.kind == "cml" }.map {
                (name: $0.name, bytes: $0.bytes)
            }
            if !labs.isEmpty {
                let prepared = try CMOriginalPackScenePlanner.prepare(
                    laboratories: labs,
                    sha256: { scene in
                        SHA256.hash(data: scene)
                            .map { String(format: "%02x", $0) }.joined()
                    }
                )
                for item in prepared {
                    guard names.insert(item.name.lowercased()).inserted else {
                        throw PackError.invalid(
                            "Conflicting decoded original level: \(item.name)")
                    }
                    entries.append(Entry(name: item.name,
                                         kind: "json", bytes: item.bytes))
                    levels += 1
                }
            }
        }

        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let original = support.appendingPathComponent("OriginalGame", isDirectory: true)
        let scenes = support.appendingPathComponent("OriginalScenes", isDirectory: true)
        try FileManager.default.createDirectory(at: original, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: scenes, withIntermediateDirectories: true)

        // Reject conflicting on-device files BEFORE any imports. Existing
        // matching assets are harmless and permit retrying interrupted imports.
        for entry in entries {
            let folder = entry.kind == "json" ? scenes : original
            let target = folder.appendingPathComponent(entry.name)
            if FileManager.default.fileExists(atPath: target.path),
               try Data(contentsOf: target) != entry.bytes {
                throw PackError.invalid("Different on-device file already exists: \(entry.name)")
            }
        }
        var installed = 0
        var existing = 0
        var written: [URL] = []
        do {
            for entry in entries {
                let folder = entry.kind == "json" ? scenes : original
                let target = folder.appendingPathComponent(entry.name)
                if FileManager.default.fileExists(atPath: target.path) {
                    existing += 1
                } else {
                    try entry.bytes.write(to: target, options: .atomic)
                    written.append(target)
                    installed += 1
                }
            }
        } catch {
            // A disk-full or other write failure must not strand a partial
            // 102-level import. Never remove pre-existing original files.
            for path in written { try? FileManager.default.removeItem(at: path) }
            throw error
        }
        return Result(installed: installed, existing: existing,
                      models: models, textures: textures, levels: levels)
    }
}
