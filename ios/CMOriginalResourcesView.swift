import SwiftUI
import UniformTypeIdentifiers

/// Imports user-owned original Windows game resources into the iOS app sandbox.
/// This does not pretend that proprietary CML levels are decoded or playable.
struct CMOriginalResourcesView: View {
    @State private var importing = false
    @State private var entries: [ResourceEntry] = []
    @State private var message = "Import extracted original .cml, .ucm or .tga files."
    private let allowed = Set(["cml", "ucm", "tga", "ogg", "wav", "vsc", "fsc"])

    struct ResourceEntry: Identifiable {
        let name: String
        let kind: String
        let bytes: Int
        var id: String { kind + ":" + name }
    }

    private var storage: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OriginalGame", isDirectory: true)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Original Crazy Machines resources")
                        .font(.headline)
                    Text("These files remain private on this iPhone. The CML level format is not decoded yet.")
                        .font(.caption)
                    Button("Import original game files") { importing = true }
                    Text(message).font(.caption).foregroundStyle(.secondary)
                }
                Section("Imported files (\(entries.count))") {
                    ForEach(entries) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.name).lineLimit(1)
                                Text(entry.kind.uppercased()).font(.caption)
                            }
                            Spacer()
                            Text(ByteCountFormatter.string(fromByteCount: Int64(entry.bytes), countStyle: .file))
                                .font(.caption.monospacedDigit())
                        }
                    }
                }
            }
            .navigationTitle("Original files")
            .onAppear(perform: reload)
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    importFiles(urls)
                case .failure(let error):
                    message = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func reload() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: storage, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]
        ) else {
            entries = []
            return
        }
        entries = files.compactMap { url in
            let ext = url.pathExtension.lowercased()
            guard allowed.contains(ext),
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return nil }
            return ResourceEntry(name: url.lastPathComponent, kind: ext, bytes: size)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func importFiles(_ urls: [URL]) {
        do {
            try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        } catch {
            message = "Storage unavailable: \(error.localizedDescription)"
            return
        }
        var imported = 0
        var rejected = 0
        for url in urls {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let ext = url.pathExtension.lowercased()
            guard allowed.contains(ext) else { rejected += 1; continue }
            do {
                let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values.isRegularFile == true,
                      let size = values.fileSize, size > 0, size <= 64 * 1024 * 1024 else {
                    rejected += 1
                    continue
                }
                let data = try Data(contentsOf: url)
                guard data.count == size else { rejected += 1; continue }
                if ext == "ucm" && data.prefix(4) != Data([85, 67, 77, 49]) {
                    rejected += 1
                    continue
                }
                let destination = storage.appendingPathComponent(url.lastPathComponent)
                // Never silently overwrite a different original file with the same name.
                if FileManager.default.fileExists(atPath: destination.path) {
                    if (try? Data(contentsOf: destination)) == data { continue }
                    rejected += 1
                    continue
                }
                try data.write(to: destination, options: .atomic)
                imported += 1
            } catch {
                rejected += 1
            }
        }
        reload()
        message = "Imported \(imported) original files; skipped \(rejected)."
    }
}
