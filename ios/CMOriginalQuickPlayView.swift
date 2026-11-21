import SwiftUI

/// Opens a user-imported original Professor Laboratory scene directly in 3D.
/// All geometry/coordinates come from the user's PC game assets; this is not
/// the original Windows game engine or a claim of reconstructed puzzle rules.
struct CMOriginalQuickPlayView: View {
    let document: CMOriginalSceneDocument
    let assetDirectory: URL

    @State private var experimentalPhysics = false
    @State private var physicsPaused = false
    @State private var sceneRevision = UUID()
    @State private var showAllLevels = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Original level \(document.index): \(document.title)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .accessibilityIdentifier("cm.original.quickplay-level")
                Spacer(minLength: 0)
                Button("Levels") { showAllLevels = true }
                    .accessibilityIdentifier("cm.original.quickplay-levels")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)

            CMOriginalAssembledSceneView(
                document: document,
                assetDirectory: assetDirectory,
                experimentalPhysics: experimentalPhysics,
                physicsPaused: physicsPaused
            )
            .id(sceneRevision)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 12) {
                Toggle("Experimental collisions", isOn: $experimentalPhysics)
                    .font(.caption)
                    .onChange(of: experimentalPhysics) { _, _ in
                        physicsPaused = false
                        // Rebuild bodies only after changing scene physics mode.
                        sceneRevision = UUID()
                    }
                    .accessibilityIdentifier("cm.original.quickplay-physics")
                if experimentalPhysics {
                    Button(physicsPaused ? "Resume" : "Pause") {
                        physicsPaused.toggle()
                    }
                    .accessibilityIdentifier("cm.original.quickplay-pause")
                }
                Button("Reset") {
                    physicsPaused = false
                    sceneRevision = UUID()
                }
                .accessibilityIdentifier("cm.original.quickplay-reset")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            Text("Authentic PC geometry and transforms. Experimental collisions are not the original puzzle physics.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .navigationTitle("Crazy Machines")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationDestination(isPresented: $showAllLevels) {
            CMOriginalLevelBrowserView()
        }
    }
}
