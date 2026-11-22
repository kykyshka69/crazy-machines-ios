import SwiftUI
import UniformTypeIdentifiers

/// Browse actual user-exported original levels without simulating invented physics.
struct CMOriginalLevelBrowserView: View {
    @State private var importing = false
    @State private var importingFolder = false
    @State private var documents: [CMOriginalSceneDocument] = []
    @State private var errorMessage: String?
    @State private var selected: Int?
    @State private var previewModel: ModelPreviewSelection?
    @State private var assembledScene: AssembledSelection?
    @State private var physicsExperimentEnabled = false
    @State private var physicsExperimentPaused = false
    private struct AssembledSelection: Identifiable {
        let document: CMOriginalSceneDocument
        let id = UUID()
    }

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
                        NavigationLink {
                            levelDetails(document)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(document.index). \(document.title)")
                                Text("\(document.root.objectCount) object nodes · \(document.root.positionedObjectCount) positioned")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("cm.original.level-\(document.index)")
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
                CMOriginalAssetAuditView(
                    modelNames: CMOriginalModelResolver.allModelNames(in: document.root),
                    directory: originalStorage
                )
                .id(document.sceneSHA256)
            }
            Section("Assembled original 3D scene") {
                Button("View original level in 3D") {
                    assembledScene = AssembledSelection(document: document)
                }
                Text("Uses imported UCM meshes and original nested POS/ROT transforms. Missing models are omitted; original materials and physics are not yet supported.")
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
                        Text(name + " — import matching .ucm file")
                            .foregroundStyle(.secondary)
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
        // Keep the first authentic 3D preview reachable without scrolling
        // through a long list of original object properties.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    assembledScene = AssembledSelection(document: document)
                } label: {
                    Label("3D view", systemImage: "cube")
                }
                .accessibilityIdentifier("cm.original.open-3d")
            }
        }
        .sheet(item: $assembledScene) { selection in
            NavigationStack {
                VStack(spacing: 0) {
                    Toggle("Experimental collisions (not original game physics)", isOn: $physicsExperimentEnabled)
                        .font(.caption)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .accessibilityIdentifier("cm.original.experimental-physics")
                    if physicsExperimentEnabled {
                        HStack {
                            Button(physicsExperimentPaused ? "Resume simulation" : "Pause simulation") {
                                physicsExperimentPaused.toggle()
                            }
                            .accessibilityIdentifier("cm.original.physics-pause")
                            Spacer()
                            Text("Approximate UCM collisions")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                    CMOriginalAssembledSceneView(
                        document: selection.document,
                        assetDirectory: originalStorage,
                        experimentalPhysics: physicsExperimentEnabled,
                        physicsPaused: physicsExperimentPaused
                    )
                    // Rebuild the original scene when changing simulation
                    // modes; otherwise SceneKit bodies are never created.
                    .id("\(selection.id)-physics-\(physicsExperimentEnabled)")
                }
                .navigationTitle("Level \(selection.document.index) · 3D")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") {
                            physicsExperimentEnabled = false
                            physicsExperimentPaused = false
                            assembledScene = nil
                        }
                    }
                }
            }
        }
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
