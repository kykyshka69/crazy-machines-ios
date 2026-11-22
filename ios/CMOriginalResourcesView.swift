import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

/// Imports user-owned original Windows game resources into the iOS app sandbox.
/// Imported PC laboratories are decoded into the same original levels used by Play.
struct CMOriginalResourcesView: View {
    @State private var importing = false
    @State private var importingFolder = false
    @State private var importingPack = false
    @State private var installingPack = false
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

    private var sceneStorage: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OriginalScenes", isDirectory: true)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Original Crazy Machines resources")
                        .font(.headline)
                    Text("Install your private CrazyMachines_Original_102Levels.cmassets pack to load 160 original models, 181 textures and all 102 original level scenes at once. Original game physics is still being reconstructed.")
                        .font(.caption)
                    Button("Install original game pack (102 levels)") { importingPack = true }
                        .accessibilityIdentifier("cm.original.import-pack")
                        .disabled(installingPack)
                    if installingPack {
                        ProgressView("Checking and installing original game files…")
                            .accessibilityIdentifier("cm.original.pack-installing")
                    }
                    Button("Import original game files") { importing = true }
                        .disabled(installingPack)
                    Button("Import entire extracted models folder") { importingFolder = true }
                        .disabled(installingPack)
                    Button("Decode levels from saved CML files") { decodeSavedLaboratories() }
                        .disabled(installingPack)
                        .accessibilityIdentifier("cm.original.decode-saved-cml")
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
            .fileImporter(isPresented: $importingPack, allowedContentTypes: [.item]) { result in
                switch result {
                case .success(let url):
                    guard !installingPack else { return }
                    guard url.pathExtension.lowercased() == "cmassets" else {
                        message = "Select the CrazyMachines_Original_102Levels.cmassets file."
                        return
                    }
                    installingPack = true
                    message = "Checking original model and texture checksums…"
                    Task { @MainActor in
                        // Maintain the Files security scope until the entire
                        // detached import finishes. Releasing it as soon as
                        // fileImporter returns can fail for iCloud Files.
                        let access = url.startAccessingSecurityScopedResource()
                        defer {
                            if access { url.stopAccessingSecurityScopedResource() }
                            installingPack = false
                        }
                        do {
                            // Importing up to 102 scenes / 160 UCMs / 181 TGAs
                            // includes validation, SHA-256 and atomic writes.
                            // None of that belongs on the SwiftUI main actor.
                            let report = try await Task.detached(
                                priority: .userInitiated
                            ) {
                                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                                return try CMOriginalAssetPackImporter.install(data)
                            }.value
                            reload()
                            message = "Installed \(report.installed) files (\(report.existing) already present). \(report.models) original 3D models, \(report.textures) textures and \(report.levels) authentic scenes. Open Play to view levels."
                        } catch {
                            message = "Original game pack import failed: \(error.localizedDescription)"
                        }
                    }
                case .failure(let error):
                    message = "Original game pack selection failed: \(error.localizedDescription)"
                }
            }
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

    /// Make the original laboratory playable in the level browser after
    /// importing it from Game files, or when restoring a previously saved CML.
    private func decodeLaboratories(_ urls: [URL]) -> (installed: Int, total: Int, errors: [String]) {
        var installed = 0
        var total = 0
        var errors: [String] = []
        for url in urls {
            do {
                let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard attributes.isRegularFile == true,
                      let size = attributes.fileSize,
                      size >= 256, size <= 32 * 1024 * 1024 else {
                    throw CMOriginalLaboratorySceneInstaller.ImportError.invalid(
                        "Invalid CML file size"
                    )
                }
                let contents = try Data(contentsOf: url)
                let result = try CMOriginalLaboratorySceneInstaller.install(
                    contents, into: sceneStorage
                ) { sceneBytes in
                    SHA256.hash(data: sceneBytes)
                        .map { String(format: "%02x", $0) }.joined()
                }
                installed += result.installed
                total += result.total
            } catch {
                errors.append("\(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return (installed, total, errors)
    }

    private func decodeSavedLaboratories() {
        let stored = (try? FileManager.default.contentsOfDirectory(
            at: storage, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let cml = stored.filter { $0.pathExtension.lowercased() == "cml" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        guard !cml.isEmpty else {
            message = "No original CML laboratory found. Import the extracted PC game files first."
            return
        }
        let result = decodeLaboratories(cml)
        message = "Decoded \(result.installed) new level scenes (\(result.total) records checked)." +
            (result.errors.isEmpty ? "" : " Errors: \(result.errors.joined(separator: "; "))")
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
        var importedLaboratories: [URL] = []
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
                if ext == "fsc" && url.lastPathComponent.lowercased() == "elements.fsc" {
                    guard let source = try? CMOriginalElementsScriptDecoder.decode(data),
                          let scripts = try? CMOriginalElementsTemplateCatalog
                            .parse(decodedBytes: source), scripts.count >= 100 else {
                        rejected += 1
                        continue
                    }
                }
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
                    if (try? Data(contentsOf: destination)) == data {
                        if ext == "cml" { importedLaboratories.append(destination) }
                        continue
                    }
                    rejected += 1
                    continue
                }
                try data.write(to: destination, options: .atomic)
                if ext == "cml" { importedLaboratories.append(destination) }
                imported += 1
            } catch {
                rejected += 1
            }
        }
        reload()
        let scenes = decodeLaboratories(importedLaboratories)
        message = "Imported \(imported) original files; skipped \(rejected). " +
            "Decoded \(scenes.installed) new level scenes (\(scenes.total) records checked)." +
            (scenes.errors.isEmpty ? "" : " CML errors: \(scenes.errors.joined(separator: "; "))")
    }
}
