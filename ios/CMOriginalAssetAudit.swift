import Foundation

/// Read-only audit of user-imported original PC model files.
/// A filename match is not sufficient: each UCM must parse as renderable
/// geometry before it can be counted as ready for the first real level.
enum CMOriginalAssetAudit {
    enum Status: String, Sendable {
        case ready
        case missing
        case ambiguous
        case invalidReference
        case unreadable
        case tooLarge
        case invalidGeometry
        case invalidTexture
    }

    struct Entry: Sendable, Identifiable {
        let reference: String
        let status: Status
        let fileName: String?
        let vertices: Int
        let triangles: Int

        var id: String { reference }
    }

    struct Report: Sendable {
        let entries: [Entry]

        var readyCount: Int { entries.filter { $0.status == .ready }.count }
        var problemEntries: [Entry] { entries.filter { $0.status != .ready } }
        var allReady: Bool { !entries.isEmpty && problemEntries.isEmpty }
    }

    private struct MeshCheck {
        let status: Status
        let vertices: Int
        let triangles: Int
    }

    static func inspect(modelNames: [String], directory: URL) -> Report {
        let index = CMOriginalModelResolver.AssetIndex(directory: directory)
        var cachedMeshes: [URL: MeshCheck] = [:]
        var cachedTextures: [URL: Status] = [:]
        let textureURLs = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        var texturesByName: [String: [URL]] = [:]
        for url in textureURLs where url.pathExtension.lowercased() == "tga" {
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey])
                .isRegularFile) == true else { continue }
            let key = url.deletingPathExtension().lastPathComponent.lowercased()
            texturesByName[key, default: []].append(url)
        }
        var entries: [Entry] = []
        var seen = Set<String>()

        for reference in modelNames where seen.insert(reference.lowercased()).inserted {
            // Five 3DO references are PC glow/effect billboards, not UCM
            // shapes. Requiring a nonexistent .ucm here previously blocked
            // authentic playback of 48/102 perfectly intact PC scenes.
            // Validate their ACTUAL TGA images, never invent geometry.
            if let effect = CMOriginalEffectBillboard.specification(for: reference) {
                let matches = texturesByName[effect.textureName] ?? []
                let status: Status
                if matches.isEmpty {
                    status = .missing
                } else if matches.count > 1 {
                    status = .ambiguous
                } else if let cached = cachedTextures[matches[0]] {
                    status = cached
                } else {
                    status = checkTexture(at: matches[0])
                    cachedTextures[matches[0]] = status
                }
                entries.append(Entry(
                    reference: reference, status: status,
                    fileName: matches.count == 1 ? matches[0].lastPathComponent : nil,
                    vertices: 0, triangles: 0
                ))
                continue
            }
            switch index.resolution(for: reference) {
            case .missing:
                entries.append(Entry(reference: reference, status: .missing,
                                     fileName: nil, vertices: 0, triangles: 0))
            case .ambiguous:
                entries.append(Entry(reference: reference, status: .ambiguous,
                                     fileName: nil, vertices: 0, triangles: 0))
            case .invalidReference:
                entries.append(Entry(reference: reference, status: .invalidReference,
                                     fileName: nil, vertices: 0, triangles: 0))
            case .found(let url):
                let checked: MeshCheck
                if let saved = cachedMeshes[url] {
                    checked = saved
                } else {
                    checked = checkMesh(at: url)
                    cachedMeshes[url] = checked
                }
                entries.append(Entry(reference: reference, status: checked.status,
                                     fileName: url.lastPathComponent,
                                     vertices: checked.vertices,
                                     triangles: checked.triangles))
            }
        }
        return Report(entries: entries)
    }

    private static func checkTexture(at url: URL) -> Status {
        guard let info = try? url.resourceValues(
            forKeys: [.isRegularFileKey, .fileSizeKey]),
              info.isRegularFile == true, let size = info.fileSize,
              size > 0 else { return .unreadable }
        guard size <= 64 * 1024 * 1024 else { return .tooLarge }
        guard let bytes = try? Data(contentsOf: url), bytes.count == size
        else { return .unreadable }
        return (try? CMTGATexture(data: bytes)) != nil ? .ready : .invalidTexture
    }

    private static func checkMesh(at url: URL) -> MeshCheck {
        guard let info = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
              info.isRegularFile == true,
              let size = info.fileSize, size > 0 else {
            return MeshCheck(status: .unreadable, vertices: 0, triangles: 0)
        }
        // Match the resource importer's per-file limit; don't allocate
        // arbitrary large user-selected files on the iPhone.
        guard size <= 64 * 1024 * 1024 else {
            return MeshCheck(status: .tooLarge, vertices: 0, triangles: 0)
        }
        guard let bytes = try? Data(contentsOf: url), bytes.count == size else {
            return MeshCheck(status: .unreadable, vertices: 0, triangles: 0)
        }
        guard let mesh = try? CMUCMModel(data: bytes) else {
            return MeshCheck(status: .invalidGeometry, vertices: 0, triangles: 0)
        }
        return MeshCheck(status: .ready, vertices: mesh.vertexCount,
                         triangles: mesh.triangleCount)
    }
}
