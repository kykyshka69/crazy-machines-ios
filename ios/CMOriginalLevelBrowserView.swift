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
                let names = CMOriginalModelResolver.modelNames(in: document.root)
                let available = names.filter {
                    CMOriginalModelResolver.resolve($0, in: originalStorage) != nil
                }
                let missing = names.filter {
                    CMOriginalModelResolver.resolve($0, in: originalStorage) == nil
                }
                LabeledContent("Referenced original meshes", value: "\(names.count)")
                LabeledContent("Resolved original UCM files", value: "\(available.count)")
                LabeledContent("Missing original UCM files", value: "\(missing.count)")
                if !missing.isEmpty {
                    Text("These are original model references, not substitute objects. Import matching UCM files from your PC installation.")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(missing, id: \.self) { name in
                        Text(name).font(.caption.monospaced()).textSelection(.enabled)
                    }
                }
            }
            Section("Assembled original 3D scene") {
                Button("View original level in 3D") {
                    assembledScene = AssembledSelection(document: document)
                }
                Text("Uses imported UCM meshes and original nested POS/ROT transforms. Missing models are omitted; original materials and physics are not yet supported.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Original 3D models") {
                let names = CMOriginalModelResolver.modelNames(in: document.root)
                if names.isEmpty {
                    Text("No 3DO references in this level")
                }
                ForEach(names, id: \.self) { name in
                    if let url = CMOriginalModelResolver.resolve(name, in: originalStorage) {
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
        .sheet(item: $assembledScene) { selection in
            NavigationStack {
                CMOriginalAssembledSceneView(
                    document: selection.document,
                    assetDirectory: originalStorage,
                    experimentalPhysics: false
                )
                    // Keep the imported original scene tied to this presentation.
                    .id(selection.id)
                    .navigationTitle("Level \(selection.document.index) · 3D")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { assembledScene = nil }
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
        ) else { return }
        var loaded: [Int: CMOriginalSceneDocument] = [:]
        for url in urls where url.pathExtension.lowercased() == "json" {
            guard let data = try? Data(contentsOf: url),
                  let document = try? CMOriginalSceneDocument.read(data) else { continue }
            loaded[document.index] = document
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
                let data = try Data(contentsOf: url)
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
