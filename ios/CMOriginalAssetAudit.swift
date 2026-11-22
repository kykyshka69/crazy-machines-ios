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
        var entries: [Entry] = []
        var seen = Set<String>()

        for reference in modelNames where seen.insert(reference.lowercased()).inserted {
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
