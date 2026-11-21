import SwiftUI
import UniformTypeIdentifiers
import CryptoKit

/// Browse actual user-exported original levels without simulating invented physics.
struct CMOriginalLevelBrowserView: View {
    @State private var importing = false
    @State private var importingFolder = false
    @State private var importingCML = false
    @State private var documents: [CMOriginalSceneDocument] = []
    @State private var errorMessage: String?
    @State private var selected: Int?
    @State private var previewModel: ModelPreviewSelection?
    private struct ModelPreviewSelection: Identifiable {
        let id = UUID()
        let name: String
        let url: URL
    }

    private var originalStorage: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OriginalGame", isDirectory: true)
    }

    private var sceneStorage: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OriginalScenes", isDirectory: true)
    }

    private var sorted: [CMOriginalSceneDocument] {
        documents.sorted { $0.index < $1.index }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Import JSON files exported from your original Professor Laboratory CML.")
                        .font(.caption)
                    Button("Import original levels") { importing = true }
                    Button("Import entire exported levels folder") { importingFolder = true }
                    Button("Import original PC laboratory (.cml)") { importingCML = true }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red).font(.caption)
                    }
                    Text("\(documents.count) original levels loaded")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Original puzzles") {
                    if documents.isEmpty {
                        ContentUnavailableView(
                            "No original levels imported",
                            systemImage: "square.stack.3d.up.slash",
                            description: Text("Export the original CML levels to JSON on your computer, then import the files or their folder here.")
                        )
                    }
                    ForEach(sorted, id: \.index) { document in
                        HStack {
                            // Every authentic imported puzzle enters the SAME
                            // player-facing 3D scene, not an inspect-only sheet.
                            NavigationLink {
                                CMOriginalQuickPlayView(
                                    document: document, assetDirectory: originalStorage
                                )
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(document.index). \(document.title)")
                                    Text("\(document.root.objectCount) original objects")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            .accessibilityIdentifier("cm.original.open-level-\(document.index)")
                            NavigationLink {
                                levelDetails(document)
                            } label: {
                                Label("Level \(document.index) details", systemImage: "info.circle")
                                    .labelStyle(.iconOnly)
                                    .padding(8)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }
            .navigationTitle("Original levels")
            .onAppear(perform: reloadSavedScenes)
            .fileImporter(isPresented: $importingFolder, allowedContentTypes: [.folder]) { result in
                switch result {
                case .failure(let error):
                    errorMessage = error.localizedDescription
                case .success(let folder):
                    let access = folder.startAccessingSecurityScopedResource()
                    defer { if access { folder.stopAccessingSecurityScopedResource() } }
                    guard let enumerator = FileManager.default.enumerator(
                        at: folder, includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles, .skipsPackageDescendants]
                    ) else {
                        errorMessage = "Cannot read exported level folder"
                        return
                    }
                    var jsonFiles: [URL] = []
                    for case let file as URL in enumerator {
                        guard file.pathExtension.lowercased() == "json" else { continue }
                        guard (try? file.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
                            continue
                        }
                        jsonFiles.append(file)
                        if jsonFiles.count > 102 {
                            errorMessage = "Too many JSON files in selected folder"
                            return
                        }
                    }
                    guard !jsonFiles.isEmpty else {
                        errorMessage = "No exported JSON levels found in this folder"
                        return
                    }
                    jsonFiles.sort { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
                    importDocuments(jsonFiles)
                }
            }
            .fileImporter(isPresented: $importingCML,
                          allowedContentTypes: [UTType(filenameExtension: "cml") ?? .data]) { result in
                switch result {
                case .failure(let error):
                    errorMessage = error.localizedDescription
                case .success(let url):
                    importOriginalLaboratory(url)
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json],
                          allowsMultipleSelection: true) { result in
                switch result {
                case .failure(let error):
                    errorMessage = error.localizedDescription
                case .success(let urls):
                    importDocuments(urls)
                }
            }
        }
    }

    private func levelDetails(_ document: CMOriginalSceneDocument) -> some View {
        List {
            Section("Original scene") {
                LabeledContent("Puzzle", value: document.title)
                LabeledContent("Objects", value: "\(document.root.objectCount)")
                LabeledContent("With positions", value: "\(document.root.positionedObjectCount)")
                LabeledContent("Goal markers", value: "\(document.root.goalCount)")
                let inventory = document.gameplayInventory
                LabeledContent("Distinct object types", value: "\(inventory.objectTypes.count)")
                LabeledContent("Goal object types", value: "\(inventory.goalObjectTypes.count)")
                if !inventory.goalObjectTypes.isEmpty {
                    ForEach(inventory.goalObjectTypes.keys.sorted(), id: \.self) { name in
                        LabeledContent(name, value: "\(inventory.goalObjectTypes[name] ?? 0) goal markers")
                    }
                }
                if !inventory.objectsWithoutModels.isEmpty {
                    LabeledContent("Objects without 3D references",
                                   value: "\(inventory.objectsWithoutModels.values.reduce(0, +))")
                }
                Text("These are verified scene annotations, not a decoded victory condition.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Original goal-marked objects") {
                let goalObjects = goalMarkedObjects(in: document.root)
                if goalObjects.isEmpty {
                    Text("No GOAL 1 annotations in this scene.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(goalObjects.enumerated()), id: \.offset) { entry in
                    DisclosureGroup(entry.element.name) {
                        if let position = entry.element.position {
                            LabeledContent("Original POS", value: position.map {
                                String(format: "%.5f", $0)
                            }.joined(separator: ", "))
                        }
                        if let models = entry.element.models, !models.isEmpty {
                            LabeledContent("3D models", value: models.joined(separator: ", "))
                        }
                        ForEach(entry.element.fields, id: \.self) { field in
                            Text(field).font(.caption.monospaced()).textSelection(.enabled)
                        }
                    }
                }
                Text("GOAL 1 identifies original annotations, not a verified win condition.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            originalPropertiesSection(document)
            Section("Original object positions (X/Y)") {
                CMOriginalLevelMapView(document: document)
                Text("Read-only top-down coordinate plot. Orange markers are objects with GOAL 1; no original geometry or physics is simulated.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Original 3D asset readiness") {
                let names = CMOriginalModelResolver.allModelNames(in: document.root)
                let assets = CMOriginalModelResolver.AssetIndex(directory: originalStorage)
                let available = names.filter {
                    if case .found = assets.resolution(for: $0) { return true }
                    return false
                }
                let missing = names.filter {
                    if case .missing = assets.resolution(for: $0) { return true }
                    return false
                }
                let ambiguous = names.filter {
                    if case .ambiguous = assets.resolution(for: $0) { return true }
                    return false
                }
                let invalid = names.filter {
                    if case .invalidReference = assets.resolution(for: $0) { return true }
                    return false
                }
                LabeledContent("Referenced original meshes", value: "\(names.count)")
                LabeledContent("Resolved original UCM files", value: "\(available.count)")
                LabeledContent("Missing original UCM files", value: "\(missing.count)")
                LabeledContent("Ambiguous original UCM files", value: "\(ambiguous.count)")
                LabeledContent("Invalid original model references", value: "\(invalid.count)")
                if !missing.isEmpty || !ambiguous.isEmpty || !invalid.isEmpty {
                    let report = [
                        "Crazy Machines — original 3D asset report",
                        "Level: \(document.index) — \(document.title)",
                        "Resolved: \(available.count) / \(names.count)",
                        "",
                        "Missing UCM models (\(missing.count)):",
                        missing.isEmpty ? "(none)" : missing.joined(separator: "\n"),
                        "",
                        "Ambiguous UCM models (\(ambiguous.count)):",
                        ambiguous.isEmpty ? "(none)" : ambiguous.joined(separator: "\n"),
                        "",
                        "Invalid original references (\(invalid.count)):",
                        invalid.isEmpty ? "(none)" : invalid.joined(separator: "\n")
                    ].joined(separator: "\n")
                    ShareLink(item: report) {
                        Label("Share missing-model report", systemImage: "square.and.arrow.up")
                    }
                }
                if !missing.isEmpty {
                    Text("Import matching original UCM files from your PC installation.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(missing, id: \.self) { name in
                        Text(name).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                if !ambiguous.isEmpty {
                    Text("Multiple imported UCM files match these names. Remove duplicate basenames before rendering.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(ambiguous, id: \.self) { name in
                        Text(name).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
                if !invalid.isEmpty {
                    Text("These original model references contain unsupported paths or names.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(invalid, id: \.self) { name in
                        Text(name).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
            }
            Section("Original PC electrical terminals") {
                let session = CMOriginalGameplaySession(document: document)
                let terminals = session.originalPowerTerminals
                let indexed = terminals.filter { $0.originalTerminalNumber != nil }
                if terminals.isEmpty {
                    Text("No original tmo_power_plug terminals in this puzzle.")
                        .foregroundStyle(.secondary)
                } else {
                    LabeledContent("Original terminals", value: "\(terminals.count)")
                    LabeledContent("Numbered VALF terminals", value: "\(indexed.count)")
                    LabeledContent("Unnumbered PC terminals",
                                   value: "\(terminals.count - indexed.count)")
                    LabeledContent("Terminal IDs",
                                   value: session.powerTerminalNumbersAreUnique
                                     ? "Unique in this level" : "Duplicate values")
                    ForEach(terminals, id: \.plugObjectID) { terminal in
                        DisclosureGroup(
                            terminal.originalTerminalNumber.map { "Terminal #\($0)" }
                                ?? "Unnumbered terminal"
                        ) {
                            LabeledContent(
                                "Original device",
                                value: terminal.deviceType ?? "Unresolved PC owner"
                            )
                            if let location = terminal.originalRelativePosition {
                                Text("POSREL " + location.map {
                                    String(format: "%.5f", $0)
                                }.joined(separator: ", "))
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    Text("The original VALF number identifies a plug, not its wire, voltage, or switch state. The original electrical wiring has not yet been decoded; this screen does not invent connections.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Play original 3D level") {
                NavigationLink {
                    CMOriginalQuickPlayView(
                        document: document, assetDirectory: originalStorage
                    )
                } label: {
                    Label("Open original level \(document.index)", systemImage: "play.fill")
                }
                Text("Original geometry and CML transforms, with editable UNLOCKED parts. The physics solver is still experimental.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Original 3D models") {
                let names = CMOriginalModelResolver.allModelNames(in: document.root)
                let assets = CMOriginalModelResolver.AssetIndex(directory: originalStorage)
                if names.isEmpty {
                    Text("No 3DO references in this level")
                }
                ForEach(names, id: \.self) { name in
                    if let url = assets.resolve(name) {
                        Button("Preview " + name) {
                            previewModel = ModelPreviewSelection(name: name, url: url)
                        }
                    } else {
                        switch assets.resolution(for: name) {
                        case .missing:
                            Text(name + " — import matching .ucm file")
                                .foregroundStyle(.secondary)
                        case .ambiguous:
                            Text(name + " — duplicate UCM filenames; resolve ambiguity")
                                .foregroundStyle(.secondary)
                        case .invalidReference:
                            Text(name + " — invalid original model reference")
                                .foregroundStyle(.secondary)
                        case .found:
                            EmptyView()
                        }
                    }
                }
            }
            Section("Scene hierarchy") {
                OutlineGroup([document.root], children: \.outlineChildren) { node in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(node.name).font(.system(.subheadline, design: .monospaced))
                        if let position = node.position {
                            Text("POS " + position.map { String(format: "%.5f", $0) }.joined(separator: ", "))
                                .font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        if let rotation = node.rotationRaw {
                            Text("ROT " + rotation).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        if let models = node.models, !models.isEmpty {
                            Text("3DO " + models.joined(separator: ", "))
                                .font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        if let goal = node.goalRaw {
                            Text("GOAL " + goal).font(.caption.monospaced()).foregroundStyle(.secondary)
                        }
                        if node.name.hasPrefix("tmo_") {
                            DisclosureGroup("Original object parameters") {
                                ForEach(node.originalFieldValues.keys.sorted(), id: \.self) { key in
                                    ForEach(Array((node.originalFieldValues[key] ?? []).enumerated()), id: \.offset) { item in
                                        Text(key + (item.element.isEmpty ? "" : " " + item.element))
                                            .font(.caption.monospaced())
                                            .textSelection(.enabled)
                                    }
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
            }
            Section {
                Text("Original model geometry can be previewed; original physics and materials are not yet implemented.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Level \(document.index)")
        .sheet(item: $previewModel) { selection in
            NavigationStack {
                CMOriginalModelPreview(modelURL: selection.url)
                    .navigationTitle(selection.name)
                    .toolbar { Button("Close") { previewModel = nil } }
            }
        }
    }

    @ViewBuilder
    private func originalPropertiesSection(_ document: CMOriginalSceneDocument) -> some View {
        Section("Original PC object properties") {
            Text("Unmodified properties from the imported level. No behavior is inferred from these values.")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(Array(originalObjects(in: document.root).enumerated()), id: \.offset) { entry in
                originalObjectProperties(entry.element, number: entry.offset + 1)
            }
        }
    }

    @ViewBuilder
    private func originalObjectProperties(_ object: CMOriginalSceneDocument.Node, number: Int) -> some View {
        DisclosureGroup("\(number). \(object.name)") {
            if let position = object.position {
                LabeledContent("POS", value: position.map { String($0) }.joined(separator: ", "))
            }
            if let relative = object.positionRelative {
                LabeledContent("POSREL", value: relative.map { String($0) }.joined(separator: ", "))
            }
            if let rotation = object.rotationRaw {
                LabeledContent("ROT", value: rotation)
            }
            if let rotation = object.rotationRelativeRaw {
                LabeledContent("ROTREL", value: rotation)
            }
            ForEach(Array(object.fields.enumerated()), id: \.offset) { field in
                Text(field.element).font(.caption.monospaced()).textSelection(.enabled)
            }
        }
    }

    private func originalObjects(in root: CMOriginalSceneDocument.Node) -> [CMOriginalSceneDocument.Node] {
        var result: [CMOriginalSceneDocument.Node] = []
        func visit(_ node: CMOriginalSceneDocument.Node) {
            if node.name.hasPrefix("tmo_") { result.append(node) }
            for child in node.children { visit(child) }
        }
        visit(root)
        return result
    }

    private func goalMarkedObjects(in root: CMOriginalSceneDocument.Node) -> [CMOriginalSceneDocument.Node] {
        var result: [CMOriginalSceneDocument.Node] = []
        func visit(_ node: CMOriginalSceneDocument.Node) {
            if node.name.hasPrefix("tmo_"), node.goalRaw == "1" {
                result.append(node)
            }
            for child in node.children { visit(child) }
        }
        visit(root)
        return result
    }

    /// Native original CML import: read the user-supplied encrypted Windows
    /// laboratory, decompress each LZW scene and generate the same verified
    /// scene documents already supported by the existing player. Preflight
    /// every level before writing anything into the private app sandbox.
    private func importOriginalLaboratory(_ url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard attributes.isRegularFile == true,
                  let size = attributes.fileSize,
                  size >= 256, size <= 32 * 1024 * 1024 else {
                errorMessage = "Original CML file has an invalid size"
                return
            }
            let data = try Data(contentsOf: url)
            let records = try CMOriginalCMLContainer.read(data)
            guard !records.isEmpty else {
                errorMessage = "This original laboratory contains no puzzles"
                return
            }

            var prepared: [(url: URL, bytes: Data, hash: String, title: String)] = []
            for record in records {
                let originalBytes = try CMOriginalLZW12.decodeLevelSection(record.payload)
                guard let text = CMOriginalWindows1251.decode(originalBytes) else {
                    throw CMOriginalCMLContainer.DecodeError.invalidText
                }
                let hash = SHA256.hash(data: originalBytes)
                    .map { String(format: "%02x", $0) }.joined()
                let json = try CMOriginalSceneTextParser.export(
                    text, index: record.index, title: record.title, sceneSHA256: hash
                )
                let filename = String(format: "level-%03d.json", record.index)
                let destination = sceneStorage.appendingPathComponent(filename)
                prepared.append((destination, json, hash, record.title))
            }

            // Preserve any existing imported levels. Equivalent original
            // scenes are idempotent even if JSON key ordering differs.
            var fresh: [(url: URL, bytes: Data)] = []
            for item in prepared {
                if FileManager.default.fileExists(atPath: item.url.path) {
                    let existingData = try Data(contentsOf: item.url)
                    let existing = try CMOriginalSceneDocument.read(existingData)
                    guard existing.sceneSHA256 == item.hash,
                          existing.title == item.title else {
                        errorMessage = "A different original level already exists: \(item.url.lastPathComponent)"
                        return
                    }
                } else {
                    fresh.append((item.url, item.bytes))
                }
            }
            try FileManager.default.createDirectory(
                at: sceneStorage, withIntermediateDirectories: true
            )
            for item in fresh {
                try item.bytes.write(to: item.url, options: .atomic)
            }
            reloadSavedScenes()
            errorMessage = "Imported \(fresh.count) original PC puzzles (\(records.count) in laboratory)"
        } catch {
            errorMessage = "Unable to import original CML: \(error.localizedDescription)"
        }
    }

    private func reloadSavedScenes() {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: sceneStorage, includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            // Do not retain stale levels if private storage was removed
            // while the app was running or is not readable.
            documents = []
            return
        }
        var loaded: [Int: CMOriginalSceneDocument] = [:]
        // Stable ordering prevents duplicate level indices from resolving
        // differently between launches when the filesystem enumeration varies.
        let sortedURLs = urls.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
        for url in sortedURLs where url.pathExtension.lowercased() == "json" {
            guard let attributes = try? url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey]),
                  attributes.isRegularFile == true,
                  let size = attributes.fileSize, size > 0, size <= 8_000_000,
                  let data = try? Data(contentsOf: url),
                  let document = try? CMOriginalSceneDocument.read(data) else { continue }
            // Do not silently replace a previously loaded scene when two
            // saved JSON files declare the same original level number.
            if loaded[document.index] == nil {
                loaded[document.index] = document
            }
        }
        documents = loaded.values.sorted { $0.index < $1.index }
    }

    private func importDocuments(_ urls: [URL]) {
        do {
            try FileManager.default.createDirectory(
                at: sceneStorage, withIntermediateDirectories: true
            )
        } catch {
            errorMessage = "Cannot create private level storage: \(error.localizedDescription)"
            return
        }
        var imported = 0
        var rejected = 0
        var seenIndices = Set<Int>()
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                // Check file metadata before allocating its contents. The
                // decoder's 8 MB limit alone runs after Data(contentsOf:).
                let attributes = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
                guard attributes.isRegularFile == true,
                      let size = attributes.fileSize, size > 0, size <= 8_000_000 else {
                    rejected += 1
                    continue
                }
                let data = try Data(contentsOf: url)
                guard data.count <= 8_000_000 else {
                    rejected += 1
                    continue
                }
                let document = try CMOriginalSceneDocument.read(data)
                // Refuse conflicting duplicate level numbers in the same import.
                // Otherwise the last file silently wins depending on file order.
                guard seenIndices.insert(document.index).inserted else {
                    rejected += 1
                    continue
                }
                let filename = String(format: "level-%03d.json", document.index)
                let destination = sceneStorage.appendingPathComponent(filename)
                // Preserve an existing original level unless the imported bytes
                // are identical. A different export with the same index must
                // not silently replace the user's previously imported scene.
                if FileManager.default.fileExists(atPath: destination.path) {
                    if (try? Data(contentsOf: destination)) == data { continue }
                    rejected += 1
                    continue
                }
                // Retain only user-imported data in the app sandbox, never the repo.
                try data.write(to: destination, options: .atomic)
                imported += 1
            } catch {
                rejected += 1
            }
        }
        reloadSavedScenes()
        errorMessage = rejected == 0
            ? "Saved \(imported) original scenes on this iPhone"
            : "Saved \(imported); rejected \(rejected) invalid files"
    }
}

// OutlineGroup requires an optional collection for hierarchical children.
private extension CMOriginalSceneDocument.Node {
    var outlineChildren: [CMOriginalSceneDocument.Node]? {
        children.isEmpty ? nil : children
    }
}
