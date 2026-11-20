import SwiftUI
import UniformTypeIdentifiers

/// Imports user-owned original Windows game resources into the iOS app sandbox.
/// The separate Original levels tab displays locally exported original scenes; physics is not yet playable.
struct CMOriginalResourcesView: View {
    @State private var importing = false
    @State private var importingFolder = false
    @State private var selectedCML: ResourceEntry?
    @State private var selectedProbe: CMOriginalCMLProbe?
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
                    Text("Original CML decoding and private scene export are available through the project tools. Import the exported JSON scenes in Original levels; original physics is not playable yet.")
                        .font(.caption)
                    Button("Import original game files") { importing = true }
                    Button("Import entire extracted models folder") { importingFolder = true }
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
                        .contentShape(Rectangle())
                        .onTapGesture { inspectCML(entry) }
                    }
                }
            }
            .navigationTitle("Original files")
            .sheet(item: $selectedCML) { entry in
                NavigationStack {
                    List {
                        Text(entry.name).font(.headline)
                        if let probe = selectedProbe {
                            LabeledContent("Bytes", value: String(probe.byteCount))
                            LabeledContent("Zero bytes", value: String(probe.zeroByteCount))
                            Section("First 32 bytes (hex)") {
                                Text(probe.headerHex).font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                            Section("ASCII clues (not decoded levels)") {
                                ForEach(probe.asciiClues, id: \.self) { clue in
                                    Text(clue).font(.system(.caption, design: .monospaced))
                                }
                            }
                        }
                    }
                    .navigationTitle("CML inspection")
                    .toolbar { Button("Close") { selectedCML = nil } }
                }
            }

            .onAppear(perform: reload)
            .fileImporter(isPresented: $importingFolder, allowedContentTypes: [.folder]) { result in
                switch result {
                case .success(let folder):
                    importFolder(folder)
                case .failure(let error):
                    message = "Folder import failed: \(error.localizedDescription)"
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    importFiles(urls)
                case .failure(let error):
                    message = "Import failed: \(error.localizedDescription)"
                }
            }
        }
    }

    private func inspectCML(_ entry: ResourceEntry) {
        guard entry.kind == "cml" else { return }
        let path = storage.appendingPathComponent(entry.name)
        guard let data = try? Data(contentsOf: path) else {
            message = "Cannot read original CML file"
            return
        }
        selectedProbe = CMOriginalCMLProbe(data: data)
        selectedCML = entry
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
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  values.isRegularFile == true,
                  let size = values.fileSize, size > 0, size <= 64 * 1024 * 1024 else { return nil }
            return ResourceEntry(name: url.lastPathComponent, kind: ext, bytes: size)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func importFolder(_ folder: URL) {
        let access = folder.startAccessingSecurityScopedResource()
        defer { if access { folder.stopAccessingSecurityScopedResource() } }
        guard let enumerator = FileManager.default.enumerator(
            at: folder, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            message = "Unable to read the selected folder"
            return
        }
        var files: [URL] = []
        for case let url as URL in enumerator {
            if allowed.contains(url.pathExtension.lowercased()) {
                files.append(url)
            }
            if files.count > 10000 {
                message = "Folder exceeds the 10,000 resource safety limit"
                return
            }
        }
        importFiles(files)
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
                if ext == "ucm" {
                    // Reject truncated or malformed meshes before they reach
                    // SceneKit. The parser validates indices and finite floats.
                    guard (try? CMUCMModel(data: data)) != nil else {
                        rejected += 1
                        continue
                    }
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
