import SwiftUI

/// Opens a user-imported original Professor Laboratory scene directly in 3D.
/// All geometry/coordinates come from the user's PC game assets; this is not
/// the original Windows game engine or a claim of reconstructed puzzle rules.
struct CMOriginalQuickPlayView: View {
    let assetDirectory: URL
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dismiss) private var dismiss
    @AppStorage("cm.original.last-played-level") private var lastPlayedOriginalLevel = 1
    @State private var document: CMOriginalSceneDocument
    // Decode the original hierarchy once per loaded level. SwiftUI
    // recomputes these properties on every physics/status update; rebuilding
    // a 1000-object registry for each frame adds avoidable latency.
    @State private var originalSession: CMOriginalGameplaySession
    // Bounded LRU avoids re-decoding previous/next original JSON levels
    // every time SwiftUI redraws after a physics contact.
    @State private var sceneCache: CMOriginalLevelDocumentCache

    init(document: CMOriginalSceneDocument, assetDirectory: URL) {
        self.assetDirectory = assetDirectory
        _document = State(initialValue: document)
        _originalSession = State(initialValue: CMOriginalGameplaySession(document: document))
        _powerCircuit = State(initialValue: CMOriginalPowerCircuit(
            session: CMOriginalGameplaySession(document: document)))
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = support.appendingPathComponent(
            "OriginalScenes", isDirectory: true)
        _sceneCache = State(initialValue: CMOriginalLevelDocumentCache(
            initial: document, sceneDirectory: directory))
        _firstLevelRun = State(initialValue: CMOriginalFirstLevelRun(document: document))
        _secondLevelRun = State(initialValue: CMOriginalSecondLevelRun(document: document))
        _thirdLevelRun = State(initialValue: CMOriginalThirdLevelRun(document: document))
        _objectiveLedger = State(initialValue:
            CMOriginalObjectiveEvidenceLedger(
                session: CMOriginalGameplaySession(document: document)))
        _windowsGoalCounter = State(initialValue:
            CMOriginalWindowsGoalCounter(
                session: CMOriginalGameplaySession(document: document)))
        _fourthLevelRun = State(initialValue: CMOriginalFourthLevelRun(document: document))
    }

    // Open an authentic scene at rest; users arrange original parts before
    // starting the approximate physics simulation, matching the PC play loop.
    @State private var experimentalPhysics = false
    @State private var experimentalMotorDrive = false
    @State private var experimentalMagnetism = false
    @State private var experimentalWiredPower = false
    @State private var powerCircuit: CMOriginalPowerCircuit?
    // Original generator owner ID → observed signed rotor speed.
    @State private var generatorRotorSpeedsByDeviceID: [String: Float] = [:]
    @State private var pendingPowerPlugID: String?
    @State private var powerConnectionMessage: String?
    @State private var physicsPaused = false
    @State private var sceneRevision = UUID()
    @State private var cameraResetRevision = 0
    @State private var undoPlacementRevision = 0
    @State private var canUndoPlacement = false
    @State private var showAllLevels = false
    @State private var originalWindowsTemplates:
        [String: CMOriginalElementsTemplateCatalog.Template]?
    @State private var originalLevelDoneActions:
        CMOriginalVSCScriptLibrary.CompletionActions?
    @State private var objectiveLedger: CMOriginalObjectiveEvidenceLedger?
    // Recovered from the original CrazyMachines.exe win dispatcher:
    // two separately latched channels, not a generic scene-collision win.
    @State private var windowsGoalCounter: CMOriginalWindowsGoalCounter?
    @State private var zoneContacts: [String: Int] = [:]
    @State private var matchedZoneLinks = Set<String>()
    @State private var matchedMechanismLinks = Set<String>()
    @State private var flippedOriginalSwitchIDs = Set<String>()
    @State private var firstLevelRun: CMOriginalFirstLevelRun?
    @State private var secondLevelRun: CMOriginalSecondLevelRun?
    @State private var thirdLevelRun: CMOriginalThirdLevelRun?
    @State private var fourthLevelRun: CMOriginalFourthLevelRun?
    @State private var showFirstLevelObjectiveDetails = false

    // Reconstruct the PC's explicit CONNECTED_TO references to tmo_zone.
    // The original 0-based indices refer to level_elements.children,
    // not the nested SceneKit hierarchy. GOAL is not a victory rule.
    private var originalConnections: [CMOriginalGameplaySession.OriginalConnection] {
        originalSession.originalConnections
    }

    private var originalZoneConnections: [CMOriginalGameplaySession.OriginalConnection] {
        originalConnections.filter { $0.targetType == "tmo_zone" }
    }

    private var originalMechanismConnections: [CMOriginalGameplaySession.OriginalConnection] {
        originalConnections.filter { $0.targetType != "tmo_zone" }
    }

    /// Each physical role is assigned using the SAME authoritative object
    /// registry as SceneKit bodies and CONNECTED_TO links. Nested mount
    /// objects must not make the object IDs drift.
    private var experimentalPhysicsRoles: [String: CMOriginalGameplaySession.PhysicsRole] {
        CMOriginalPhysicsRolePlanner.roles(
            for: originalSession, originalTemplates: originalWindowsTemplates
        )
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

    private var hasOriginalSwitch: Bool {
        func contains(_ node: CMOriginalSceneDocument.Node) -> Bool {
            node.name == "tmo_power_switch"
                || node.children.contains(where: contains)
        }
        return contains(document.root)
    }

    /// Authored original plug-to-plug pairs plus Win32's actual battery
    /// source value (10.0). This graph remains an OPT-IN topology prototype:
    /// voltage loss and the original electrical solver are not recovered.
    private var experimentalPowerSignals: [String: Float] {
        guard experimentalPhysics && experimentalWiredPower,
              let network = powerCircuit else { return [:] }
        // Actual Win32 battery scalar 10.0 + measured generator speed,
        // transmitted through EXPLICIT pairs of original PC power plugs.
        return network.experimentalNetworkSignals(
            closedSwitchIDs: flippedOriginalSwitchIDs,
            generatorRotorCommandsByDeviceID: generatorRotorSpeedsByDeviceID)
    }

    private var wiredMotorRotorDriveSignals: [String: Float] {
        let inputs = experimentalPowerSignals
        return Dictionary(uniqueKeysWithValues:
            originalSession.objects.compactMap { rotor -> (String, Float)? in
                guard rotor.type == "tmo_power_motor_rotor",
                      let ownerID = rotor.parentID,
                      let input = inputs[ownerID],
                      CMOriginalWindowsPowerScalar.motorTriggersGoal(power: input),
                      let command = CMOriginalWindowsPowerScalar
                        .motorRotorCommand(from: input)
                else { return nil }
                return (rotor.id, command)
            }
        )
    }

    private var wiredMotorRotorIDs: Set<String> {
        Set(wiredMotorRotorDriveSignals.keys)
    }

    private func creditExperimentalElectricGoals() {
        guard experimentalPhysics && experimentalWiredPower && !physicsPaused else {
            return
        }
        let eligible = CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: originalSession, powerByDeviceID: experimentalPowerSignals
        )
        for id in eligible {
            _ = windowsGoalCounter?.recordGoalEvent(
                objectID: id, simulationRunning: true)
        }
    }

    private var hasOriginalMotor: Bool {
        func containsMotor(_ node: CMOriginalSceneDocument.Node) -> Bool {
            node.name == "tmo_power_motor_rotor"
                || node.children.contains(where: containsMotor)
        }
        return containsMotor(document.root)
    }

    private var hasOriginalMagneticTargets: Bool {
        let types = Set(originalSession.objects.map(\.type))
        return types.contains("tmo_magnetic_permanent")
            && types.contains(where: CMOriginalMagneticAttraction.responds)
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
        sceneCache.scene(at: index)
    }

    private func changeLevel(by step: Int) {
        guard let next = scene(at: document.index + step) else { return }
        document = next
        originalSession = CMOriginalGameplaySession(document: next)
        objectiveLedger = CMOriginalObjectiveEvidenceLedger(session: originalSession)
        powerCircuit = CMOriginalPowerCircuit(session: originalSession)
        generatorRotorSpeedsByDeviceID.removeAll()
        pendingPowerPlugID = nil
        powerConnectionMessage = nil
        experimentalWiredPower = false
        windowsGoalCounter = CMOriginalWindowsGoalCounter(session: originalSession)
        firstLevelRun = CMOriginalFirstLevelRun(document: next)
        secondLevelRun = CMOriginalSecondLevelRun(document: next)
        thirdLevelRun = CMOriginalThirdLevelRun(document: next)
        fourthLevelRun = CMOriginalFourthLevelRun(document: next)
        showFirstLevelObjectiveDetails = false
        experimentalPhysics = false
        experimentalMotorDrive = false
        experimentalMagnetism = false
        physicsPaused = false
        zoneContacts.removeAll()
        matchedZoneLinks.removeAll()
        matchedMechanismLinks.removeAll()
        flippedOriginalSwitchIDs.removeAll()
        generatorRotorSpeedsByDeviceID.removeAll()
        firstLevelRun?.reset()
        secondLevelRun?.reset()
                        thirdLevelRun?.reset()
                        fourthLevelRun?.reset()
                        objectiveLedger?.reset()
                        windowsGoalCounter?.reset()
        canUndoPlacement = false
        sceneRevision = UUID()
    }

    /// Same restart action for the normal iPhone control and the genuine
    /// Windows VSC Replay button. No game assets or game-state shortcuts.
    private func restartCurrentPuzzle() {
        physicsPaused = false
        zoneContacts.removeAll()
        matchedZoneLinks.removeAll()
        matchedMechanismLinks.removeAll()
        flippedOriginalSwitchIDs.removeAll()
        generatorRotorSpeedsByDeviceID.removeAll()
        firstLevelRun?.reset()
        secondLevelRun?.reset()
        thirdLevelRun?.reset()
        fourthLevelRun?.reset()
        objectiveLedger?.reset()
        windowsGoalCounter?.reset()
        canUndoPlacement = false
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
                cameraResetRevision: cameraResetRevision,
                undoPlacementRevision: undoPlacementRevision,
                onCanUndoPlacementChange: { canUndoPlacement = $0 },
                allowObjectPlacement: true,
                experimentalMotorDrive: experimentalMotorDrive,
                experimentalMagnetism: experimentalMagnetism,
                poweredMotorRotorObjectIDs: wiredMotorRotorIDs,
                poweredMotorRotorDriveSignals: wiredMotorRotorDriveSignals,
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
                        // Level one's private, evidence-derived prototype
                        // tracker is stricter than generic zone telemetry.
                        // Store the outcome only after the fourth distinct
                        // linked object reaches its actual target zone.
                        if firstLevelRun?.recordContact(
                            sourceID: sourceID, zoneID: zoneID) == true,
                           let run = firstLevelRun, run.isSatisfied {
                            UserDefaults.standard.set(true, forKey: run.storageKey)
                        }
                        // Professor level 3 has FIVE separate crates with
                        // an explicit CONNECTED_TO reference to one zone.
                        // Track only their exact original IDs and collisions.
                        if thirdLevelRun?.recordContact(
                            sourceID: sourceID, zoneID: zoneID) == true,
                           let run = thirdLevelRun, run.isSatisfied {
                            UserDefaults.standard.set(true, forKey: run.storageKey)
                        }
                    }
                },
                onOriginalConnectionContact: { sourceID, targetID in
                    _ = windowsGoalCounter?.recordConnectedToEvent(
                        sourceID: sourceID, targetID: targetID,
                        simulationRunning: experimentalPhysics && !physicsPaused
                    )
                    _ = objectiveLedger?.recordPhysicalContact(
                        sourceID, targetID,
                        isSimulationRunning: experimentalPhysics && !physicsPaused
                    )
                    let key = sourceID + "|" + targetID
                    if originalMechanismConnections.contains(where: {
                        $0.sourceID == sourceID && $0.targetID == targetID
                    }) {
                        matchedMechanismLinks.insert(key)
                        // Original Professor level 2 links a basketball to
                        // a crate, not to its separate tmo_zone. Credit an
                        // actual SceneKit contact between those exact IDs.
                        if secondLevelRun?.recordContact(
                            sourceID: sourceID, targetID: targetID
                        ) == true,
                           let run = secondLevelRun, run.isSatisfied {
                            UserDefaults.standard.set(true, forKey: run.storageKey)
                        }
                    }
                },
                onOriginalBucketCapture: { ballID, bucketID in
                    // Actual imported ball UCM fit inside imported GOAL bucket.
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: bucketID,
                        simulationRunning: experimentalPhysics && !physicsPaused
                    )
                    _ = objectiveLedger?.recordGoalStateChanged(
                        bucketID,
                        isSimulationRunning: experimentalPhysics && !physicsPaused
                    )
                    if fourthLevelRun?.recordCapture(
                        ballID: ballID, bucketID: bucketID
                    ) == true, let run = fourthLevelRun {
                        UserDefaults.standard.set(true, forKey: run.storageKey)
                    }
                },
                onOriginalGeneratorSignal: { generatorID, rotorSpeed in
                    guard experimentalPhysics && !physicsPaused else { return }
                    generatorRotorSpeedsByDeviceID[generatorID] = rotorSpeed
                    if CMOriginalWindowsPowerScalar.generatorTriggersGoal(
                        rotor: rotorSpeed) {
                        _ = windowsGoalCounter?.recordGoalEvent(
                            objectID: generatorID, simulationRunning: true)
                    }
                    creditExperimentalElectricGoals()
                },
                onOriginalPowerPlugTap: { plugID in
                    guard !experimentalPhysics else { return }
                    if let first = pendingPowerPlugID {
                        pendingPowerPlugID = nil
                        if first == plugID {
                            powerConnectionMessage = "Cancelled cable selection"
                        } else if var circuit = powerCircuit {
                            let outcome = circuit.toggleCable(
                                between: first, and: plugID)
                            powerCircuit = circuit
                            switch outcome {
                            case .connected:
                                powerConnectionMessage = "Original plug cable connected"
                            case .disconnected:
                                powerConnectionMessage = "Original plug cable removed"
                            case .rejected:
                                powerConnectionMessage = "Invalid or already occupied plug"
                            }
                        }
                    } else {
                        pendingPowerPlugID = plugID
                        powerConnectionMessage = "Choose the second original power plug"
                    }
                },
                onOriginalSwitchToggle: { switchID, isOn in
                    // Win32 switch mechanism calls its GOAL channel on an
                    // actual lever activation, not on a passive contact.
                    if isOn {
                        _ = windowsGoalCounter?.recordGoalEvent(
                            objectID: switchID,
                            simulationRunning: experimentalPhysics && !physicsPaused
                        )
                    }
                    if isOn {
                        flippedOriginalSwitchIDs.insert(switchID)
                    } else {
                        flippedOriginalSwitchIDs.remove(switchID)
                    }
                    // Power can reach a lamp/lightning only through the
                    // actual chosen plug pairs and closed original switch.
                    creditExperimentalElectricGoals()
                }
            )
            .id(sceneRevision)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(1)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    cameraResetRevision &+= 1
                } label: {
                    Image(systemName: "viewfinder")
                        .font(.title3)
                        .padding(10)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel("Center 3D camera")
                .accessibilityIdentifier("cm.original.quickplay-center-camera")
                .padding(10)
            }
            .overlay(alignment: .topTrailing) {
                if experimentalPhysics && hasOriginalMagneticTargets {
                    // PC level 4's magnet is a real movable original object.
                    // Put its prototype field control over the viewport:
                    // the lower diagnostic panel can be off-screen on iPhone.
                    Button {
                        experimentalMagnetism.toggle()
                    } label: {
                        Label(
                            experimentalMagnetism ? "Magnet ON" : "Magnet OFF",
                            systemImage: "magnet"
                        )
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("cm.original.magnetism-viewport")
                    .accessibilityLabel(
                        experimentalMagnetism
                            ? "Disable experimental magnet attraction"
                            : "Enable experimental magnet attraction"
                    )
                    .padding(10)
                }
            }
            .overlay(alignment: .topLeading) {
                // The original goal must remain visible over the 3D board.
                // The continue action must ALSO remain reachable when the
                // bottom controls are clipped/scrollable on a small iPhone.
                if let run = firstLevelRun {
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: run.isSatisfied
                                  ? "checkmark.seal.fill" : "scope")
                            Text("Deliveries: \(run.deliveredCount)/\(run.totalCount)")
                                .monospacedDigit()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(run.isSatisfied ? Color.green : Color.primary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .accessibilityIdentifier("cm.original.first-level-hud")
                        if run.isSatisfied {
                            Button {
                                changeLevel(by: 1)
                            } label: {
                                Label("Level 2", systemImage: "arrow.right")
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.borderedProminent)
                            .disabled(scene(at: document.index + 1) == nil)
                            .accessibilityIdentifier("cm.original.first-level-next")
                        }
                    }
                    .padding(10)
                } else if let run = secondLevelRun {
                    HStack(spacing: 8) {
                        Label(
                            "Basket → crate: \(run.isSatisfied ? "1/1" : "0/1")",
                            systemImage: run.isSatisfied ? "checkmark.seal.fill" : "scope"
                        )
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .accessibilityIdentifier("cm.original.second-level-hud")
                        if run.isSatisfied {
                            Button {
                                changeLevel(by: 1)
                            } label: {
                                Label("Level 3", systemImage: "arrow.right")
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.borderedProminent)
                            .disabled(scene(at: document.index + 1) == nil)
                            .accessibilityIdentifier("cm.original.second-level-next")
                        }
                    }
                    .padding(10)
                } else if let run = thirdLevelRun {
                    HStack(spacing: 8) {
                        Label(
                            "Crates: \(run.deliveredCount)/\(run.totalCount)",
                            systemImage: run.isSatisfied
                                ? "checkmark.seal.fill" : "scope"
                        )
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .accessibilityIdentifier("cm.original.third-level-hud")
                        if run.isSatisfied {
                            Button {
                                changeLevel(by: 1)
                            } label: {
                                Label("Level 4", systemImage: "arrow.right")
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.borderedProminent)
                            .disabled(scene(at: document.index + 1) == nil)
                            .accessibilityIdentifier("cm.original.third-level-next")
                        }
                    }
                    .padding(10)
                } else if let run = fourthLevelRun {
                    HStack(spacing: 8) {
                        Label(
                            run.isSatisfied ? "Ball inside GOAL bucket"
                                : "Level 4: ball → original bucket",
                            systemImage: run.isSatisfied
                                ? "checkmark.seal.fill" : "scope"
                        )
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 11)
                        .padding(.vertical, 8)
                        .background(.regularMaterial, in: Capsule())
                        .accessibilityIdentifier("cm.original.fourth-level-hud")
                        if run.isSatisfied {
                            Button {
                                changeLevel(by: 1)
                            } label: {
                                Label("Level 5", systemImage: "arrow.right")
                            }
                            .font(.caption.weight(.semibold))
                            .buttonStyle(.borderedProminent)
                            .disabled(scene(at: document.index + 1) == nil)
                            .accessibilityIdentifier("cm.original.fourth-level-next")
                        }
                    }
                    .padding(10)
                } else {
                    // Higher original scenes retain factual object HUDs.
                    // Every value below is derived from the actual imported
                    // CML scene and observed SceneKit contacts; none is a
                    // guessed Windows victory condition.
                    HStack(spacing: 7) {
                        Image(systemName: experimentalPhysics
                              ? "point.3.connected.trianglepath.dotted"
                              : "hand.draw")
                        Text(experimentalPhysics
                             ? (originalConnections.isEmpty
                                ? "Original objects: \(document.root.objectCount)"
                                : "Linked contacts: \(matchedZoneLinks.count + matchedMechanismLinks.count)/\(originalConnections.count)")
                             : "Movable original parts: \(originalEditablePartCount)")
                            .monospacedDigit()
                            .accessibilityIdentifier("cm.original.general-level-hud")
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(10)
                }
            }

            // The original PC puzzle needs a usable 3D board even after
            // contacts, motors and goals populate the status panel. Keep the
            // board flexible and scroll secondary controls independently.
            ScrollView(.vertical) {
                VStack(spacing: 0) {
            HStack(spacing: 12) {
                Toggle("Run experimental physics", isOn: $experimentalPhysics)
                    .font(.caption)
                    .onChange(of: experimentalPhysics) { _, newValue in
                        if !newValue {
                            experimentalMotorDrive = false
                            experimentalMagnetism = false
                            experimentalWiredPower = false
                        }
                        physicsPaused = false
                        zoneContacts.removeAll()
                        matchedZoneLinks.removeAll()
                        matchedMechanismLinks.removeAll()
                        flippedOriginalSwitchIDs.removeAll()
                        generatorRotorSpeedsByDeviceID.removeAll()
                        firstLevelRun?.reset()
        secondLevelRun?.reset()
                        thirdLevelRun?.reset()
                        fourthLevelRun?.reset()
                        objectiveLedger?.reset()
                        windowsGoalCounter?.reset()
                        // Rebuild bodies only after changing scene physics mode.
                        canUndoPlacement = false
                        sceneRevision = UUID()
                    }
                    .accessibilityIdentifier("cm.original.quickplay-physics")
                if experimentalPhysics {
                    Button(physicsPaused ? "Resume" : "Pause") {
                        physicsPaused.toggle()
                        if !physicsPaused { creditExperimentalElectricGoals() }
                    }
                    .accessibilityIdentifier("cm.original.quickplay-pause")
                }
                Button("Restart") { restartCurrentPuzzle() }
                .accessibilityIdentifier("cm.original.quickplay-reset")
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            if experimentalPhysics && hasOriginalSwitch {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Original switch levers flipped: \(flippedOriginalSwitchIDs.count)")
                        .font(.caption.weight(.medium))
                        .accessibilityIdentifier("cm.original.switch-toggles")
                    Text("Tap an original switch in the 3D scene to move its lever. The original wiring is still unknown, so this does not automatically power a motor.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
            }

            if let circuit = powerCircuit, circuit.terminals.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original power plugs: \(circuit.terminals.count) · logical cables: \(circuit.cableCount)")
                        .font(.caption.weight(.semibold))
                        .accessibilityIdentifier("cm.original.power-cable-count")
                    if !experimentalPhysics {
                        Text("Tap two original 3D power plugs to connect/remove their terminals. Original cable geometry is not faked.")
                            .font(.caption2).foregroundStyle(.secondary)
                        if pendingPowerPlugID != nil {
                            Text("First plug selected; tap a second original plug")
                                .font(.caption2.weight(.medium))
                        }
                        if circuit.cableCount > 0 {
                            Button("Clear experimental cables") {
                                var next = circuit
                                next.reset()
                                powerCircuit = next
                                pendingPowerPlugID = nil
                                powerConnectionMessage = nil
                            }.font(.caption)
                        }
                    } else {
                        let reachable = circuit.reachableDevices(
                            closedSwitchIDs: flippedOriginalSwitchIDs)
                        Text("Battery-reachable devices: \(reachable.count). An open switch blocks transmission.")
                            .font(.caption2).foregroundStyle(.secondary)
                        if circuit.cableCount > 0 {
                            Toggle("Experimental battery-powered mechanisms",
                                   isOn: $experimentalWiredPower)
                                .font(.caption)
                                .onChange(of: experimentalWiredPower) { _, enabled in
                                    if enabled { creditExperimentalElectricGoals() }
                                }
                                .accessibilityIdentifier("cm.original.wired-motor-drive")
                        }
                    }
                    if let message = powerConnectionMessage {
                        Text(message).font(.caption2)
                            .accessibilityIdentifier("cm.original.power-cable-message")
                    }
                    Text("Win32: battery source 10.0; spinning generator outputs abs(rotor speed). Lamp GOAL >3, lightning >1, generator >1. Cable graph, generator units, return paths and motor torque remain experimental.")
                        .accessibilityIdentifier("cm.original.generator-power-rules")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }

            if experimentalPhysics && hasOriginalMagneticTargets {
                Toggle("Experimental magnet attraction", isOn: $experimentalMagnetism)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 14)
                    .accessibilityIdentifier("cm.original.magnetism")
                Text("Approximate force on original buckets and steel balls. Windows magnet strength, radius and victory rules are not recovered.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
            }

            if experimentalPhysics && hasOriginalMotor {
                HStack(spacing: 8) {
                    Toggle("Experimental motor drive", isOn: $experimentalMotorDrive)
                        .font(.caption.weight(.medium))
                        .accessibilityIdentifier("cm.original.motor-drive")
                    Text("prototype")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                Text("Applies controlled rotation to original PC motor rotors. Electrical wiring and original motor speed are not yet decoded.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .accessibilityIdentifier("cm.original.motor-drive-note")
            }

            HStack(spacing: 10) {
                if !experimentalPhysics {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("\(originalEditablePartCount) movable PC puzzle pieces", systemImage: "hand.draw")
                            .font(.caption.weight(.medium))
                        Text("Tap · drag part · two-finger camera pan · twist · pinch")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("cm.original.quickplay-arrange-hint")
                } else {
                    Text("Stop physics to return to object placement.")
                        .font(.caption)
                }
                Spacer(minLength: 6)
                Button {
                    undoPlacementRevision &+= 1
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .font(.caption.weight(.semibold))
                .disabled(!canUndoPlacement || experimentalPhysics)
                .accessibilityIdentifier("cm.original.quickplay-undo")
                Button("Original layout") {
                    UserDefaults.standard.removeObject(
                        forKey: "cm.original.positions.\(document.sceneSHA256)"
                    )
                    UserDefaults.standard.removeObject(
                        forKey: "cm.original.rotations.\(document.sceneSHA256)"
                    )
                    experimentalPhysics = false
                    experimentalMotorDrive = false
                    experimentalMagnetism = false
                    physicsPaused = false
                    zoneContacts.removeAll()
                    matchedZoneLinks.removeAll()
                    matchedMechanismLinks.removeAll()
                    flippedOriginalSwitchIDs.removeAll()
                    firstLevelRun?.reset()
        secondLevelRun?.reset()
                        thirdLevelRun?.reset()
                        fourthLevelRun?.reset()
                        objectiveLedger?.reset()
                        windowsGoalCounter?.reset()
                    canUndoPlacement = false
                    sceneRevision = UUID()
                }
                .font(.caption.weight(.semibold))
                .accessibilityIdentifier("cm.original.quickplay-original-layout")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            if let run = fourthLevelRun {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Level 4: original tennis ball into GOAL bucket")
                        .font(.caption.weight(.semibold))
                    Text("Move the genuine UNLOCKED magnet and start physics. The tennis ball must enter the bucket, not touch its outside. This is an experimental iPhone objective, not a verified Windows victory rule.")
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(run.isSatisfied ? "Captured" : "Not captured")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .accessibilityIdentifier("cm.original.fourth-level-progress")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            if let run = thirdLevelRun {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Level 3: five original crate → zone links")
                        .font(.caption.weight(.semibold))
                    Text("Arrange the UNLOCKED spring and start physics. This experimental objective records actual contacts of the five linked crates with their original target zone.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\(run.deliveredCount) / \(run.totalCount)")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .accessibilityIdentifier("cm.original.third-level-progress")
                    if run.isSatisfied {
                        Text("All five original links contacted. Recovered Windows physics and victory rules are not yet verified.")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                // Keep the inner progress label's own accessibility ID.
                // Applying an ID to this container overrides child IDs in
                // UIKit's accessibility tree on iPhone Simulator.
            }

            if let run = secondLevelRun {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Level 2: original basketball → crate link")
                        .font(.caption.weight(.semibold))
                    Text("Arrange the three UNLOCKED dominoes, then start physics. This prototype checks the basketball's actual contact with its CONNECTED_TO crate, not the separate collection zone.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(run.isSatisfied ? "1 / 1" : "0 / 1")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .accessibilityIdentifier("cm.original.second-level-progress")
                    if run.isSatisfied {
                        Text("Original object link contacted. Windows victory logic remains under reconstruction.")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                // Keep the inner progress label's own accessibility ID.
                // Applying an ID to this container overrides child IDs in
                // UIKit's accessibility tree on iPhone Simulator.
            }

            if let run = firstLevelRun {
                VStack(alignment: .leading, spacing: 5) {
                    // Keep the 3D viewport large enough for finger-driven
                    // board placement. The four-item checklist is expandable
                    // instead of permanently occupying half the iPhone screen.
                    DisclosureGroup(
                        isExpanded: $showFirstLevelObjectiveDetails
                    ) {
                        Text("Move the two UNLOCKED boards, start physics, and deliver each of the four original PC objects to its CONNECTED_TO zone.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(run.targets) { target in
                            HStack(spacing: 7) {
                                Image(systemName: run.isDelivered(target)
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(run.isDelivered(target)
                                                     ? Color.green : Color.secondary)
                                Text(target.displayName)
                                    .font(.caption)
                                Spacer()
                            }
                        }
                        if UserDefaults.standard.bool(forKey: run.storageKey)
                            && !run.isSatisfied {
                            Text("Prototype goal reached in an earlier run.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Text("Level 1 deliveries")
                                .font(.caption.weight(.semibold))
                            Spacer(minLength: 5)
                            Text("\(run.deliveredCount) / \(run.totalCount)")
                                .font(.caption.monospacedDigit().weight(.semibold))
                                .accessibilityIdentifier("cm.original.first-level-progress")
                        }
                    }
                    ProgressView(value: Double(run.deliveredCount),
                                 total: Double(run.totalCount))
                    if run.isSatisfied {
                        Text("Prototype target reached: four authentic linked-zone contacts. Original Windows victory logic is still unknown.")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                            .accessibilityIdentifier("cm.original.first-level-prototype-complete")
                        // The actionable Continue control lives over
                        // the 3D viewport and remains visible without
                        // scrolling this long diagnostics panel.
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .accessibilityIdentifier("cm.original.first-level-challenge")
            }

            // These are actual, independently latched Windows-style win
            // inputs. Incomplete mechanism and power simulation remains
            // explicitly experimental; a count does not prove parity.
            if experimentalPhysics, let counter = windowsGoalCounter {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Label("Original Windows win inputs", systemImage: "checkmark.circle")
                        Spacer()
                        Text("\(counter.credited) / \(counter.totalRequired)")
                            .monospacedDigit()
                    }
                    .font(.caption.weight(.semibold))
                    .accessibilityIdentifier("cm.original.windows-win-counter")
                    Text("Win32 GOAL / CONNECTED_TO counter. Some credited electrical inputs use an explicitly experimental battery-cable graph; this is not proof of Windows physics parity.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if counter.completed {
                        Text("All reconstructed win inputs fired. Original Windows mechanism parity has not been established.")
                            .font(.caption.weight(.semibold))
                        if let actions = originalLevelDoneActions {
                            // Text and IDs are from the user's genuine
                            // encrypted gui/leveldone.vsc, not fabricated
                            // button names or hardcoded Windows screen art.
                            HStack {
                                Button(actions.continueName) {
                                    changeLevel(by: 1)
                                }
                                .disabled(scene(at: document.index + 1) == nil)
                                .accessibilityIdentifier("cm.original.windows-win-next")
                                Button(actions.replayName) {
                                    restartCurrentPuzzle()
                                }
                                .accessibilityIdentifier("cm.original.windows-win-replay")
                                Button(actions.mainMenuName) { dismiss() }
                                    .accessibilityIdentifier("cm.original.windows-win-menu")
                            }
                            .font(.caption.weight(.semibold))
                        } else {
                            Button("Continue to level \(document.index + 1) (experimental)") {
                                changeLevel(by: 1)
                            }
                            .disabled(scene(at: document.index + 1) == nil)
                            .accessibilityIdentifier("cm.original.windows-win-next")
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }

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
            }
            .frame(maxHeight: verticalSizeClass == .compact ? 120 : 260)
            .accessibilityIdentifier("cm.original.quickplay-controls")
        }
        .navigationTitle("Crazy Machines")
        .onAppear {
            lastPlayedOriginalLevel = document.index
        }
        .task {
            // Decode only user-installed genuine Windows templates off-main.
            let directory = assetDirectory
            let original = await Task.detached(priority: .utility) {
                CMOriginalWindowsScriptLibrary.load(directory: directory)
            }.value
            if let original {
                originalWindowsTemplates = original
                if experimentalPhysics { sceneRevision = UUID() }
            }
            // Original PC completion UI is another encrypted script, using
            // the independently recovered tz023416 Value Script key.
            originalLevelDoneActions = await Task.detached(priority: .utility) {
                CMOriginalVSCScriptLibrary.loadLevelDone(directory: directory)
            }.value
        }
        .onChange(of: document.index) { _, newIndex in
            lastPlayedOriginalLevel = newIndex
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .navigationDestination(isPresented: $showAllLevels) {
            CMOriginalLevelBrowserView()
        }
    }
}
