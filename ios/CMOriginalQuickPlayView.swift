import SwiftUI

/// Opens a user-imported original Professor Laboratory scene directly in 3D.
/// All geometry/coordinates come from the user's PC game assets; this is not
/// the original Windows game engine or a claim of reconstructed puzzle rules.
struct CMOriginalQuickPlayView: View {
    let assetDirectory: URL
    @State private var document: CMOriginalSceneDocument

    init(document: CMOriginalSceneDocument, assetDirectory: URL) {
        self.assetDirectory = assetDirectory
        _document = State(initialValue: document)
    }

    // Open an authentic scene at rest; users arrange original parts before
    // starting the approximate physics simulation, matching the PC play loop.
    @State private var experimentalPhysics = false
    @State private var physicsPaused = false
    @State private var sceneRevision = UUID()
    @State private var showAllLevels = false
    @State private var zoneContacts: [String: Int] = [:]
    @State private var matchedZoneLinks = Set<String>()
    @State private var matchedMechanismLinks = Set<String>()

    // Reconstruct the PC's explicit CONNECTED_TO references to tmo_zone.
    // The original 0-based indices refer to level_elements.children,
    // not the nested SceneKit hierarchy. GOAL is not a victory rule.
    private var originalConnections: [CMOriginalGameplaySession.OriginalConnection] {
        CMOriginalGameplaySession(document: document).originalConnections
    }

    private var originalZoneConnections: [CMOriginalGameplaySession.OriginalConnection] {
        originalConnections.filter { $0.targetType == "tmo_zone" }
    }

    private var originalMechanismConnections: [CMOriginalGameplaySession.OriginalConnection] {
        originalConnections.filter { $0.targetType != "tmo_zone" }
    }

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
                if node.name == "tmo_zone" {
                    // Original capture zones use VALB 32/36. Detect contacts
                    // but never let the zone fall as a solid object.
                    roles[id] = .sensor
                } else if node.name == "tmo_rope_seesaw_lever" {
                    // In the original CML this lever is a child of a fixed
                    // seesaw support at POSREL 0,0,0. It has no VALB flag,
                    // so the generic flag parser froze it. A world-anchored
                    // hinge in the scene renderer lets it pivot on its PC
                    // support and respond to falling objects.
                    roles[id] = .movable
                } else if let raw = node.fields.first(where: { $0.hasPrefix("VALB ") }),
                          let flags = Int(raw.dropFirst(5)
                            .trimmingCharacters(in: .whitespaces)),
                          flags >= 0 && flags <= 255 {
                    // Recovered PC level metadata consistently distinguishes
                    // moving bodies with bit 8: balls/crates=72, dominoes=8/72,
                    // weights=72, balloons=104, etc. Fixed boards/pipes=64.
                    // This is a cautious SceneKit mapping of original data,
                    // NOT a reconstruction of the Windows physics engine.
                    roles[id] = (flags & 8) != 0 ? .movable : .fixed
                } else {
                    // Missing/unrecognized metadata must not cause original
                    // decorative/attachment objects to start falling.
                    roles[id] = .fixed
                }
            }
            for child in node.children { walk(child) }
        }
        walk(document.root)
        return roles
    }

    /// Identifies parts the original PC level explicitly lets the player
    /// rearrange. This is a recovered CML rule, not a guessed object category.
    private var originalEditablePartCount: Int {
        func count(_ node: CMOriginalSceneDocument.Node) -> Int {
            let own = node.name.hasPrefix("tmo_")
                && node.fields.contains("UNLOCKED 1") ? 1 : 0
            return own + node.children.reduce(0) { $0 + count($1) }
        }
        return count(document.root)
    }

    private var hasOriginalCaptureZone: Bool {
        func containsZone(_ node: CMOriginalSceneDocument.Node) -> Bool {
            node.name == "tmo_zone" || node.children.contains(where: containsZone)
        }
        return containsZone(document.root)
    }

    /// Navigate between authentic, privately imported CML scene exports.
    /// There are no synthetic fallback puzzles: missing or invalid levels
    /// are not offered. User arrangements remain separate for each scene hash.
    private func scene(at index: Int) -> CMOriginalSceneDocument? {
        guard (1...102).contains(index) else { return nil }
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let name = String(format: "level-%03d.json", index)
        let url = support.appendingPathComponent("OriginalScenes", isDirectory: true)
            .appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url),
              let result = try? CMOriginalSceneDocument.read(data),
              result.index == index else { return nil }
        return result
    }

    private func changeLevel(by step: Int) {
        guard let next = scene(at: document.index + step) else { return }
        document = next
        experimentalPhysics = false
        physicsPaused = false
        zoneContacts.removeAll()
        matchedZoneLinks.removeAll()
        matchedMechanismLinks.removeAll()
        sceneRevision = UUID()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    changeLevel(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(scene(at: document.index - 1) == nil)
                .accessibilityLabel("Previous original level")
                .accessibilityIdentifier("cm.original.quickplay-previous")

                Text("Original level \(document.index): \(document.title)")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .accessibilityIdentifier("cm.original.quickplay-level")

                Button {
                    changeLevel(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(scene(at: document.index + 1) == nil)
                .accessibilityLabel("Next original level")
                .accessibilityIdentifier("cm.original.quickplay-next")
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
                configuredPhysicsRoles: experimentalPhysicsRoles,
                onOriginalZoneContact: { type in
                    // Callback is posted to the main thread by SceneKit bridge.
                    zoneContacts[type, default: 0] += 1
                },
                onLinkedZoneContact: { sourceID, zoneID in
                    // Only a contact with the source object's OWN original
                    // CONNECTED_TO zone counts as a recovered objective.
                    let isOriginalTarget = originalZoneConnections.contains {
                        $0.sourceID == sourceID && $0.targetID == zoneID
                    }
                    if isOriginalTarget {
                        matchedZoneLinks.insert(sourceID + "|" + zoneID)
                    }
                },
                onOriginalConnectionContact: { sourceID, targetID in
                    let key = sourceID + "|" + targetID
                    if originalMechanismConnections.contains(where: {
                        $0.sourceID == sourceID && $0.targetID == targetID
                    }) {
                        matchedMechanismLinks.insert(key)
                    }
                }
            )
            .id(sceneRevision)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 12) {
                Toggle("Run experimental physics", isOn: $experimentalPhysics)
                    .font(.caption)
                    .onChange(of: experimentalPhysics) { _, _ in
                        physicsPaused = false
                        zoneContacts.removeAll()
                        matchedZoneLinks.removeAll()
                        matchedMechanismLinks.removeAll()
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
                    zoneContacts.removeAll()
                    matchedZoneLinks.removeAll()
                    matchedMechanismLinks.removeAll()
                    sceneRevision = UUID()
                }
                .accessibilityIdentifier("cm.original.quickplay-reset")
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            HStack(spacing: 10) {
                if !experimentalPhysics {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("\(originalEditablePartCount) movable PC puzzle pieces", systemImage: "hand.draw")
                            .font(.caption.weight(.medium))
                        Text("Tap to select · drag to move · twist to rotate · pinch to zoom")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
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
                    zoneContacts.removeAll()
                    matchedZoneLinks.removeAll()
                    matchedMechanismLinks.removeAll()
                    sceneRevision = UUID()
                }
                .font(.caption.weight(.semibold))
                .accessibilityIdentifier("cm.original.quickplay-original-layout")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if experimentalPhysics && hasOriginalCaptureZone {
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                    Text("Objects touching original collection zone: \(zoneContacts.values.reduce(0, +))")
                        .accessibilityIdentifier("cm.original.zone-contact-count")
                    Spacer()
                }
                .font(.caption.weight(.medium))
                .padding(.horizontal, 14)
                if !originalZoneConnections.isEmpty {
                    let total = originalZoneConnections.count
                    let recorded = matchedZoneLinks.count
                    Text("Original linked zone targets: \(recorded) / \(total)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .accessibilityIdentifier("cm.original.linked-zone-progress")
                    if recorded == total {
                        Text("Every explicitly linked object contacted its own zone. Original Windows completion rules are still under reconstruction.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                    }
                }
                if !zoneContacts.isEmpty {
                    // Report the actual object kinds seen by the original
                    // capture-zone sensor, not an invented win condition.
                    Text(zoneContacts.keys.sorted().map { kind in
                        let readable = kind.replacingOccurrences(of: "tmo_", with: "")
                            .replacingOccurrences(of: "_", with: " ")
                        return "\(readable): \(zoneContacts[kind] ?? 0)"
                    }.joined(separator: " · "))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .accessibilityIdentifier("cm.original.zone-contact-types")
                }
                Text("Actual 3D collisions only. Original PC victory rules are not yet decoded.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
            }

            if experimentalPhysics && !originalMechanismConnections.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original linked mechanisms: \(matchedMechanismLinks.count) / \(originalMechanismConnections.count)")
                        .font(.caption.weight(.semibold))
                        .accessibilityIdentifier("cm.original.linked-mechanism-progress")
                    Text("Physical contacts with explicitly linked PC objects; these do not prove puzzle completion.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
            }

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
