import SwiftUI

/// Opens a user-imported original Professor Laboratory scene directly in 3D.
/// All geometry/coordinates come from the user's PC game assets; this is not
/// the original Windows game engine or a claim of reconstructed puzzle rules.
struct CMOriginalQuickPlayView: View {
    let document: CMOriginalSceneDocument
    let assetDirectory: URL

    // Open an authentic scene at rest; users arrange original parts before
    // starting the approximate physics simulation, matching the PC play loop.
    @State private var experimentalPhysics = false
    @State private var physicsPaused = false
    @State private var sceneRevision = UUID()
    @State private var showAllLevels = false

    /// An explicit experimental starting configuration for the imported PC
    /// scene. SceneKit physics is not the original Windows solver. The roles
    /// below are provisional object-category choices, not recovered engine
    /// behavior. They prevent the scenery from falling with the balls.
    private var experimentalPhysicsRoles: [String: CMOriginalGameplaySession.PhysicsRole] {
        var ordinal = 0
        var roles: [String: CMOriginalGameplaySession.PhysicsRole] = [:]
        func walk(_ node: CMOriginalSceneDocument.Node) {
            if node.name.hasPrefix("tmo_") {
                let id = "object-\(ordinal)"
                ordinal += 1
                switch node.name {
                case "tmo_zone":
                    roles[id] = .sensor
                case let name where name.hasPrefix("tmo_ball") || name == "tmo_crate":
                    roles[id] = .movable
                default:
                    roles[id] = .fixed
                }
            }
            for child in node.children { walk(child) }
        }
        walk(document.root)
        return roles
    }

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
                physicsPaused: physicsPaused,
                allowObjectPlacement: true,
                configuredPhysicsRoles: experimentalPhysicsRoles
            )
            .id(sceneRevision)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 12) {
                Toggle("Run experimental physics", isOn: $experimentalPhysics)
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
                Button("Restart") {
                    physicsPaused = false
                    sceneRevision = UUID()
                }
                .accessibilityIdentifier("cm.original.quickplay-reset")
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            HStack(spacing: 10) {
                if !experimentalPhysics {
                    Label("Tap to select · drag · twist to rotate · pinch to zoom.", systemImage: "hand.draw")
                        .font(.caption.weight(.medium))
                        .accessibilityIdentifier("cm.original.quickplay-arrange-hint")
                } else {
                    Text("Stop physics to return to object placement.")
                        .font(.caption)
                }
                Spacer(minLength: 6)
                Button("Original layout") {
                    UserDefaults.standard.removeObject(
                        forKey: "cm.original.positions.\(document.sceneSHA256)"
                    )
                    UserDefaults.standard.removeObject(
                        forKey: "cm.original.rotations.\(document.sceneSHA256)"
                    )
                    experimentalPhysics = false
                    physicsPaused = false
                    sceneRevision = UUID()
                }
                .font(.caption.weight(.semibold))
                .accessibilityIdentifier("cm.original.quickplay-original-layout")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            Text(experimentalPhysics
                 ? "Experimental SceneKit collisions, not the original game's physics."
                 : "Positions and rotations are stored only on this iPhone. Starting physics uses this arrangement; original PC level files stay unchanged.")
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
