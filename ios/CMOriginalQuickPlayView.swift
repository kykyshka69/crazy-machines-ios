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
        let session = CMOriginalGameplaySession(document: document)
        _originalSession = State(initialValue: session)
        _powerCircuit = State(initialValue: Self.restoredCircuit(for: session))
        let mechanical = Self.restoredMechanicalLinks(for: session)
        _originalRopes = State(initialValue: mechanical.ropes)
        _originalBelts = State(initialValue: mechanical.belts)
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

    /// The player's selected cable pairs are stored separately from the
    /// user-owned PC scene. Do not confuse these with decoded Windows wires.
    private static func restoredCircuit(
        for session: CMOriginalGameplaySession
    ) -> CMOriginalPowerCircuit? {
        guard var circuit = CMOriginalPowerCircuit(session: session) else { return nil }
        if let data = UserDefaults.standard.data(forKey: circuit.snapshotStorageKey),
           !circuit.restoreSnapshot(data) {
            UserDefaults.standard.removeObject(forKey: circuit.snapshotStorageKey)
        }
        return circuit
    }

    private static func restoredMechanicalLinks(
        for session: CMOriginalGameplaySession
    ) -> CMOriginalMechanicalSnapshot.Links {
        let key = CMOriginalMechanicalSnapshot.storageKey(sceneSHA256: session.sceneSHA256)
        guard let data = UserDefaults.standard.data(forKey: key) else { return .init() }
        let types = Dictionary(uniqueKeysWithValues: session.objects.map { ($0.id,$0.type) })
        guard let links = CMOriginalMechanicalSnapshot.decode(
            data, sceneSHA256: session.sceneSHA256, objectTypes: types) else {
            UserDefaults.standard.removeObject(forKey: key)
            return .init()
        }
        return links
    }

    private func saveMechanicalLinks() {
        let key = CMOriginalMechanicalSnapshot.storageKey(sceneSHA256: originalSession.sceneSHA256)
        if originalRopes.isEmpty && originalBelts.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
        } else if let data = try? CMOriginalMechanicalSnapshot.encode(
            .init(ropes: originalRopes, belts: originalBelts),
            sceneSHA256: originalSession.sceneSHA256) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    // Open an authentic scene at rest; users arrange original parts before
    // starting the approximate physics simulation, matching the PC play loop.
    @State private var experimentalPhysics = false
    @State private var experimentalMotorDrive = false
    @State private var experimentalMagnetism = false
    @State private var experimentalWiredPower = false
    @State private var powerCircuit: CMOriginalPowerCircuit?
    /// Genuine original script `VELOCITY` initializes rocket child
    /// +0xFC. This is not per-frame evidence of Engine activation.
    private var initialOriginalRocketVelocities: [String: Float] {
        var values: [String: Float] = [:]
        for child in originalSession.objects
            where child.type == "tmo_heat_rocket_rocket" {
            guard let parentID = child.parentID,
                  originalSession.objects.contains(where: {
                    $0.id == parentID && $0.type == "tmo_heat_rocket"
                  }),
                  let evidence = CMOriginalWindowsRocketVelocity.initialChildFC(
                    originalChildType: child.type,
                    sceneFields: child.fields,
                    originalTemplateFields:
                        originalWindowsTemplates?[child.type]?.originalProperties
                  ) else { continue }
            values[child.id] = evidence.initialChildFC
        }
        return values
    }

    // Original generator owner ID → observed signed rotor speed.
    @State private var generatorRotorSpeedsByDeviceID: [String: Float] = [:]
    // Measured angle of the authentic disrupter wheel (+0xD0 on Windows).
    // Original phase interval check decides whether cables conduct.
    @State private var disrupterAnglesByDeviceID: [String: Float] = [:]
    @State private var pendingPowerPlugID: String?
    @State private var ropeEditing = false
    @State private var beltEditing = false
    @State private var pendingBeltWheel: String?
    @State private var originalBelts = Set<CMOriginalDriveBelt.Pair>()
    @State private var beltMessage: String?
    @State private var pendingRopeEndpoint: CMOriginalRope.Endpoint?
    @State private var originalRopes = Set<CMOriginalRope.Pair>()
    @State private var cutOriginalRopes = Set<CMOriginalRope.Pair>()
    @State private var ropeMessage: String?
    @State private var powerConnectionMessage: String?
    @State private var physicsPaused = false
    @State private var sceneRevision = UUID()
    @State private var cameraResetRevision = 0
    @State private var undoPlacementRevision = 0
    @State private var canUndoPlacement = false
    @State private var showAllLevels = false
    @State private var originalTemplatesLoadFinished = false
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
    // Observations from actual SceneKit rigid-body hits against the imported
    // original switch lever, separate from user tap and electric-state logic.
    @State private var observedOriginalLeverStrikers = Set<String>()
    // Actual measured UCM mesh sightlines; not yet Win32 light rays.
    @State private var originalOpticalSightlines: [CMOriginalOpticalSightline] = []
    @State private var originalSolarRays: [String: [Float]] = [:]
    // Live actual SceneKit original rocket UCM frames. These measurements
    // neither establish original Engine thrust nor dispatch a GOAL.
    @State private var observedOriginalRocketAnchors:
        [CMOriginalRocketAnchorTelemetry.Complete] = []
    @State private var observedCandleRocketHeatPairs:
        [CMOriginalRocketCandleHeatPair.Observation] = []
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
    // Evaluate lamp emission from independent wired sources only for now.
    // Solar-powered lamps would require a native coupled optical/electrical
    // solver; a feedback loop must not manufacture its own source energy.
    private var independentOpticalLampPower: [String: Float] {
        guard experimentalPhysics && experimentalWiredPower,
              let network = powerCircuit else { return [:] }
        let signals = network.experimentalNetworkSignals(
            closedSwitchIDs: flippedOriginalSwitchIDs,
            generatorRotorCommandsByDeviceID: generatorRotorSpeedsByDeviceID,
            disrupterRotorAnglesByDeviceID: disrupterAnglesByDeviceID)
        return Dictionary(uniqueKeysWithValues: originalSession.objects.compactMap { object -> (String, Float)? in
            guard object.type == "tmo_power_lamp", let power = signals[object.id] else { return nil }
            return (object.id, power)
        })
    }

    private var experimentalPowerSignals: [String: Float] {
        guard experimentalPhysics && experimentalWiredPower,
              let network = powerCircuit else { return [:] }
        // Actual Win32 battery, generator and reconstructed optical signals,
        // transmitted through explicit pairs of original PC power plugs.
        return network.experimentalNetworkSignals(
            closedSwitchIDs: flippedOriginalSwitchIDs,
            generatorRotorCommandsByDeviceID: generatorRotorSpeedsByDeviceID,
            solarRayContributionsByDeviceID: originalSolarRays,
            disrupterRotorAnglesByDeviceID: disrupterAnglesByDeviceID)
    }

    // Only already wired, original CML terminal pairs which have matched
    // finite nonzero experimental voltage at BOTH device ends render
    // bright. This is a UI trace, NOT a native Win32 current estimate.
    private var experimentalCablePowerSignals:
        [CMOriginalPowerCircuit.Cable: Float] {
        guard let network = powerCircuit else { return [:] }
        return network.experimentalCablePowerSignals(
            powerByDeviceID: experimentalPowerSignals)
    }

    // Three authentic original PC ammeters are present on levels 40,
    // 54 and 94. Native +0xFE instrument input is not decoded yet.
    // In the opt-in wiring prototype only actual main electrical
    // readings can drive their imported original UCM indicators.
    private var originalAmmeterPowerSignals: [String: Float]? {
        guard experimentalPhysics && experimentalWiredPower else { return nil }
        let power = experimentalPowerSignals
        return Dictionary(uniqueKeysWithValues:
            originalSession.objects.compactMap { item -> (String, Float)? in
                guard item.type == "tmo_power_amperemeter",
                      let value = power[item.id], value.isFinite
                else { return nil }
                return (item.id, value)
            })
    }

    private var originalLampVisualFactors: [String: Float]? {
        guard experimentalPhysics && experimentalWiredPower else { return nil }
        let powerByID = experimentalPowerSignals
        var factors: [String: Float] = [:]
        for lamp in originalSession.objects where lamp.type == "tmo_power_lamp" {
            guard let power = powerByID[lamp.id],
                  let fraction = CMOriginalWindowsPowerScalar
                    .lampVisualFactor(power: power)
            else { continue }
            factors[lamp.id] = fraction
        }
        return factors
    }

    private var wiredMotorRotorDriveSignals: [String: Float] {
        let inputs = experimentalPowerSignals
        return Dictionary(uniqueKeysWithValues:
            originalSession.objects.compactMap { rotor -> (String, Float)? in
                guard rotor.type == "tmo_power_motor_rotor",
                      let ownerID = rotor.parentID,
                      let input = inputs[ownerID],
                      let command = CMOriginalWindowsPowerScalar
                        .motorRotorCommand(from: input),
                      command != 0
                else { return nil }
                // The original Win32 GOAL threshold 0.5 does NOT gate
                // the rotor command: even a nonzero subthreshold input
                // produces motor motion. Goal credit is handled separately.
                return (rotor.id, command)
            }
        )
    }

    private var wiredMotorRotorIDs: Set<String> {
        Set(wiredMotorRotorDriveSignals.keys)
    }

    private func creditExperimentalElectricGoals(capturedWhileRunning: Bool = false) {
        guard experimentalPhysics && experimentalWiredPower,
              !physicsPaused || capturedWhileRunning else {
            return
        }
        let eligible = CMOriginalWindowsElectricalGoals.activeGoalIDs(
            session: originalSession,
            powerByDeviceID: experimentalPowerSignals,
            solarRayContributionsByDeviceID: originalSolarRays,
            generatorRotorCommandsByDeviceID: generatorRotorSpeedsByDeviceID
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

    private var hasOriginalSolarCell: Bool {
        originalSession.objects.contains { $0.type == "tmo_power_solarcell" }
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
        originalRopes.removeAll()
        cutOriginalRopes.removeAll()
        originalBelts.removeAll()
        pendingRopeEndpoint = nil
        ropeEditing = false
        ropeMessage = nil
        beltEditing = false
        pendingBeltWheel = nil
        beltMessage = nil
        originalSession = CMOriginalGameplaySession(document: next)
        let mechanical = Self.restoredMechanicalLinks(for: originalSession)
        originalRopes = mechanical.ropes
        originalBelts = mechanical.belts
        objectiveLedger = CMOriginalObjectiveEvidenceLedger(session: originalSession)
        powerCircuit = Self.restoredCircuit(for: originalSession)
        generatorRotorSpeedsByDeviceID.removeAll()
        disrupterAnglesByDeviceID.removeAll()
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
        observedOriginalLeverStrikers.removeAll()
        originalOpticalSightlines.removeAll()
        originalSolarRays.removeAll()
        observedOriginalRocketAnchors.removeAll()
        observedCandleRocketHeatPairs.removeAll()
        generatorRotorSpeedsByDeviceID.removeAll()
        disrupterAnglesByDeviceID.removeAll()
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
        pendingBeltWheel = nil
        beltMessage = nil
        cutOriginalRopes.removeAll()
        pendingRopeEndpoint = nil
        ropeMessage = nil
        powerCircuit?.clearRuntimeCuts()
        // Keep deliberate paired wires but discard an unfinished first click.
        // A stale selection must not connect to a future scene or replay.
        pendingPowerPlugID = nil
        powerConnectionMessage = nil
        physicsPaused = false
        zoneContacts.removeAll()
        matchedZoneLinks.removeAll()
        matchedMechanismLinks.removeAll()
        flippedOriginalSwitchIDs.removeAll()
        observedOriginalLeverStrikers.removeAll()
        originalOpticalSightlines.removeAll()
        originalSolarRays.removeAll()
        observedOriginalRocketAnchors.removeAll()
        observedCandleRocketHeatPairs.removeAll()
        generatorRotorSpeedsByDeviceID.removeAll()
        disrupterAnglesByDeviceID.removeAll()
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
        // Old SceneKit renderer callbacks can arrive after a level change or
        // Replay. Match their source scene lifetime, not just the Run toggle.
        let eventRevision = sceneRevision
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    changeLevel(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
                physicsPaused: physicsPaused || windowsGoalCounter?.completed == true,
                cameraResetRevision: cameraResetRevision,
                undoPlacementRevision: undoPlacementRevision,
                onCanUndoPlacementChange: { value in
                    guard eventRevision == sceneRevision else { return }
                    canUndoPlacement = value
                },
                allowObjectPlacement: true,
                experimentalMotorDrive: experimentalMotorDrive,
                experimentalMagnetism: experimentalMagnetism,
                poweredMotorRotorObjectIDs: wiredMotorRotorIDs,
                poweredMotorRotorDriveSignals: wiredMotorRotorDriveSignals,
                originalLampVisualFactors: originalLampVisualFactors,
                originalAmmeterPowerSignals: originalAmmeterPowerSignals,
                experimentalOriginalRocketFlight: true,
                initialOriginalRocketVelocities: initialOriginalRocketVelocities,
                originalPlayerPowerCables: powerCircuit.map {
                    Array($0.activeCables)
                } ?? [],
                originalPlayerRopes: originalRopes.subtracting(cutOriginalRopes),
                originalRopeEditing: ropeEditing,
                originalPlayerBelts: originalBelts,
                originalOpticalLampPower: independentOpticalLampPower,
                originalBeltEditing: beltEditing,
                originalPlayerCablePowerSignals: experimentalCablePowerSignals,
                configuredPhysicsRoles: experimentalPhysicsRoles,
                onOriginalZoneContact: { type in
                    guard eventRevision == sceneRevision else { return }
                    // The renderer authenticated this event while running. Pause
                    // does not erase it; Stop/Replay invalidates its scene revision.
                    guard experimentalPhysics else { return }
                    // Callback is posted to the main thread by SceneKit bridge.
                    zoneContacts[type, default: 0] += 1
                },
                onLinkedZoneContact: { sourceID, zoneID in
                    guard eventRevision == sceneRevision else { return }
                    // The renderer authenticated this event while running. Pause
                    // does not erase it; Stop/Replay invalidates its scene revision.
                    guard experimentalPhysics else { return }
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
                    guard eventRevision == sceneRevision else { return }
                    // The renderer authenticated this event while running. Pause
                    // does not erase it; Stop/Replay invalidates its scene revision.
                    guard experimentalPhysics else { return }
                    _ = windowsGoalCounter?.recordConnectedToEvent(
                        sourceID: sourceID, targetID: targetID,
                        simulationRunning: true
                    )
                    _ = objectiveLedger?.recordPhysicalContact(
                        sourceID, targetID,
                        isSimulationRunning: true
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
                    guard eventRevision == sceneRevision else { return }
                    // The renderer authenticated this event while running. Pause
                    // does not erase it; Stop/Replay invalidates its scene revision.
                    guard experimentalPhysics else { return }
                    // Real original tmo_ball_* approaches the authored
                    // Test/Catch marker within native Win32 radius 0.1.
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: bucketID,
                        simulationRunning: true
                    )
                    _ = objectiveLedger?.recordGoalStateChanged(
                        bucketID,
                        isSimulationRunning: true
                    )
                    if fourthLevelRun?.recordCapture(
                        ballID: ballID, bucketID: bucketID
                    ) == true, let run = fourthLevelRun {
                        UserDefaults.standard.set(true, forKey: run.storageKey)
                    }
                },
                onOriginalCageCapture: { ballID, cageID in
                    guard eventRevision == sceneRevision else { return }
                    // The renderer authenticated this event while running. Pause
                    // does not erase it; Stop/Replay invalidates its scene revision.
                    guard experimentalPhysics else { return }
                    // Native Win32 Catch/Test path 0x44D874...0x44D9A2
                    // also accepts GOAL-marked tmo_rope_cage containers.
                    // A ball within the original 0.1 spatial target radius
                    // generates one channel-0 event for the cage owner.
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: cageID,
                        simulationRunning: true
                    )
                    _ = objectiveLedger?.recordGoalStateChanged(
                        cageID,
                        isSimulationRunning: true
                    )
                },
                onOriginalPlayerSourceGoal: { originalID in
                    guard eventRevision == sceneRevision else { return }
                    // The renderer authenticated this event while running. Pause
                    // does not erase it; Stop/Replay invalidates its scene revision.
                    guard experimentalPhysics else { return }
                    // Real x86 0x455241 captures the initial source state
                    // in +0xF0. Native 0x434A76/0x434B12 emits channel-0
                    // only AFTER user click changes +0xEC against +0xF0.
                    // The coordinator has already checked that condition
                    // on the real imported, GOAL-marked PC element.
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: originalID,
                        simulationRunning: true
                    )
                    _ = objectiveLedger?.recordGoalStateChanged(
                        originalID,
                        isSimulationRunning: true
                    )
                },
                onOriginalHammerGoal: { ownerID in
                    // Native 0x44BFA5 emits channel 0 after the nail
                    // enters the terminal depth state. The renderer's
                    // reconstructed mechanism captures this while running.
                    guard eventRevision == sceneRevision, experimentalPhysics,
                          originalSession.objects.contains(where: {
                              $0.id == ownerID && $0.type == "tmo_hammer"
                          }) else { return }
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: ownerID, simulationRunning: true)
                    _ = objectiveLedger?.recordGoalStateChanged(
                        ownerID, isSimulationRunning: true)
                },
                onOriginalSteamGoal: { ownerID in
                    guard eventRevision == sceneRevision, experimentalPhysics,
                          originalSession.objects.contains(where: {
                              $0.id == ownerID && ["tmo_boiler", "tmo_pipe_whistle"].contains($0.type)
                          }) else { return }
                    // The SceneKit thermal and pipe adapter is reconstructed.
                    // Native boiler >1 / whistle >=1 cutoffs are distinct.
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: ownerID, simulationRunning: true)
                    _ = objectiveLedger?.recordGoalStateChanged(
                        ownerID, isSimulationRunning: true)
                },
                onOriginalGrillGoal: { ownerID in
                    guard eventRevision == sceneRevision, experimentalPhysics,
                          originalSession.objects.contains(where: {
                              $0.id == ownerID && $0.type == "tmo_heat_grill"
                          }) else { return }
                    // The original thermal predicate uses both accumulated
                    // heat and sausage shade, not rotation alone.
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: ownerID, simulationRunning: true)
                    _ = objectiveLedger?.recordGoalStateChanged(
                        ownerID, isSimulationRunning: true)
                },
                onOriginalFlaskGoal: { ownerID in
                    guard eventRevision == sceneRevision, experimentalPhysics,
                          originalSession.objects.contains(where: {
                              $0.id == ownerID && $0.type == "tmo_flask"
                          }) else { return }
                    // Reconstructed active particle count >5, not heat alone.
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: ownerID, simulationRunning: true)
                    _ = objectiveLedger?.recordGoalStateChanged(
                        ownerID, isSimulationRunning: true)
                },
                onOriginalFlagGoal: { ownerID in
                    guard eventRevision == sceneRevision, experimentalPhysics,
                          originalSession.objects.contains(where: {
                              $0.id == ownerID && $0.type == "tmo_belt_flag"
                          }) else { return }
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: ownerID, simulationRunning: true)
                    _ = objectiveLedger?.recordGoalStateChanged(
                        ownerID, isSimulationRunning: true)
                },
                onOriginalEnvironmentalCandleGoal: { ownerID in
                    guard eventRevision == sceneRevision, experimentalPhysics,
                          originalSession.objects.contains(where: {
                              $0.id == ownerID && ["tmo_candle", "tmo_candle_dyn"].contains($0.type)
                          }) else { return }
                    // Native focused heat and wind dispatch channel 0
                    // for the original candle owner.
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: ownerID, simulationRunning: true)
                    _ = objectiveLedger?.recordGoalStateChanged(
                        ownerID, isSimulationRunning: true)
                },
                onOriginalBalloonGoal: { ownerID in
                    guard eventRevision == sceneRevision, experimentalPhysics,
                          originalSession.objects.contains(where: {
                              $0.id == ownerID && $0.type == "tmo_balloon"
                          }) else { return }
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: ownerID, simulationRunning: true)
                    _ = objectiveLedger?.recordGoalStateChanged(
                        ownerID, isSimulationRunning: true)
                },
                onOriginalCatapultGoal: { ownerID in
                    guard eventRevision == sceneRevision, experimentalPhysics,
                          originalSession.objects.contains(where: {
                              $0.id == ownerID && $0.type == "tmo_catapult"
                          }) else { return }
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: ownerID, simulationRunning: true)
                    _ = objectiveLedger?.recordGoalStateChanged(
                        ownerID, isSimulationRunning: true)
                },
                onOriginalSolarRays: { rays in
                    guard eventRevision == sceneRevision, experimentalPhysics else { return }
                    originalSolarRays = rays
                    creditExperimentalElectricGoals(capturedWhileRunning: true)
                },
                onOriginalFlowerGoal: { ownerID in
                    guard eventRevision == sceneRevision, experimentalPhysics,
                          originalSession.objects.contains(where: {
                              $0.id == ownerID && $0.type == "tmo_light_flower"
                          }) else { return }
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: ownerID, simulationRunning: true)
                    _ = objectiveLedger?.recordGoalStateChanged(
                        ownerID, isSimulationRunning: true)
                },
                onOriginalDisrupterAngle: { disrupterID, wheelAngle in
                    guard eventRevision == sceneRevision else { return }
                    guard experimentalPhysics else { return }
                    guard originalSession.objects.contains(where: {
                        $0.id == disrupterID
                            && $0.type == "tmo_power_disrupter"
                    }) else { return }
                    // Only genuine original wheel->device ownership events.
                    // Missing angle always blocks power, never auto-enables.
                    disrupterAnglesByDeviceID[disrupterID] = wheelAngle
                    creditExperimentalElectricGoals(capturedWhileRunning: true)
                },
                onOriginalGeneratorSignal: { generatorID, rotorSpeed in
                    guard eventRevision == sceneRevision else { return }
                    guard experimentalPhysics else { return }
                    generatorRotorSpeedsByDeviceID[generatorID] = rotorSpeed
                    if CMOriginalWindowsPowerScalar.generatorTriggersGoal(
                        rotor: rotorSpeed) {
                        _ = windowsGoalCounter?.recordGoalEvent(
                            objectID: generatorID, simulationRunning: true)
                    }
                    creditExperimentalElectricGoals(capturedWhileRunning: true)
                },
                onOriginalWindmillSignal: { windmillID, measuredRotorSpeed in
                    guard eventRevision == sceneRevision else { return }
                    guard experimentalPhysics else { return }
                    // The native GOAL predicate is exact; mapping SceneKit
                    // angular velocity to Win32 +0xE0 remains provisional.
                    if CMOriginalWindowsWindmill.triggersGoal(
                        nativeWingsSignal: measuredRotorSpeed) {
                        _ = windowsGoalCounter?.recordGoalEvent(
                            objectID: windmillID, simulationRunning: true)
                    }
                },
                onOriginalPowerPlugTap: { plugID in
                    guard eventRevision == sceneRevision else { return }
                    guard !experimentalPhysics else { return }
                    if let first = pendingPowerPlugID {
                        pendingPowerPlugID = nil
                        if first == plugID {
                            powerConnectionMessage = "Cancelled cable selection"
                        } else if var circuit = powerCircuit {
                            let outcome = circuit.toggleCable(
                                between: first, and: plugID)
                            powerCircuit = circuit
                            if outcome != .rejected,
                               let snapshot = try? circuit.snapshotData() {
                                UserDefaults.standard.set(
                                    snapshot, forKey: circuit.snapshotStorageKey)
                            }
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
                onOriginalRopeTap: { endpoint in
                    guard eventRevision == sceneRevision, !experimentalPhysics, ropeEditing,
                          let object = originalSession.objects.first(where: { $0.id == endpoint.objectID }),
                          CMOriginalRope.accepts(type: object.type, marker: endpoint.marker) else { return }
                    if let first = pendingRopeEndpoint {
                        pendingRopeEndpoint = nil
                        guard let pair = CMOriginalRope.Pair(first, endpoint) else {
                            ropeMessage = "Choose attachments on different objects"
                            return
                        }
                        if originalRopes.remove(pair) != nil {
                            saveMechanicalLinks()
                            ropeMessage = "Rope removed"
                        } else if originalRopes.count < 64,
                                  !originalRopes.contains(where: { existing in
                                      existing.first == first || existing.second == first ||
                                      existing.first == endpoint || existing.second == endpoint
                                  }) {
                            originalRopes.insert(pair)
                            saveMechanicalLinks()
                            ropeMessage = "Original rope attachments connected"
                        } else {
                            ropeMessage = "Attachment already occupied"
                        }
                    } else {
                        pendingRopeEndpoint = endpoint
                        ropeMessage = "Tap the second rope attachment"
                    }
                },
                onOriginalBeltTap: { wheel in
                    guard eventRevision == sceneRevision, !experimentalPhysics, beltEditing,
                          let object = originalSession.objects.first(where: { $0.id == wheel }),
                          CMOriginalDriveBelt.accepts(type: object.type) else { return }
                    if let first = pendingBeltWheel {
                        pendingBeltWheel = nil
                        guard let pair = CMOriginalDriveBelt.Pair(first, wheel) else {
                            beltMessage = "Choose two different original wheels"
                            return
                        }
                        if originalBelts.remove(pair) != nil {
                            saveMechanicalLinks()
                            beltMessage = "Drive belt removed"
                        } else if originalBelts.count < 64 {
                            originalBelts.insert(pair)
                            saveMechanicalLinks()
                            beltMessage = "Drive belt linked (requires separated, aligned wheels)"
                        } else {
                            beltMessage = "Drive belt limit reached"
                        }
                    } else {
                        pendingBeltWheel = wheel
                        beltMessage = "Tap the second original wheel"
                    }
                },
                onOriginalRopeCut: { pair in
                    guard eventRevision == sceneRevision, experimentalPhysics,
                          originalRopes.contains(pair), cutOriginalRopes.insert(pair).inserted else { return }
                    ropeMessage = "Original rope released during simulation"
                },
                onOriginalCableCut: { pair in
                    guard eventRevision == sceneRevision, experimentalPhysics,
                          var circuit = powerCircuit,
                          circuit.applyObservedCableCut(pair) else { return }
                    powerCircuit = circuit
                    // Do not save a simulation cut into editor wiring.
                    powerConnectionMessage = "Original scissors cut a power cable"
                    creditExperimentalElectricGoals(capturedWhileRunning: true)
                },
                onOriginalSwitchToggle: { switchID, isOn in
                    guard eventRevision == sceneRevision, experimentalPhysics else { return }
                    // Renderer-reported actual lever contact, not the tap or
                    // collision command. Pause may follow a valid observation.
                    // The SceneKit closed-pose adapter is provisional; it does
                    // not fabricate native +0xEC/+0xC8 or dispatch switch GOAL.
                    if isOn {
                        flippedOriginalSwitchIDs.insert(switchID)
                    } else {
                        flippedOriginalSwitchIDs.remove(switchID)
                    }
                    creditExperimentalElectricGoals(capturedWhileRunning: true)
                },
                onOriginalSwitchImpactGoal: { ownerID in
                    guard eventRevision == sceneRevision, experimentalPhysics,
                          originalSession.objects.contains(where: {
                              $0.id == ownerID && $0.type == "tmo_power_switch"
                          }) else { return }
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: ownerID, simulationRunning: true)
                    _ = objectiveLedger?.recordGoalStateChanged(
                        ownerID, isSimulationRunning: true)
                },
                onOriginalSwitchContact: { hit in
                    guard eventRevision == sceneRevision else { return }
                    // The renderer authenticated this event while running. Pause
                    // does not erase it; Stop/Replay invalidates its scene revision.
                    guard experimentalPhysics else { return }
                    // Collision evidence is not Win32 +0xEC/+0xC8 closure:
                    // only expose verified original object identities.
                    observedOriginalLeverStrikers.insert(
                        hit.switchID + "|" + hit.strikingObjectID
                    )
                },
                onOriginalOpticalSightlines: { observations in
                    guard eventRevision == sceneRevision else { return }
                    // The renderer authenticated this event while running. Pause
                    // does not erase it; Stop/Replay invalidates its scene revision.
                    guard experimentalPhysics else { return }
                    originalOpticalSightlines = observations
                },
                onOriginalRocketAnchorSnapshots: { snapshots in
                    guard eventRevision == sceneRevision,
                          experimentalPhysics else { return }
                    observedOriginalRocketAnchors = snapshots
                },
                onOriginalCandleRocketHeatPairs: { measured in
                    guard eventRevision == sceneRevision,
                          experimentalPhysics else { return }
                    observedCandleRocketHeatPairs = measured
                },
                onOriginalReconstructedRocketGoal: { parentID, childID in
                    // Recreate the original 0x44F354 goal channel only after
                    // the real rocket model finished its iOS heat/fuse/Engine
                    // sequence, original Explode UCM marker was present,
                    // and the child rigid body was retired exactly once.
                    // The graphical TGA is optional: missing visual assets
                    // cannot block the physical puzzle's objective.
                    // Heat-region/effect parity with PC remains unverified.
                    // The terminal event was captured on an ALREADY
                    // running renderer frame. A subsequent user Pause before
                    // the main-queue delivery must not discard a valid
                    // completed objective forever. Scene revision still
                    // rejects stale level/reset events, while the original
                    // physics terminal gate handles exactly-once delivery.
                    guard eventRevision == sceneRevision,
                          experimentalPhysics,
                          let parent = originalSession.objects.first(where: {
                              $0.id == parentID
                          }),
                          let child = originalSession.objects.first(where: {
                              $0.id == childID
                          }),
                          child.parentID == parentID,
                          CMOriginalRocketTerminalGate
                            .supportsReconstructedGoal(
                                originalParentType: parent.type,
                                originalChildType: child.type,
                                originalParentGoal: parent.goalAnnotation,
                                phase: .ended,
                                genuineOriginalExplodeMarker: true,
                                originalChildPhysicsRetired: true)
                    else { return }
                    _ = windowsGoalCounter?.recordGoalEvent(
                        objectID: parentID, simulationRunning: true)
                    _ = objectiveLedger?.recordGoalStateChanged(
                        parentID, isSimulationRunning: true)
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

            // Win32 0x44B592 emits task_solved/level_done when ALL
            // individually latched native channels have fired. Previous
            // controls were buried in the diagnostics panel, inaccessible
            // on a small iPhone unless the user scrolled past everything.
            // Show the decoded original leveldone.vsc actions directly
            // over the imported PC scene, without faking a solved level
            // from GOAL annotations or merely opening an original file.
            .overlay(alignment: .center) {
                if experimentalPhysics,
                   let counter = windowsGoalCounter, counter.completed {
                    VStack(spacing: 12) {
                        Label(
                            "Original goal inputs received",
                            systemImage: "checkmark.seal.fill"
                        )
                        .font(.headline)
                        Text(
                            "All \(counter.totalRequired) reconstructed Win32 input channels have fired. Full Windows physics parity remains unverified."
                        )
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Button(originalLevelDoneActions?.continueName ?? "Continue") {
                                changeLevel(by: 1)
                            }
                            .disabled(scene(at: document.index + 1) == nil)
                            .accessibilityIdentifier("cm.original.windows-win-next")
                            Button(originalLevelDoneActions?.replayName ?? "Replay") {
                                restartCurrentPuzzle()
                            }
                            .accessibilityIdentifier("cm.original.windows-win-replay")
                            Button(originalLevelDoneActions?.mainMenuName ?? "Main menu") {
                                dismiss()
                            }
                            .accessibilityIdentifier("cm.original.windows-win-menu")
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.bordered)
                    }
                    .padding(18)
                    .frame(maxWidth: 370)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 14)
                    .accessibilityIdentifier("cm.original.windows-leveldone-viewport")
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
                        ropeEditing = false
                        beltEditing = false
                        if !newValue {
                            experimentalMotorDrive = false
                            experimentalMagnetism = false
                            experimentalWiredPower = false
                        }
                        restartCurrentPuzzle()
                    }
                    .disabled(!originalTemplatesLoadFinished)
                    .accessibilityIdentifier("cm.original.quickplay-physics")
                if experimentalPhysics {
                    Button(physicsPaused ? "Resume" : "Pause") {
                        physicsPaused.toggle()
                        if !physicsPaused { creditExperimentalElectricGoals() }
                    }
                    // Explicitly publish the changing control state to
                    // XCUI/VoiceOver. SceneKit may render continuously, so
                    // the accessibility snapshot must expose the live
                    // SwiftUI state rather than rely on a stale button label.
                    .disabled(windowsGoalCounter?.completed == true)
                    .accessibilityLabel(physicsPaused ? "Resume" : "Pause")
                    .accessibilityValue(physicsPaused ? "paused" : "running")
                    .accessibilityIdentifier("cm.original.quickplay-pause")
                }
                Button("Restart") { restartCurrentPuzzle() }
                .accessibilityIdentifier("cm.original.quickplay-reset")
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)

            // Only observed imported rocket-child UCM frames are counted.
            // Do not translate these anchors into guessed native force.
            if experimentalPhysics && originalSession.objects.contains(where: {
                $0.type == "tmo_heat_rocket_rocket"
            }) {
                Text("Original rocket frames: \(observedOriginalRocketAnchors.count); physical centers: \(observedOriginalRocketAnchors.filter { $0.worldDynamicBodyCenter != nil }.count)")
                    .font(.caption.weight(.medium))
                    .accessibilityIdentifier("cm.original.rocket-frames")
            }

            if experimentalPhysics &&
                originalSession.objects.contains(where: {
                    $0.type == "tmo_heat_rocket_rocket"
                }) {
                Text("Original rocket VELOCITY source records: \(initialOriginalRocketVelocities.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("cm.original.rocket-initial-velocity")
            }

            if experimentalPhysics &&
                originalSession.objects.contains(where: {
                    $0.type == "tmo_heat_rocket"
                }) {
                Text("Lit original candle-to-rocket Heat pairs: \(observedCandleRocketHeatPairs.count); experimental rocket flight enabled; native GOAL unverified")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("cm.original.rocket-heat-pairs")
            }

            if experimentalPhysics && hasOriginalSolarCell {
                VStack(alignment: .leading, spacing: 3) {
                    let visible = originalOpticalSightlines.filter {
                        $0.isUnobstructed
                    }.count
                    Text("Original UCM optical paths: \(visible)/\(originalOpticalSightlines.count) unobstructed")
                        .font(.caption.weight(.medium))
                        .accessibilityIdentifier("cm.original.optical-sightlines")
                    Text("Measured between original lamp-bulb or pocketlamp-glass and solar-cell UCM meshes, with real 3D blockers. Windows emission direction, intersection fraction and reflections remain unverified; geometry alone never generates solar power or GOAL.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
            }

            if experimentalPhysics && hasOriginalSwitch {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Original switch contacts closed: \(flippedOriginalSwitchIDs.count)")
                        .font(.caption.weight(.medium))
                        .accessibilityIdentifier("cm.original.switch-toggles")
                    Text("Observed switch lever/striker pairs: \(observedOriginalLeverStrikers.count)")
                        .font(.caption.weight(.medium))
                        .accessibilityIdentifier("cm.original.switch-physical-contacts")
                    Text("Tap an original switch or strike its genuine lever with a movable original object. Electrical power changes when the actual lever reaches or leaves its reconstructed closed pose. Native component-state correspondence and original current remain unverified.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
            }

            if originalSession.objects.filter({ CMOriginalDriveBelt.accepts(type: $0.type) }).count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original drive belts: \(originalBelts.count)")
                        .font(.caption.weight(.semibold))
                    if !experimentalPhysics {
                        Toggle("Connect original drive belts", isOn: $beltEditing)
                            .font(.caption)
                            .onChange(of: beltEditing) { _, enabled in
                                pendingBeltWheel = nil
                                beltMessage = nil
                                if enabled {
                                    ropeEditing = false
                                    pendingRopeEndpoint = nil
                                    pendingPowerPlugID = nil
                                }
                            }
                        if beltEditing {
                            Text("Tap two separated original wheels with aligned Wheel attachments. Tap the pair again to remove its open belt.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        if !originalBelts.isEmpty {
                            Button("Clear drive belts") {
                                originalBelts.removeAll()
                                saveMechanicalLinks()
                                pendingBeltWheel = nil
                                beltMessage = nil
                            }.font(.caption)
                        }
                        if let beltMessage { Text(beltMessage).font(.caption2) }
                    }
                    Text("Open belts transmit rotation in the same direction using original VALF ratios. SceneKit coupling and straight belt spans remain experimental.")
                        .font(.caption2).foregroundStyle(.secondary)
                }.padding(.horizontal, 14).padding(.vertical, 6)
            }

            if originalSession.objects.filter({ object in
                ["Rope", "Rope01", "Rope02"].contains { CMOriginalRope.accepts(type: object.type, marker: $0) }
            }).count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original rope links: \(originalRopes.count - cutOriginalRopes.count) · cut: \(cutOriginalRopes.count)")
                        .font(.caption.weight(.semibold))
                    if !experimentalPhysics {
                        Toggle("Connect original ropes", isOn: $ropeEditing)
                            .font(.caption)
                            .onChange(of: ropeEditing) { _, enabled in
                                if enabled {
                                    beltEditing = false
                                    pendingBeltWheel = nil
                                    beltMessage = nil
                                }
                                pendingRopeEndpoint = nil
                                pendingPowerPlugID = nil
                                ropeMessage = nil
                            }
                        if ropeEditing {
                            Text("Tap two original rope-bearing parts. On a seesaw tap the desired end. Tap the same pair again to remove it.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        if !originalRopes.isEmpty {
                            Button("Clear ropes") {
                                originalRopes.removeAll()
                                cutOriginalRopes.removeAll()
                                saveMechanicalLinks()
                                pendingRopeEndpoint = nil
                                ropeMessage = nil
                            }.font(.caption)
                        }
                    }
                    if let ropeMessage { Text(ropeMessage).font(.caption2) }
                    Text("Ropes pull at authentic UCM attachments when stretched. SceneKit tension and straight visual segments are experimental.")
                        .font(.caption2).foregroundStyle(.secondary)
                }.padding(.horizontal, 14).padding(.vertical, 6)
            }

            if let circuit = powerCircuit, circuit.terminals.count > 1 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original power plugs: \(circuit.terminals.count) · logical cables: \(circuit.cableCount)")
                        .font(.caption.weight(.semibold))
                        .accessibilityIdentifier("cm.original.power-cable-count")
                    if !experimentalPhysics {
                        Text("Tap two genuine 3D power plugs to connect or disconnect them. Connected pairs are drawn with the original power_cable.tga; the SceneKit tube shape is approximate.")
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
                                UserDefaults.standard.removeObject(
                                    forKey: next.snapshotStorageKey)
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
                    Text("Connected original power_cable.tga wires dim when one end has no known matching signal; both ends at the same finite powered value render bright. Battery 10.0 and physically observed generator drive the experimental circuit. Native current, resistance, return paths and polarity remain unverified.")
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
                    originalRopes.removeAll()
                    cutOriginalRopes.removeAll()
                    originalBelts.removeAll()
                    saveMechanicalLinks()
                    pendingRopeEndpoint = nil
                    ropeEditing = false
                    ropeMessage = nil
                    beltEditing = false
                    pendingBeltWheel = nil
                    beltMessage = nil
                    experimentalPhysics = false
                    experimentalMotorDrive = false
                    experimentalMagnetism = false
                    experimentalWiredPower = false
                    if var circuit = powerCircuit {
                        circuit.reset()
                        UserDefaults.standard.removeObject(
                            forKey: circuit.snapshotStorageKey)
                        powerCircuit = circuit
                    }
                    pendingPowerPlugID = nil
                    powerConnectionMessage = nil
                    generatorRotorSpeedsByDeviceID.removeAll()
                    disrupterAnglesByDeviceID.removeAll()
                    physicsPaused = false
                    zoneContacts.removeAll()
                    matchedZoneLinks.removeAll()
                    matchedMechanismLinks.removeAll()
                    flippedOriginalSwitchIDs.removeAll()
                    observedOriginalLeverStrikers.removeAll()
                    originalOpticalSightlines.removeAll()
                    originalSolarRays.removeAll()
        observedOriginalRocketAnchors.removeAll()
        observedCandleRocketHeatPairs.removeAll()
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
                        Text("The original VSC Continue / Replay / Main menu actions are available over the 3D board.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
            // Never replace the running board while retaining old GOAL latches.
            // Initial run is disabled until this first template load completes.
            if !originalTemplatesLoadFinished {
                originalWindowsTemplates = original
                originalTemplatesLoadFinished = true
            }
            // Original PC completion UI is another encrypted script, using
            // the independently recovered tz023416 Value Script key.
            originalLevelDoneActions = await Task.detached(priority: .utility) {
                CMOriginalVSCScriptLibrary.loadLevelDone(directory: directory)
            }.value
        }
        .onChange(of: windowsGoalCounter?.completed == true) { _, completed in
            if completed { physicsPaused = true }
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
