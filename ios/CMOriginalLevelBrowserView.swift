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
    @State private var confirmingResetEdits = false
    @State private var physicsPaused = false
    @State private var diagnosticHinges = false
    @State private var mechanismSourceByScene: [String: String] = [:]
    @State private var mechanismTargetByScene: [String: String] = [:]
    @State private var switchPressCount = 0
    // Keep experimental role choices isolated by scene fingerprint.
    @State private var fixedObjectTypesByScene: [String: Set<String>] = [:]
    @State private var sensorObjectTypesByScene: [String: Set<String>] = [:]

    private func loadMechanismPreset(for document: CMOriginalSceneDocument) {
        let key = document.sceneSHA256
        let ids = CMOriginalGameplaySession(document: document).objects.map(\.id)
        guard ids.count >= 2 else { return }
        let prefix = "cm.original.mechanism." + key
        let savedSource = UserDefaults.standard.string(forKey: prefix + ".source")
        let savedTarget = UserDefaults.standard.string(forKey: prefix + ".target")
        if mechanismSourceByScene[key] == nil {
            mechanismSourceByScene[key] = savedSource.flatMap { ids.contains($0) ? $0 : nil } ?? ids[0]
        }
        if mechanismTargetByScene[key] == nil {
            mechanismTargetByScene[key] = savedTarget.flatMap { ids.contains($0) ? $0 : nil } ?? ids[1]
        }
    }

    private func saveMechanismPreset(for key: String) {
        let prefix = "cm.original.mechanism." + key
        UserDefaults.standard.set(mechanismSourceByScene[key], forKey: prefix + ".source")
        UserDefaults.standard.set(mechanismTargetByScene[key], forKey: prefix + ".target")
    }

    private func loadPhysicsPresets(for document: CMOriginalSceneDocument) {
        let key = document.sceneSHA256
        let prefix = "cm.original.physics.roles." + key
        if fixedObjectTypesByScene[key] == nil {
            fixedObjectTypesByScene[key] = Set(UserDefaults.standard.stringArray(forKey: prefix + ".fixed") ?? [])
        }
        if sensorObjectTypesByScene[key] == nil {
            sensorObjectTypesByScene[key] = Set(UserDefaults.standard.stringArray(forKey: prefix + ".sensor") ?? [])
        }
    }

    private func savePhysicsPresets(for sceneKey: String) {
        let prefix = "cm.original.physics.roles." + sceneKey
        UserDefaults.standard.set(Array(fixedObjectTypesByScene[sceneKey, default: []]).sorted(),
                                  forKey: prefix + ".fixed")
        UserDefaults.standard.set(Array(sensorObjectTypesByScene[sceneKey, default: []]).sorted(),
                                  forKey: prefix + ".sensor")
    }

    private struct AssembledSelection: Identifiable {
        let document: CMOriginalSceneDocument
        let experimentalPhysics: Bool
        let diagnosticHinges: Bool
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
                    guard let files = try? FileManager.default.contentsOfDirectory(
                        at: folder, includingPropertiesForKeys: [.isRegularFileKey],
                        options: [.skipsHiddenFiles]
                    ) else {
                        errorMessage = "Cannot read exported level folder"
                        return
                    }
                    let jsonFiles = files.filter { $0.pathExtension.lowercased() == "json" }
                    guard !jsonFiles.isEmpty else {
                        errorMessage = "No exported JSON levels found in this folder"
                        return
                    }
                    guard jsonFiles.count <= 102 else {
                        errorMessage = "Too many JSON files in selected folder"
                        return
                    }
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
            Section("Original object positions (X/Y)") {
                CMOriginalLevelMapView(document: document)
                Text("Read-only top-down coordinate plot. Orange markers are objects with GOAL 1; no original geometry or physics is simulated.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("3D asset readiness") {
                let names = CMOriginalModelResolver.modelNames(in: document.root)
                let available = names.filter {
                    CMOriginalModelResolver.resolve($0, in: originalStorage) != nil
                }
                LabeledContent("Referenced meshes", value: "\(names.count)")
                LabeledContent("Available UCM meshes", value: "\(available.count)")
                if available.isEmpty {
                    Text("Import the original .ucm model files in the Original files tab before opening 3D.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if available.count < names.count {
                    Text("Some original models are missing; the scene will omit them rather than substitute invented geometry.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Section("Experimental object physics by original type") {
                Text("Roles apply only to this imported scene. These are experimental choices, not original rules.")
                    .font(.caption).foregroundStyle(.secondary)
                let sceneKey = document.sceneSHA256
                let types = Array(Set(CMOriginalGameplaySession(document: document).objects.map(\.type))).sorted()
                ForEach(types, id: \.self) { type in
                    Picker(type, selection: Binding<String>(
                        get: {
                            if fixedObjectTypesByScene[sceneKey, default: []].contains(type) { return "Fixed" }
                            if sensorObjectTypesByScene[sceneKey, default: []].contains(type) { return "Sensor" }
                            return "Movable"
                        },
                        set: { role in
                            fixedObjectTypesByScene[sceneKey, default: []].remove(type)
                            sensorObjectTypesByScene[sceneKey, default: []].remove(type)
                            if role == "Fixed" { fixedObjectTypesByScene[sceneKey, default: []].insert(type) }
                            if role == "Sensor" { sensorObjectTypesByScene[sceneKey, default: []].insert(type) }
                            savePhysicsPresets(for: sceneKey)
                        }
                    )) {
                        Text("Movable").tag("Movable")
                        Text("Fixed").tag("Fixed")
                        Text("Sensor").tag("Sensor")
                    }
                }
            }
            Section("Interactive mechanism prototype") {
                let objects = CMOriginalGameplaySession(document: document).objects
                let key = document.sceneSHA256
                if objects.count >= 2 {
                    Text("Select an imported switch and a different object. In physics mode, tapping the switch pushes the target upward. Experimental behavior, not a decoded original rule.")
                        .font(.caption).foregroundStyle(.secondary)
                    Picker("Switch", selection: Binding(
                        get: { mechanismSourceByScene[key] ?? objects[0].id },
                        set: { mechanismSourceByScene[key] = $0; saveMechanismPreset(for: key) }
                    )) {
                        ForEach(objects) { object in
                            Text("\(object.id): \(object.type)").tag(object.id)
                        }
                    }
                    Picker("Target", selection: Binding(
                        get: { mechanismTargetByScene[key] ?? objects[1].id },
                        set: { mechanismTargetByScene[key] = $0; saveMechanismPreset(for: key) }
                    )) {
                        ForEach(objects) { object in
                            Text("\(object.id): \(object.type)").tag(object.id)
                        }
                    }
                    if (mechanismSourceByScene[key] ?? objects[0].id) == (mechanismTargetByScene[key] ?? objects[1].id) {
                        Text("Choose two different objects to enable the mechanism.")
                            .foregroundStyle(.orange)
                    }
                    Text("Tap the chosen switch mesh in experimental physics mode to push the target. Repeated taps work.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("At least two imported objects are needed.")
                        .foregroundStyle(.secondary)
                }
            }
            Section("Assembled original 3D scene") {
                Button("View original level in 3D") {
                    assembledScene = AssembledSelection(document: document, experimentalPhysics: false, diagnosticHinges: false)
                }
                Toggle("Experimental hinge between nearest meshes", isOn: $diagnosticHinges)
                Text("Optional test constraint only. The connected meshes and hinge axis are not inferred from the original level.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Try experimental gravity and collisions") {
                    physicsPaused = false
                    assembledScene = AssembledSelection(document: document, experimentalPhysics: true, diagnosticHinges: diagnosticHinges)
                }
                Text("Experimental sandbox: tap a mesh to push it; long-press a mesh to toggle fixed/movable. Restart restores the imported scene. These manual body types, approximate bounding-box collisions and uniform mass are not the original game physics or completion logic.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Reset all saved 3D positions", role: .destructive) {
                    confirmingResetEdits = true
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
        .confirmationDialog("Reset all edited object positions for this level?",
                            isPresented: $confirmingResetEdits,
                            titleVisibility: .visible) {
            Button("Reset positions", role: .destructive) {
                UserDefaults.standard.removeObject(forKey: "cm.original.positions.\(document.sceneSHA256)")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("All objects will return to their original imported coordinates the next time you open the 3D scene.")
        }
        .onAppear {
            loadPhysicsPresets(for: document)
            loadMechanismPreset(for: document)
        }
        .sheet(item: $assembledScene) { selection in
            NavigationStack {
                CMOriginalAssembledSceneView(
                    document: selection.document,
                    assetDirectory: originalStorage,
                    experimentalPhysics: selection.experimentalPhysics,
                    physicsPaused: physicsPaused,
                    diagnosticHinges: selection.diagnosticHinges,
                    configuredPhysicsRoles: Dictionary(uniqueKeysWithValues:
                        CMOriginalGameplaySession(document: selection.document).objects.compactMap { object in
                            if fixedObjectTypesByScene[selection.document.sceneSHA256, default: []].contains(object.type) {
                                return (object.id, CMOriginalGameplaySession.PhysicsRole.fixed)
                            }
                            if sensorObjectTypesByScene[selection.document.sceneSHA256, default: []].contains(object.type) {
                                return (object.id, CMOriginalGameplaySession.PhysicsRole.sensor)
                            }
                            return nil
                        }),
                    configuredReactions: {
                        let objects = CMOriginalGameplaySession(document: selection.document).objects
                        guard objects.count >= 2 else { return [] }
                        let key = selection.document.sceneSHA256
                        let source = mechanismSourceByScene[key] ?? objects[0].id
                        let target = mechanismTargetByScene[key] ?? objects[1].id
                        guard source != target else { return [] }
                        return [
                            CMOriginalGameplaySession.ReactionRule(
                                objectID: source, trigger: .firstContact,
                                action: .impulseTarget(id: target, x: 0, y: 8, z: 0))
                        ]
                    }(),
                    switchPressCount: switchPressCount
                )
                    // Replacing the sheet selection alone does not guarantee
                    // UIViewRepresentable.makeUIView runs again. Force a new
                    // SceneKit world on Restart, including physics bodies and
                    // diagnostic hinges, while preserving pause/resume updates.
                    .id(selection.id)
                    .navigationTitle("Level \(selection.document.index) · 3D")
                    .safeAreaInset(edge: .bottom) {
                        if selection.experimentalPhysics && !physicsPaused &&
                            CMOriginalGameplaySession(document: selection.document).objects.count >= 2 &&
                            (mechanismSourceByScene[selection.document.sceneSHA256] != mechanismTargetByScene[selection.document.sceneSHA256]) {
                            Button("Activate mechanism") { switchPressCount += 1 }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("cm.original.mechanism.activate")
                                .padding(8)
                        }
                    }
                    .toolbar {
                        if selection.experimentalPhysics {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Restart") {
                                    physicsPaused = false
                                    assembledScene = AssembledSelection(document: selection.document,
                                                                        experimentalPhysics: true,
                                                                        diagnosticHinges: selection.diagnosticHinges)
                                }
                            }
                            ToolbarItem(placement: .topBarLeading) {
                                Button(physicsPaused ? "Resume" : "Pause") {
                                    physicsPaused.toggle()
                                }
                                .accessibilityIdentifier("cm.original.physics.pause")
                            }
                        }
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
