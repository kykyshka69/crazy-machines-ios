import SwiftUI
import UniformTypeIdentifiers

/// Browse actual user-exported original levels without simulating invented physics.
struct CMOriginalLevelBrowserView: View {
    @State private var importing = false
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
            }
            Section("Original object positions (X/Y)") {
                CMOriginalLevelMapView(document: document)
                Text("Read-only top-down coordinate plot. Orange markers are objects with GOAL 1; no original geometry or physics is simulated.")
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
                OutlineGroup([document.root], children: \.children) { node in
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
                    }
                }
            }
            Section {
                Text("Read-only original geometry metadata. Original models and physics are not rendered here yet.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Level \(document.index)")
    }

    private func importDocuments(_ urls: [URL]) {
        var imported = 0
        var rejected = 0
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let document = try CMOriginalSceneDocument.read(data)
                if let old = documents.firstIndex(where: { $0.index == document.index }) {
                    documents[old] = document
                } else {
                    documents.append(document)
                }
                imported += 1
            } catch {
                rejected += 1
            }
        }
        errorMessage = rejected == 0
            ? "Imported \(imported) original scenes"
            : "Imported \(imported); rejected \(rejected) invalid files"
    }
}
