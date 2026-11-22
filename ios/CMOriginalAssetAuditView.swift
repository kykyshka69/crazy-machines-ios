import SwiftUI

/// On-demand UCM and original billboard texture integrity check.
/// Runs off the main actor so large original files do not freeze the browser.
struct CMOriginalAssetAuditView: View {
    let modelNames: [String]
    let directory: URL

    @State private var checking = false
    @State private var report: CMOriginalAssetAudit.Report?

    var body: some View {
        LabeledContent("Original 3D/effect references", value: String(modelNames.count))
        Button {
            checkAssets()
        } label: {
            Label(checking ? "Checking original meshes and effects…" :
                  "Verify meshes and glow textures", systemImage: "checkmark.shield")
        }
        .disabled(checking || modelNames.isEmpty)
        .accessibilityIdentifier("cm.original.verify-meshes")

        if modelNames.isEmpty {
            Text("No original 3D model references were exported for this level.")
                .font(.caption).foregroundStyle(.secondary)
        } else if let report {
            LabeledContent("Renderable original references", value: String(report.readyCount))
            LabeledContent("Unresolved or invalid resources",
                           value: String(report.problemEntries.count))
            if report.allReady {
                Text("All referenced UCM meshes and supported 3DO glow textures parsed. This does not validate the original Windows shaders or puzzle physics.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(report.problemEntries) { entry in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.reference).font(.caption.monospaced())
                        Text(statusDescription(entry.status))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Text("Import the matching original UCM/TGA files, then run the check again.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } else {
            Text("Reference counts do not prove a scene is renderable. Validate original 3D meshes and the matching glow images.")
                .font(.caption).foregroundStyle(.secondary)
        }

        if checking {
            ProgressView("Reading original meshes and glow images")
                .font(.caption)
        }
    }

    private func statusDescription(_ status: CMOriginalAssetAudit.Status) -> String {
        switch status {
        case .ready: return "Referenced UCM geometry or TGA image validated"
        case .missing: return "Required original UCM or TGA is not imported"
        case .ambiguous: return "Multiple imported files have this model name"
        case .invalidReference: return "Unsafe or invalid model reference"
        case .unreadable: return "File cannot be read"
        case .tooLarge: return "File exceeds the 64 MB import limit"
        case .invalidGeometry: return "UCM geometry fails validation"
        case .invalidTexture: return "Original effect TGA fails validation"
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
