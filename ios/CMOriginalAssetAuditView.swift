import SwiftUI

/// On-demand UCM integrity check for a real imported Crazy Machines level.
/// Runs off the main actor so large original files do not freeze the browser.
struct CMOriginalAssetAuditView: View {
    let modelNames: [String]
    let directory: URL

    @State private var checking = false
    @State private var report: CMOriginalAssetAudit.Report?

    var body: some View {
        LabeledContent("Original model references", value: String(modelNames.count))
        Button {
            checkAssets()
        } label: {
            Label(checking ? "Checking original UCM files…" :
                  "Verify original UCM geometry", systemImage: "checkmark.shield")
        }
        .disabled(checking || modelNames.isEmpty)
        .accessibilityIdentifier("cm.original.verify-meshes")

        if modelNames.isEmpty {
            Text("No original 3D model references were exported for this level.")
                .font(.caption).foregroundStyle(.secondary)
        } else if let report {
            LabeledContent("Readable original 3D meshes", value: String(report.readyCount))
            LabeledContent("Unresolved or invalid meshes",
                           value: String(report.problemEntries.count))
            if report.allReady {
                Text("All referenced UCM files parsed. This does not verify original textures, placement or puzzle physics.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(report.problemEntries) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.reference).font(.caption.monospaced())
                        Text(statusDescription(entry.status))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Text("Import the matching original UCM files in Original files, then run the check again.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Text("The number of model references is not proof that a level can render. Verify the imported meshes to check for missing or malformed files.")
                .font(.caption).foregroundStyle(.secondary)
        }

        if checking {
            ProgressView("Reading original 3D models")
                .font(.caption)
        }
    }

    private func statusDescription(_ status: CMOriginalAssetAudit.Status) -> String {
        switch status {
        case .ready: return "UCM geometry validated"
        case .missing: return "UCM file not imported"
        case .ambiguous: return "Multiple imported files have this model name"
        case .invalidReference: return "Unsafe or invalid model reference"
        case .unreadable: return "File cannot be read"
        case .tooLarge: return "File exceeds the 64 MB import limit"
        case .invalidGeometry: return "UCM geometry fails validation"
        }
    }

    private func checkAssets() {
        guard !checking else { return }
        checking = true
        report = nil
        let names = modelNames
        let folder = directory
        Task {
            let result = await Task.detached(priority: .utility) {
                CMOriginalAssetAudit.inspect(modelNames: names, directory: folder)
            }.value
            report = result
            checking = false
        }
    }
}
