import SwiftUI
import SceneKit
import simd

/// Contact groups for 2.5D physics assembled from original PC objects.
/// These are SceneKit simulation-layer choices, not Windows collision flags.
/// An axle must touch other gears and balls but not the housing that holds it.
private enum CMOriginalPhysicsLayers {
    static let object = 1
    static let axle = 2
    static let housing = 4
    static let zone = 8

    static let housingKinds: Set<String> = [
        "tmo_belt_conveyer",
        "tmo_power_motor",
        "tmo_power_generator",
        "tmo_power_disrupter",
        "tmo_windmill",
        "tmo_hammer",
        "tmo_belt_flag",
        "tmo_heat_grill"
    ]

    static func category(for kind: String) -> Int {
        if kind == "tmo_zone" { return zone }
        if CMOriginalAxleParts.rotatingKinds.contains(kind) { return axle }
        if housingKinds.contains(kind) { return housing }
        return object
    }

    static func collisionMask(for category: Int) -> Int {
        switch category {
        case axle: return object | axle
        case housing: return object
        case zone: return 0
        default: return object | axle | housing
        }
    }

    static func contactMask(for category: Int) -> Int {
        switch category {
        case axle: return object | axle | zone
        case housing: return object
        case zone: return object | axle
        default: return object | axle | housing | zone
        }
    }
}

/// Interactive assembly of authentic UCM meshes at original scene POS coordinates.
/// Missing meshes are omitted and reported, never replaced with invented shapes.
/// Preserve the original object identity without relying on unavailable SCNNode.userData.
private final class CMOriginalObjectMeshNode: SCNNode {
    var originalObjectID: String?

    init(geometry: SCNGeometry) {
        super.init()
        self.geometry = geometry
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

/// A physics owner retains its original transform identifier for reset and inspection.
private final class CMOriginalPhysicsOwnerNode: SCNNode {
    var originalObjectID: String?
    // Decoded directly from the PC level's tmo_ object field UNLOCKED 1.
    // Only these pieces may be repositioned while solving the puzzle.
    var isUnlockedInOriginalLevel = false

    override init() {
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

 
/// Reuse immutable, decoded SceneKit UCM geometry across original levels.
/// 102 Professor scenes reference only a much smaller set of source meshes;
/// the previous per-scene cache re-parsed the same UCM on every Next tap.
/// Never cache mutable physics nodes or author transforms. Highlights and
/// moving conveyor materials are copied per instance by the scene builder.
/// NSCache can discard entries under iOS memory pressure.
private enum CMOriginalSharedGeometryCache {
    static let geometries: NSCache<NSString, SCNGeometry> = {
        let cache = NSCache<NSString, SCNGeometry>()
        cache.countLimit = 72
        // An approximate upper bound: the decoded vertex arrays and SceneKit
        // sources can occupy several times the on-disk UCM byte count.
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()

    static func key(for url: URL, modelReference: String) -> NSString {
        // Original PC material variants can share one UCM file while using
        // different textures. Do not collapse them by filename alone.
        (url.standardizedFileURL.path + "|" + modelReference) as NSString
    }

    static func cost(for url: URL) -> Int {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return max(1, bytes * 4)
    }
}

struct CMOriginalAssembledSceneView: UIViewRepresentable {
    let document: CMOriginalSceneDocument
    let assetDirectory: URL
    var experimentalPhysics = false
    var physicsPaused = false
    // Incrementing this value recenters the camera without rebuilding the
    // original geometry or resetting the player's saved arrangement.
    var cameraResetRevision = 0
    // Undo one saved move or rotation without resetting all other pieces.
    var undoPlacementRevision = 0
    var onCanUndoPlacementChange: ((Bool) -> Void)? = nil
    // Permits moving the original PC objects while the simulation is stopped.
    // Defaults off for read-only inspectors and other embedded scene previews.
    var allowObjectPlacement = false
    var diagnosticHinges = false
    // Direct finger impulses are a diagnostic feature, not a Crazy Machines
    // gameplay action. Keep them disabled in the player-facing original levels.
    var diagnosticTapImpulses = false
    // Opt-in mechanical drive for the 49 authentic PC motor rotors.
    // The Windows electric-circuit rules are not yet decoded; do not
    // automatically energize every motor when starting a puzzle.
    var experimentalMotorDrive = false
    var experimentalMagnetism = false
    var poweredMotorRotorObjectIDs: Set<String> = []
    // Signed Win32 command (-power) for original UCM motor rotors.
    // Actual angular-speed/torque scaling is still a bounded prototype.
    var poweredMotorRotorDriveSignals: [String: Float] = [:]
    // Optional experimental electrical power, expressed with the actual
    // Win32 lamp visual factor (+0x40 / 10). Nil means no wired experiment.
    var originalLampVisualFactors: [String: Float]? = nil
    var originalAmmeterPowerSignals: [String: Float]? = nil
    // Optional per-physics-update ORIGINAL Engine samples. Empty in the
    // player until native +0xFC, parent state, and Engine activation are
    // genuinely observable; never infer them from VALF/VELOCITY.
    var originalNativeRocketEngineObservations:
        [CMOriginalRocketForceDelivery.Observation] = []
    // Playable approximation using ORIGINAL moving UCM markers, not native GOAL.
    var experimentalOriginalRocketFlight = false
    var initialOriginalRocketVelocities: [String: Float] = [:]
    // Real player-authored original power-plug pairs. Cable visuals use
    // genuine power_cable.tga and exact original plug transforms. No
    // artificial wires are inferred from VALF IDs or object proximity.
    var originalPlayerPowerCables: [CMOriginalPowerCircuit.Cable] = []
    var originalPlayerRopes: Set<CMOriginalRope.Pair> = []
    var originalRopeEditing = false
    var originalPlayerBelts: Set<CMOriginalDriveBelt.Pair> = []
    var originalOpticalLampPower: [String: Float] = [:]
    var originalBeltEditing = false
    // Live, matched experimental network signals for original player
    // wires. These change cable brightness only, NEVER native current.
    var originalPlayerCablePowerSignals:
        [CMOriginalPowerCircuit.Cable: Float] = [:]
    var configuredPhysicsRoles: [String: CMOriginalGameplaySession.PhysicsRole] = [:]
    var configuredReactions: [CMOriginalGameplaySession.ReactionRule] = []
    var switchPressCount = 0
    // SceneKit collision telemetry for authentic PC capture zones.
    // This does NOT assert that the Windows level completion condition is met.
    var onOriginalZoneContact: ((String) -> Void)? = nil
    // Exact IDs of the source object and the original capture zone it touched.
    var onLinkedZoneContact: ((String, String) -> Void)? = nil
    // A contact matching any exact CONNECTED_TO reference in the recovered
    // PC level (not only tmo_zone targets). This is observation, not victory.
    var onOriginalConnectionContact: ((String, String) -> Void)? = nil
    var onOriginalBucketCapture: ((String, String) -> Void)? = nil
    var onOriginalCageCapture: ((String, String) -> Void)? = nil
    // Native original click produces a GOAL only if +0xEC differs
    // from its original start-of-run snapshot at +0xF0.
    var onOriginalPlayerSourceGoal: ((String) -> Void)? = nil
    // Native hammer terminal depth callback, reconstructed SceneKit cycle.
    var onOriginalHammerGoal: ((String) -> Void)? = nil
    var onOriginalSteamGoal: ((String) -> Void)? = nil
    var onOriginalGrillGoal: ((String) -> Void)? = nil
    var onOriginalFlaskGoal: ((String) -> Void)? = nil
    var onOriginalFlagGoal: ((String) -> Void)? = nil
    var onOriginalEnvironmentalCandleGoal: ((String) -> Void)? = nil
    var onOriginalBalloonGoal: ((String) -> Void)? = nil
    var onOriginalCatapultGoal: ((String) -> Void)? = nil
    var onOriginalSolarRays: (([String: [Float]]) -> Void)? = nil
    var onOriginalFlowerGoal: ((String) -> Void)? = nil
    // Reports a user-operated original PC power switch. This changes its
    // actual lever mesh, NOT the unrecovered electrical connectivity.
    var onOriginalDisrupterAngle: ((String, Float) -> Void)? = nil
    var onOriginalGeneratorSignal: ((String, Float) -> Void)? = nil
    var onOriginalWindmillSignal: ((String, Float) -> Void)? = nil
    var onOriginalPowerPlugTap: ((String) -> Void)? = nil
    var onOriginalRopeTap: ((CMOriginalRope.Endpoint) -> Void)? = nil
    var onOriginalBeltTap: ((String) -> Void)? = nil
    var onOriginalRopeCut: ((CMOriginalRope.Pair) -> Void)? = nil
    var onOriginalCableCut: ((CMOriginalPowerCircuit.Cable) -> Void)? = nil
    var onOriginalSwitchToggle: ((String, Bool) -> Void)? = nil
    var onOriginalSwitchImpactGoal: ((String) -> Void)? = nil
    // Contact pairs from the actual imported PC switch lever and striker.
    // This reports a physical event; it does not invent Win32 +0xEC/+0xC8
    // component scalars or energize the unverified electrical network.
    var onOriginalSwitchContact: ((CMOriginalSwitchContactMapper.Hit) -> Void)? = nil
    // Real UCM mesh-to-mesh visibility, NOT a decoded Win32 ray or GOAL.
    var onOriginalOpticalSightlines: (([CMOriginalOpticalSightline]) -> Void)? = nil
    // Real moving original rocket child UCM marker poses, NOT rocket GOAL.
    var onOriginalRocketAnchorSnapshots:
        (([CMOriginalRocketAnchorTelemetry.Complete]) -> Void)? = nil
    // Actual lit native candle +0xEC and imported UCM Heat geometry.
    // NOT a native thermal region hit or ignition transition.
    var onOriginalCandleRocketHeatPairs:
        (([CMOriginalRocketCandleHeatPair.Observation]) -> Void)? = nil
    // Win32 0x44F354 GOAL branch recreated in SceneKit after authentic
    // UCM Explode marker and one-shot physical retirement. This is an
    // explicitly reconstructed gameplay event, NOT native runtime proof.
    var onOriginalReconstructedRocketGoal: ((String, String) -> Void)? = nil

    private var physicsAccessibilityStatus: String {
        let state = experimentalPhysics ? (physicsPaused ? "paused" : "running") : "off"
        return "\(document.root.goalCount) original goal markers; physics \(state)"
    }

    /// Simulator-only rendering diagnostics: accessibility exposes whether
    /// imported UCM geometry is present in the SceneKit graph. The CI visual
    /// smoke test can now distinguish an asset-loading regression from a
    /// camera/rendering regression instead of reporting only "black screen".
    #if DEBUG && targetEnvironment(simulator)
    private func sceneDebugStatus(_ scene: SCNScene?) -> String {
        guard let scene else { return "; scene=missing" }
        var meshes = 0
        var originalMeshes = 0
        var visualGlowBillboards = 0
        var diagnosticMarkers = 0
        scene.rootNode.enumerateChildNodes { node, _ in
            guard node.geometry != nil else { return }
            meshes += 1
            if node is CMOriginalObjectMeshNode { originalMeshes += 1 }
            if node.name?.hasPrefix("original-effect-glow-") == true {
                visualGlowBillboards += 1
            }
            if node.name == "cm-ci-render-calibration" {
                diagnosticMarkers += 1
            }
        }
        // Count expected renderable 3DO instances from the SAME traversal
        // rules used by buildScene. Never deduplicate model names here:
        // separate balls or beams using one UCM still need separate nodes.
        var expectedOriginalMeshes = 0
        var expectedVisualGlows = 0
        func countReference(_ name: String) {
            if CMOriginalEffectBillboard.specification(for: name) != nil {
                expectedVisualGlows += 1
            } else {
                expectedOriginalMeshes += 1
            }
        }
        func visitReferences(_ item: CMOriginalSceneDocument.Node) {
            if item.name.hasPrefix("3DO ") {
                countReference(String(item.name.dropFirst(4)))
            }
            for name in CMOriginalModelResolver.fallbackModelNames(in: item) {
                countReference(name)
            }
            for child in item.children {
                visitReferences(child)
            }
        }
        visitReferences(document.root)
        let camera = scene.rootNode.childNode(
            withName: "original-level-camera", recursively: false)
        let position = camera?.position ?? SCNVector3Zero
        let forward = camera?.convertVector(
            SCNVector3(0, 0, -1), to: nil) ?? SCNVector3Zero
        // Stamp the CURRENT imported level so a 102-level UI sweep cannot
        // accidentally read the previous SceneKit view's mesh statistics
        // while SwiftUI is replacing the scene after Next.
        return "; sceneLevel=\(document.index); sceneMeshes=\(meshes)" +
            "; originalUCM=\(originalMeshes)" +
            "; expectedUCM=\(expectedOriginalMeshes)" +
            "; glowBillboards=\(visualGlowBillboards)" +
            "; expectedGlows=\(expectedVisualGlows)" +
            "; calibration=\(diagnosticMarkers); camera=" +
            "\(position.x),\(position.y),\(position.z)" +
            "; forward=\(forward.x),\(forward.y),\(forward.z)"
    }
    #endif

    #if DEBUG && targetEnvironment(simulator)
    /// SceneKit can exist in the scene graph while its Metal layer remains
    /// black in CI captures. SCNView.snapshot() asks SceneKit to render an
    /// independent image: it distinguishes a capture/compositing problem
    /// from a camera or renderer problem without altering genuine PC art.
    private static func ciSceneSnapshotColors(_ image: UIImage) -> (orange: Int, cyan: Int) {
        guard let cg = image.cgImage else { return (0, 0) }
        let side = 72
        var rgba = [UInt8](repeating: 0, count: side * side * 4)
        let decoded = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let address = buffer.baseAddress,
                  let context = CGContext(
                    data: address, width: side, height: side,
                    bitsPerComponent: 8, bytesPerRow: side * 4,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                  ) else { return false }
            context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard decoded else { return (0, 0) }
        var orange = 0
        var cyan = 0
        for offset in stride(from: 0, to: rgba.count, by: 4) {
            let r = Int(rgba[offset]), g = Int(rgba[offset + 1])
            let b = Int(rgba[offset + 2])
            if r >= 140 && g >= 40 && r >= g + 35 && g >= b + 25 {
                orange += 1
            }
            if g >= 120 && b >= 120 && r + 45 <= g && r + 45 <= b {
                cyan += 1
            }
        }
        return (orange, cyan)
    }
    #endif

    #if DEBUG && targetEnvironment(simulator)
    /// Counts ONLY parsed original UCM drawables, not synthetic calibration
    /// nodes, physics proxies or decorative SwiftUI controls.
    private func loadedSceneOriginalMeshCount(_ scene: SCNScene) -> Int {
        var count = 0
        scene.rootNode.enumerateChildNodes { node, _ in
            if node is CMOriginalObjectMeshNode, node.geometry != nil { count += 1 }
        }
        return count
    }
    #endif

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = UIColor(white: 0.09, alpha: 1)
        view.accessibilityIdentifier = "cm.original.assembled-scene"
        view.accessibilityLabel = "Original level 3D scene"
        view.accessibilityHint = experimentalPhysics
            ? (diagnosticHinges
               ? "Diagnostic mode: double tap two parts for a hinge, or long-press to change their physics type."
               : "Original puzzle is running. Pause, stop or restart the experiment; parts cannot be rearranged during motion.")
            : (allowObjectPlacement
               ? "Only UNLOCKED parts from the original PC puzzle can be moved or rotated. Tap to select; drag with one finger, pan the camera with two fingers, twist to rotate, or pinch to zoom."
               : "Inspect the original imported parts using the camera controls.")
        view.accessibilityValue = physicsAccessibilityStatus
        // The SceneKit camera's one-finger pan conflicts with object dragging.
        // Disable it only while editing the imported puzzle arrangement.
        view.allowsCameraControl = !allowObjectPlacement || experimentalPhysics
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        // SceneKit defaults to a paused scene in some configurations; make
        // frame scheduling explicit for deterministic experiment startup.
        // Keep the renderer active while arranging an original level.
        // view.isPlaying=false can leave the imported SceneKit viewport
        // completely black until the user starts physics. Drawing a scene
        // and integrating its rigid bodies are separate responsibilities.
        view.rendersContinuously = true
        view.preferredFramesPerSecond = experimentalPhysics ? 60 : 30
        if experimentalPhysics { view.delegate = context.coordinator }
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.selectObject(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        // Joint creation belongs to the optional diagnostic inspector only.
        // Player-facing PC puzzles must not allow inventing extra hinges.
        if experimentalPhysics && diagnosticHinges {
            let connect = UITapGestureRecognizer(target: context.coordinator,
                                                  action: #selector(Coordinator.selectHingeEndpoint(_:)))
            connect.numberOfTapsRequired = 2
            tap.require(toFail: connect)
            view.addGestureRecognizer(connect)
            // Three-finger tap removes the most recently added manual hinge.
            let undoHinge = UITapGestureRecognizer(target: context.coordinator,
                                                    action: #selector(Coordinator.removeLastManualHinge(_:)))
            undoHinge.numberOfTouchesRequired = 3
            view.addGestureRecognizer(undoHinge)
        }
        let drag = UIPanGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.dragSelected(_:)))
        drag.minimumNumberOfTouches = 1
        drag.maximumNumberOfTouches = 1
        drag.delegate = context.coordinator
        drag.isEnabled = allowObjectPlacement && !experimentalPhysics
        // Edited placements are sandbox-only and never modify the original
        // imported CML/JSON scene or UCM files.
        view.addGestureRecognizer(drag)
        // While arranging a level, native SceneKit camera control is off so
        // one-finger movement can edit unlocked pieces. Provide a distinct
        // two-finger pan for inspecting sections of large original puzzles.
        let cameraPan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.panCamera(_:))
        )
        cameraPan.minimumNumberOfTouches = 2
        cameraPan.maximumNumberOfTouches = 2
        cameraPan.delegate = context.coordinator
        cameraPan.isEnabled = allowObjectPlacement && !experimentalPhysics
        view.addGestureRecognizer(cameraPan)
        let rotate = UIRotationGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.rotateSelected(_:))
        )
        rotate.delegate = context.coordinator
        rotate.isEnabled = allowObjectPlacement && !experimentalPhysics
        view.addGestureRecognizer(rotate)
        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.zoomCamera(_:))
        )
        pinch.delegate = context.coordinator
        pinch.isEnabled = allowObjectPlacement && !experimentalPhysics
        view.addGestureRecognizer(pinch)
        let reset = UILongPressGestureRecognizer(target: context.coordinator,
                                                  action: #selector(Coordinator.resetSelected(_:)))
        reset.minimumPressDuration = 0.8
        // In inspection mode, long press resets a saved position; in physics
        // mode, it toggles a mesh between movable and fixed for diagnostics.
        reset.isEnabled = (allowObjectPlacement && !experimentalPhysics)
            || (experimentalPhysics && diagnosticHinges)
        view.addGestureRecognizer(reset)
        context.coordinator.lastUndoPlacementRevision = undoPlacementRevision
        context.coordinator.onCanUndoPlacementChange = onCanUndoPlacementChange
        context.coordinator.storageKey = "cm.original.positions.\(document.sceneSHA256)"
        context.coordinator.rotationStorageKey = "cm.original.rotations.\(document.sceneSHA256)"
        context.coordinator.physicsEnabled = experimentalPhysics
        context.coordinator.diagnosticTapImpulses = diagnosticTapImpulses
        context.coordinator.setExperimentalMotorDrive(experimentalMotorDrive)
        context.coordinator.setExperimentalMagnetism(experimentalMagnetism)
        context.coordinator.setPoweredMotorRotorIDs(poweredMotorRotorObjectIDs)
        context.coordinator.setPoweredMotorDriveSignals(poweredMotorRotorDriveSignals)
        context.coordinator.experimentalOriginalRocketFlight = experimentalOriginalRocketFlight
        context.coordinator.setOriginalRocketInitialVelocities(initialOriginalRocketVelocities)
        context.coordinator.session = CMOriginalGameplaySession(document: document)
        // Only evidence-derived zone-delivery prototypes collect bodies:
        // four distinct linked objects in Professor level 1, or five
        // linked crates in Professor level 3. Other levels preserve bodies.
        let first = (CMOriginalFirstLevelRun(document: document)?.targets ?? [])
            .map(\.id)
        let third = (CMOriginalThirdLevelRun(document: document)?.targets ?? [])
            .map(\.id)
        context.coordinator.collectiblePrototypeTargets = Set(first + third)
        context.coordinator.onOriginalZoneContact = onOriginalZoneContact
        context.coordinator.onLinkedZoneContact = onLinkedZoneContact
        context.coordinator.onOriginalConnectionContact = onOriginalConnectionContact
        context.coordinator.onOriginalBucketCapture = onOriginalBucketCapture
        context.coordinator.onOriginalCageCapture = onOriginalCageCapture
        context.coordinator.onOriginalPlayerSourceGoal = onOriginalPlayerSourceGoal
        context.coordinator.onOriginalHammerGoal = onOriginalHammerGoal
        context.coordinator.onOriginalSteamGoal = onOriginalSteamGoal
        context.coordinator.onOriginalGrillGoal = onOriginalGrillGoal
        context.coordinator.onOriginalFlaskGoal = onOriginalFlaskGoal
        context.coordinator.onOriginalFlagGoal = onOriginalFlagGoal
        context.coordinator.onOriginalEnvironmentalCandleGoal = onOriginalEnvironmentalCandleGoal
        context.coordinator.onOriginalBalloonGoal = onOriginalBalloonGoal
        context.coordinator.onOriginalCatapultGoal = onOriginalCatapultGoal
        context.coordinator.onOriginalSolarRays = onOriginalSolarRays
        context.coordinator.onOriginalFlowerGoal = onOriginalFlowerGoal
        context.coordinator.setLiveOpticalLampPower(originalOpticalLampPower)
        context.coordinator.fourthLevelRun = CMOriginalFourthLevelRun(document: document)
        context.coordinator.onOriginalSwitchToggle = onOriginalSwitchToggle
        context.coordinator.onOriginalSwitchImpactGoal = onOriginalSwitchImpactGoal
        context.coordinator.onOriginalSwitchContact = onOriginalSwitchContact
        context.coordinator.onOriginalOpticalSightlines = onOriginalOpticalSightlines
        context.coordinator.onOriginalRocketAnchorSnapshots = onOriginalRocketAnchorSnapshots
        context.coordinator.onOriginalCandleRocketHeatPairs =
            onOriginalCandleRocketHeatPairs
        context.coordinator.onOriginalReconstructedRocketGoal =
            onOriginalReconstructedRocketGoal
        context.coordinator.onOriginalPowerPlugTap = onOriginalPowerPlugTap
        context.coordinator.onOriginalRopeTap = onOriginalRopeTap
        context.coordinator.onOriginalBeltTap = onOriginalBeltTap
        context.coordinator.originalBeltEditing = originalBeltEditing
        context.coordinator.onOriginalRopeCut = onOriginalRopeCut
        context.coordinator.originalRopeEditing = originalRopeEditing
        context.coordinator.onOriginalCableCut = onOriginalCableCut
        context.coordinator.onOriginalDisrupterAngle = onOriginalDisrupterAngle
        context.coordinator.onOriginalGeneratorSignal = onOriginalGeneratorSignal
        context.coordinator.onOriginalWindmillSignal = onOriginalWindmillSignal
        if experimentalPhysics {
            context.coordinator.session?.start()
            if physicsPaused { context.coordinator.session?.pause() }
        }
        var originalPositions: [String: SCNVector3] = [:]
        var originalRotations: [String: SCNVector3] = [:]
        let scene = buildScene(
            originalPositions: &originalPositions,
            originalRotations: &originalRotations
        )
        if experimentalPhysics {
            scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
        }
        view.scene = scene
        context.coordinator.syncOriginalRopes(originalPlayerRopes, in: scene)
        context.coordinator.syncOriginalBelts(originalPlayerBelts, in: scene)
        context.coordinator.syncOriginalPowerCables(
            originalPlayerPowerCables, in: scene,
            originalDirectory: assetDirectory,
            observedPower: originalPlayerCablePowerSignals)
        #if DEBUG && targetEnvironment(simulator)
        view.accessibilityValue = physicsAccessibilityStatus +
            sceneDebugStatus(scene)
        #endif
        context.coordinator.initializeSwitchPressCount(switchPressCount)
        if experimentalPhysics {
            context.coordinator.registerPhysicsNodes(in: scene, originalDirectory: assetDirectory)
            context.coordinator.setOriginalNativeRocketEngineObservations(
                originalNativeRocketEngineObservations)
            context.coordinator.configurePhysicsRoles(configuredPhysicsRoles)
            context.coordinator.configureExperimentalReactions(configuredReactions)
            context.coordinator.setOriginalLampVisualFactors(originalLampVisualFactors)
            context.coordinator.setOriginalAmmeterSignals(originalAmmeterPowerSignals)
        }
        // Assign a fixed simulation step to reduce device-dependent solver
        // behavior and tunneling through thin imported mechanisms.
        if experimentalPhysics {
            scene.physicsWorld.timeStep = 1.0 / 120.0
            scene.physicsWorld.contactDelegate = context.coordinator
        }
        // Render original UCM meshes in both arrangement and playback modes.
        // PhysicsWorld.speed=0 freezes simulation without stopping drawing,
        // camera orbiting or screenshots of a paused/unsolved puzzle.
        scene.physicsWorld.speed = experimentalPhysics && !physicsPaused ? 1 : 0
        view.isPlaying = true
        if experimentalPhysics {
            // Allow tapping a moving imported object to give it an impulse.
            // This is a sandbox interaction, not an original puzzle mechanic.
            context.coordinator.physicsEnabled = true
        }
        // Experimental physics must not change the user's saved inspection
        // coordinates. Physics mode never writes to that persistence store.
        context.coordinator.originalPositions = originalPositions
        context.coordinator.originalRotations = originalRotations
        view.pointOfView = scene.rootNode.childNode(withName: "original-level-camera", recursively: false)
        context.coordinator.initialCameraTransform = view.pointOfView?.transform
        context.coordinator.initialCameraFieldOfView = view.pointOfView?.camera?.fieldOfView
        context.coordinator.lastCameraResetRevision = cameraResetRevision
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains(CMPrivateSimulatorCapture.launchArgument) {
            let registeredModels = CMOriginalModelResolver.allModelNames(in: document.root)
            let originalMeshes = loadedSceneOriginalMeshCount(scene)
            let hasCamera = view.pointOfView?.camera != nil
            let isAuthenticFirstLevel =
                document.index == 1 && document.title != "CM synthetic CI 3D scene"
            CMPrivateSimulatorCapture.record(
                state: isAuthenticFirstLevel && originalMeshes >= 25 && hasCamera
                    ? "original-scene-loaded" : "original-scene-incomplete",
                message: "Captured scene contains original imported PC UCM geometry; screenshot must be verified separately.",
                level: document.index, title: document.title,
                originalMeshCount: originalMeshes,
                referencedModelCount: registeredModels.count,
                cameraReady: hasCamera)
        }
        if document.title == "CM synthetic CI 3D scene" {
            // Allow SwiftUI to lay out the SceneKit layer before probing.
            // This is an app-side snapshot, not an XCTest or OS screenshot.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak view] in
                guard let view, view.window != nil else { return }
                let image = view.snapshot()
                let counts = Self.ciSceneSnapshotColors(image)
                let size = view.bounds.size
                let details = "; nativeSCNSnapshot=orange:\(counts.orange)," +
                    "cyan:\(counts.cyan); viewSize=\(Int(size.width))x\(Int(size.height))" +
                    "; snapshotSize=\(Int(image.size.width))x\(Int(image.size.height))" +
                    "; renderingAPI=\(view.renderingAPI.rawValue)"
                view.accessibilityValue = (view.accessibilityValue ?? "") + details
            }
        }
        #endif
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // SwiftUI updates pause state without reconstructing imported meshes
        // or losing the current simulated positions.
        context.coordinator.onOriginalZoneContact = onOriginalZoneContact
        context.coordinator.onLinkedZoneContact = onLinkedZoneContact
        context.coordinator.onOriginalConnectionContact = onOriginalConnectionContact
        context.coordinator.onOriginalBucketCapture = onOriginalBucketCapture
        context.coordinator.onOriginalCageCapture = onOriginalCageCapture
        context.coordinator.onOriginalPlayerSourceGoal = onOriginalPlayerSourceGoal
        context.coordinator.onOriginalHammerGoal = onOriginalHammerGoal
        context.coordinator.onOriginalSteamGoal = onOriginalSteamGoal
        context.coordinator.onOriginalGrillGoal = onOriginalGrillGoal
        context.coordinator.onOriginalFlaskGoal = onOriginalFlaskGoal
        context.coordinator.onOriginalFlagGoal = onOriginalFlagGoal
        context.coordinator.onOriginalEnvironmentalCandleGoal = onOriginalEnvironmentalCandleGoal
        context.coordinator.onOriginalBalloonGoal = onOriginalBalloonGoal
        context.coordinator.onOriginalCatapultGoal = onOriginalCatapultGoal
        context.coordinator.onOriginalSolarRays = onOriginalSolarRays
        context.coordinator.onOriginalFlowerGoal = onOriginalFlowerGoal
        context.coordinator.setLiveOpticalLampPower(originalOpticalLampPower)
        context.coordinator.onOriginalSwitchToggle = onOriginalSwitchToggle
        context.coordinator.onOriginalSwitchImpactGoal = onOriginalSwitchImpactGoal
        context.coordinator.onOriginalSwitchContact = onOriginalSwitchContact
        context.coordinator.onOriginalOpticalSightlines = onOriginalOpticalSightlines
        context.coordinator.onOriginalRocketAnchorSnapshots = onOriginalRocketAnchorSnapshots
        context.coordinator.onOriginalCandleRocketHeatPairs =
            onOriginalCandleRocketHeatPairs
        context.coordinator.onOriginalReconstructedRocketGoal =
            onOriginalReconstructedRocketGoal
        context.coordinator.onOriginalPowerPlugTap = onOriginalPowerPlugTap
        context.coordinator.onOriginalRopeTap = onOriginalRopeTap
        context.coordinator.onOriginalBeltTap = onOriginalBeltTap
        context.coordinator.originalBeltEditing = originalBeltEditing
        context.coordinator.onOriginalRopeCut = onOriginalRopeCut
        context.coordinator.originalRopeEditing = originalRopeEditing
        context.coordinator.onOriginalCableCut = onOriginalCableCut
        context.coordinator.onOriginalDisrupterAngle = onOriginalDisrupterAngle
        context.coordinator.onOriginalGeneratorSignal = onOriginalGeneratorSignal
        context.coordinator.onOriginalWindmillSignal = onOriginalWindmillSignal
        context.coordinator.diagnosticTapImpulses = diagnosticTapImpulses
        context.coordinator.onCanUndoPlacementChange = onCanUndoPlacementChange
        context.coordinator.setExperimentalMotorDrive(experimentalMotorDrive)
        context.coordinator.setExperimentalMagnetism(experimentalMagnetism)
        context.coordinator.setPoweredMotorRotorIDs(poweredMotorRotorObjectIDs)
        context.coordinator.setPoweredMotorDriveSignals(poweredMotorRotorDriveSignals)
        context.coordinator.experimentalOriginalRocketFlight = experimentalOriginalRocketFlight
        context.coordinator.setOriginalRocketInitialVelocities(initialOriginalRocketVelocities)
        if let scene = uiView.scene {
            context.coordinator.syncOriginalRopes(originalPlayerRopes, in: scene)
        context.coordinator.syncOriginalBelts(originalPlayerBelts, in: scene)
            context.coordinator.syncOriginalPowerCables(
                originalPlayerPowerCables, in: scene,
                originalDirectory: assetDirectory,
                observedPower: originalPlayerCablePowerSignals)
        }
        context.coordinator.setOriginalNativeRocketEngineObservations(
            originalNativeRocketEngineObservations)
        context.coordinator.setOriginalLampVisualFactors(originalLampVisualFactors)
            context.coordinator.setOriginalAmmeterSignals(originalAmmeterPowerSignals)
        if context.coordinator.lastUndoPlacementRevision != undoPlacementRevision {
            context.coordinator.lastUndoPlacementRevision = undoPlacementRevision
            context.coordinator.undoPlacement(in: uiView)
        }
        // A paused experiment must still display its current 3D frame.
        // Freezing SceneKit's renderer would also prevent camera updates.
        uiView.isPlaying = true
        // Establish the session phase before resuming the physical clock.
        // Close the session gate before pausing, so late contacts cannot
        // consume once-only event latches outside a running frame.
        if experimentalPhysics { context.coordinator.setSessionPaused(physicsPaused) }
        uiView.scene?.physicsWorld.speed =
            experimentalPhysics && !physicsPaused ? 1 : 0
        uiView.allowsCameraControl = !allowObjectPlacement || experimentalPhysics
        // Restore the framing captured when the original scene was created.
        // Do not regenerate physics or discard edits just to recenter the
        // view after two-finger panning/pinching/native camera rotation.
        if context.coordinator.lastCameraResetRevision != cameraResetRevision {
            context.coordinator.lastCameraResetRevision = cameraResetRevision
            if let cameraNode = uiView.pointOfView {
                if let initial = context.coordinator.initialCameraTransform {
                    cameraNode.transform = initial
                }
                if let initial = context.coordinator.initialCameraFieldOfView {
                    cameraNode.camera?.fieldOfView = initial
                }
            }
        }
        if experimentalPhysics {
            context.coordinator.configurePhysicsRoles(configuredPhysicsRoles)
            context.coordinator.pressConfiguredSwitchIfNeeded(switchPressCount)
        }
        let status = context.coordinator.selectedModelName.map {
            physicsAccessibilityStatus + "; selected original model: " + $0
        } ?? physicsAccessibilityStatus
        #if DEBUG && targetEnvironment(simulator)
        uiView.accessibilityValue = status + sceneDebugStatus(uiView.scene)
        #else
        uiView.accessibilityValue = status
        #endif
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate, SCNPhysicsContactDelegate, SCNSceneRendererDelegate {
        private weak var highlighted: SCNNode?
        var selectedModelName: String?
        var session: CMOriginalGameplaySession?
        private let sessionLock = NSLock()
        private var lastRendererTime: TimeInterval?
        private var experimentalMotorDriveEnabled = false
        private var experimentalMagnetismEnabled = false
        private var poweredMotorRotorIDs = Set<String>()
        // A rotor that was being driven must coast down after an external
        // cable/switch/generator stops supplying its motor.
        private var coastingMotorRotorIDs = Set<String>()
        private var poweredMotorDriveSignals: [String: Float] = [:]
        // Consumed exactly ONCE per frame, not replayed during a stalled
        // SwiftUI snapshot. New forces require fresh real-native evidence.
        private var pendingNativeRocketEngineObservations:
            [CMOriginalRocketForceDelivery.Observation] = []
        private var lastNativeRocketEngineSequenceByChildID:
            [String: UInt64] = [:]
        var experimentalOriginalRocketFlight = false
        private var rocketSceneStages:
            [String: CMOriginalRocketStageMachine] = [:]
        private var rocketSceneTerminalGate =
            CMOriginalRocketTerminalGate()
        var onOriginalReconstructedRocketGoal:
            ((String, String) -> Void)?
        // Real imported rocket_effect.tga on the original UCM Explode
        // attachment. Visual only, never an invented explosion impulse/GOAL.
        private var rocketOriginalExplosionSpritesByChildID:
            [String: [SCNNode]] = [:]
        private var rocketInitialFCByChildID: [String: Float] = [:]
        func setOriginalRocketInitialVelocities(_ values: [String: Float]) {
            sessionLock.lock()
            rocketInitialFCByChildID = values.filter {
                $0.value.isFinite && $0.value > 0
            }
            sessionLock.unlock()
        }
        func setOriginalNativeRocketEngineObservations(
            _ observations: [CMOriginalRocketForceDelivery.Observation]
        ) {
            sessionLock.lock()
            pendingNativeRocketEngineObservations =
                observations.count <= 128 ? observations : []
            sessionLock.unlock()
        }
        var onOriginalPowerPlugTap: ((String) -> Void)?
        var onOriginalRopeTap: ((CMOriginalRope.Endpoint) -> Void)?
        var onOriginalBeltTap: ((String) -> Void)?
        var originalBeltEditing = false
        private let beltLock = NSLock()
        private weak var beltSceneRoot: SCNNode?
        private var beltWheels: [String: (marker: SCNNode, coefficient: Float)] = [:]
        private var beltSpans: [CMOriginalDriveBelt.Pair: [SCNNode]] = [:]
        var onOriginalRopeCut: ((CMOriginalRope.Pair) -> Void)?
        // Renderer-local cut latch prevents a queued UI update recreating a severed rope.
        private var severedRopes = Set<CMOriginalRope.Pair>()
        var originalRopeEditing = false
        private let ropeLock = NSLock()
        private weak var ropeSceneRoot: SCNNode?
        private var ropeMarkers: [CMOriginalRope.Endpoint: SCNNode] = [:]
        private var ropeVisuals: [CMOriginalRope.Pair: SCNNode] = [:]
        private var ropeLengths: [CMOriginalRope.Pair: Float] = [:]
        var onOriginalCableCut: ((CMOriginalPowerCircuit.Cable) -> Void)?
        private var scissorsBladesByOwner: [String: (first: String, second: String)] = [:]
        private var firedScissorsIDs = Set<String>()
        private var reportedCutCables = Set<CMOriginalPowerCircuit.Cable>()
        func setPoweredMotorDriveSignals(_ signals: [String: Float]) {
            sessionLock.lock()
            poweredMotorDriveSignals = signals.filter { $0.value.isFinite }
            sessionLock.unlock()
        }
        func setPoweredMotorRotorIDs(_ ids: Set<String>) {
            sessionLock.lock()
            poweredMotorRotorIDs = ids
            sessionLock.unlock()
        }
        private var magneticSourceIDs = Set<String>()
        private var magneticTargetIDs = Set<String>()
        var fourthLevelRun: CMOriginalFourthLevelRun?
        var onOriginalBucketCapture: ((String, String) -> Void)?
        var onOriginalCageCapture: ((String, String) -> Void)?
        var onOriginalPlayerSourceGoal: ((String) -> Void)?
        var onOriginalHammerGoal: ((String) -> Void)?
        var onOriginalSteamGoal: ((String) -> Void)?
        var onOriginalGrillGoal: ((String) -> Void)?
        var onOriginalFlaskGoal: ((String) -> Void)?
        var onOriginalFlagGoal: ((String) -> Void)?
        var onOriginalEnvironmentalCandleGoal: ((String) -> Void)?
        var onOriginalBalloonGoal: ((String) -> Void)?
        var onOriginalCatapultGoal: ((String) -> Void)?
        private struct FlagDrive {
            let wheel: SCNNode
            let telescope3: SCNNode
            let telescope4: SCNNode
            let wind: SCNNode
            var extensionValue: Float = 0
            var reported = false
        }
        private struct FlagWindmill {
            let wheel: SCNNode
            let fixedFrame: SCNNode
        }
        private var flagDrives: [String: FlagDrive] = [:]
        private var flagWindmills: [String: FlagWindmill] = [:]
        private struct BellowsDrive {
            let lever: SCNNode
            let wind: SCNNode
            var state = CMOriginalBellows()
        }
        private var bellowsDrives: [String: BellowsDrive] = [:]
        private var bellowsOwnerByLeverID: [String: String] = [:]
        private var flagWindSourceIDs = Set<String>()
        private var flagScriptedPartIDs = Set<String>()
        private struct FlaskDrive {
            let heat: SCNNode
            let gas: SCNNode
            var state = CMOriginalFlaskGas()
            var visuals: [SCNNode] = []
            var reported = false
        }
        private var flaskDrives: [String: FlaskDrive] = [:]
        private var flaskSteamImage: CGImage?
        var onOriginalSolarRays: (([String: [Float]]) -> Void)?
        var onOriginalFlowerGoal: ((String) -> Void)?
        private var liveOpticalLampPower: [String: Float] = [:]
        private var liveOpticalEmitters: [String: SCNNode] = [:]
        private var liveOpticalReceivers: [String: SCNNode] = [:]
        private var magnifierGlows: [String: [CMOriginalMagnifier.Side: SCNNode]] = [:]
        private var magnifierFoci: [(owner: String, position: SIMD3<Float>, light: Float)] = []
        private var liveFlowerProgress: [String: Float] = [:]
        private var liveFlowerMorphers: [String: SCNMorpher] = [:]
        private var liveFlowerLight: [String: Float] = [:]
        private var reportedFlowerGoals = Set<String>()
        private var lastLiveOpticalTime: TimeInterval = -1
        private var lastSolarRays: [String: [Float]] = [:]
        private var steamPortNodes: [(owner: String, node: SCNNode)] = []
        private var boilerHeatSignals: [String: Float] = [:]
        private var steamOutgoingSignals: [Int: Float] = [:]
        private var steamReceiverOwners: [String: String] = [:]
        private var steamWheelByBody: [String: SCNNode] = [:]
        private var steamValveLevers: [String: (owner: SCNNode, lever: SCNNode)] = [:]
        private struct SteamPistonDrive {
            let wheel: SCNNode
            let piston: SCNNode
            let rod: SCNNode
            let wheelX: Float
            let wheelRestAngle: Float
            let rodRestAngle: Float
        }
        private var steamPistonDrives: [SteamPistonDrive] = []
        private var steamScriptedPartIDs = Set<String>()
        private var reportedSteamGoals = Set<String>()
        // Win32 0x44D874..0x44D9A2 checks actual GOAL-marked
        // tmo_bucket objects against tmo_ball_ objects, not only puzzle 4.
        // Retain authentic UCM mesh identities for geometry containment.
        // Native 0x44D874..0x44D9A2 uses both GOAL tmo_bucket and
        // GOAL tmo_rope_cage with a tmo_ball_* source. Original CML
        // contains to_dummy_bounding at the authored Catch/Test point.
        private var catchGoalMarkerMeshes: [String: CMOriginalObjectMeshNode] = [:]
        private var originalBallMeshes: [String: CMOriginalObjectMeshNode] = [:]
        private var catchGoalKindsByID: [String: String] = [:]
        // A genuine CONNECTED_TO ball->bucket/cage is a Catch/Test
        // delivery, NOT the ball brushing the outside of a wall.
        private var linkedContainerSourcesByTarget: [String: Set<String>] = [:]
        private var ballObjectIDs = Set<String>()
        private var capturedCatchGoalIDs = Set<String>()
        private var motorRotorObjectIDs = Set<String>()
        private var generatorIDByRotorID: [String: String] = [:]
        private var windmillIDByWingsID: [String: String] = [:]
        private var windmillWheelByWingsID: [String: String] = [:]
        private struct GrillDrive {
            let wheel: SCNNode
            let spit: SCNNode
            let sausage: SCNNode
            let spitRest: simd_quatf
            let sausageRest: simd_quatf
            let heatMarker: SCNNode
            let materials: [SCNMaterial]
            var heat = CMOriginalGrillHeat.State()
            var phase: Float = 0
        }
        private var grillDrives: [String: GrillDrive] = [:]
        private struct HammerDrive {
            let wheel: SCNNode
            let hammer: SCNNode
            let nail: SCNNode
            let hammerMarker: SCNNode
            let nailMarker: SCNNode
            let armRadius: Float
            let direction: Float
            var angle: Float
            var releasing = false
            var finished = false
        }
        private var hammerDrives: [String: HammerDrive] = [:]
        private var drivenHammerPartIDs = Set<String>()
        private struct CatapultDrive {
            let sling: SCNNode
            let button: SCNNode
            let hinge: SCNNode
            let restAngle: Float
            let direction: Float
            var stroke = CMOriginalCatapultStroke()
        }
        private var catapultDrives: [String: CatapultDrive] = [:]
        private var catapultSlingIDs = Set<String>()
        private var qualifiedWindmillGoalIDs = Set<String>()
        private var disrupterIDByWheelID: [String: String] = [:]
        private var lastDisrupterConduction: [String: Bool] = [:]
        private var lastGeneratorScalars: [String: Float] = [:]
        private var lastGeneratorPollTime: TimeInterval = 0
        var onOriginalDisrupterAngle: ((String, Float) -> Void)?
        var onOriginalGeneratorSignal: ((String, Float) -> Void)?
        var onOriginalWindmillSignal: ((String, Float) -> Void)?
        private var axleObjectIDs = Set<String>()
        // Authentic PC conveyor children are linked through their scene-graph
        // parentID, not through a guessed nearest wheel or motor.
        private var originalTypesByID: [String: String] = [:]
        // Original Win32 0x42272A loads CML VALF into native +0xEC.
        // Only real authored per-object values may calibrate gear transfer.
        private var originalMechanicalVALFByID: [String: Float] = [:]
        private var conveyorWheelNodes: [String: SCNNode] = [:]
        private var conveyorRollerNodes: [String: [(kind: String, node: SCNNode)]] = [:]
        // The exact original UCM belt surface is offset from its housing.
        private var conveyorBeltNodes: [String: SCNNode] = [:]
        private var conveyorBeltMaterials: [String: SCNMaterial] = [:]
        private var conveyorTextureOffsets: [String: Float] = [:]
        private var switchLeverNodes: [String: SCNNode] = [:]
        private var switchLeverRestAngles: [String: SCNVector3] = [:]
        // Renderer-owned conduction observations, not requested lever commands.
        private var conductingSwitchIDs = Set<String>()
        private var switchImpactGoal = CMOriginalSwitchImpactGoal()
        private var switchContacts: CMOriginalSwitchContactMapper?
        var onOriginalSwitchToggle: ((String, Bool) -> Void)?
        var onOriginalSwitchImpactGoal: ((String) -> Void)?
        var onOriginalSwitchContact: ((CMOriginalSwitchContactMapper.Hit) -> Void)?
        var onOriginalOpticalSightlines: (([CMOriginalOpticalSightline]) -> Void)?
        var onOriginalRocketAnchorSnapshots:
            (([CMOriginalRocketAnchorTelemetry.Complete]) -> Void)?
        var onOriginalCandleRocketHeatPairs:
            (([CMOriginalRocketCandleHeatPair.Observation]) -> Void)?
        private var previousCandleRocketHeatPairs:
            [CMOriginalRocketCandleHeatPair.Observation] = []
        private var originalRocketChildIDs = Set<String>()
        private var originalRocketParentByChildID: [String: String] = [:]
        private var lastOriginalRocketAnchorPollTime: TimeInterval = -1
        private var previousOriginalRocketAnchorSnapshots:
            [CMOriginalRocketAnchorTelemetry.Complete] = []
        private var opticalEmitterMeshes: [String: SCNNode] = [:]
        private var opticalSolarMeshes: [String: SCNNode] = [:]
        private var originalAmmeterNeedles: [String: SCNNode] = [:]
        private var originalAmmeterRestAngles: [String: Float] = [:]
        private var requestedAmmeterPowerSignals: [String: Float]? = nil
        // Real original pocketlamp glow TGA; owner toggles +0xEC from
        // exact 0 to 1 on native Win32 mouse activation (0x434ACA).
        private var originalPocketLampGlowNodes: [String: [SCNNode]] = [:]
        // Imported original light_glow.tga candle sprites, per actual
        // tmo_candle/tmo_candle_dyn owner (never shared across instances).
        private var originalCandleGlowNodes: [String: [SCNNode]] = [:]
        // Per-object genuine source UCM attachment frames. No invented
        // native region size, thrust impulse or completion events.
        private var originalNamedAnchorNodesByObjectID: [String: [SCNNode]] = [:]
        // Native Windows 0x42FCB0 creates power_cable from TWO real ends.
        // SceneKit lines are non-colliding visible representations using
        // the original 8px power_cable.tga; native tube tessellation is
        // not independently known. The user's exact CML plug IDs govern.
        private var originalCablePlugOwners: [String: SCNNode] = [:]
        // Actual power_plug.ucm "Wire" attachment is at local
        // (0, 0, -0.0836), DIFFERENT from the "Plug" socket and its
        // owner pivot. Retain genuine moving SCNNode marker references.
        private var originalCableWireMarkers: [String: SCNNode] = [:]
        private var originalPhysicalCablePairs = Set<CMOriginalPowerCircuit.Cable>()
        private var originalCableNodes:
            [CMOriginalPowerCircuit.Cable: SCNNode] = [:]
        private weak var originalCableSceneRoot: SCNNode?
        private var originalCableMaterial: SCNMaterial?
        private let originalCableVisualLock = NSLock()
        // Each lightbulb has its own copied original UCM materials. Never
        // change the shared cross-level geometry cache or another lamp.
        private var originalLampBulbMaterials: [String: [SCNMaterial]] = [:]
        private var originalLampGlowNodes: [String: [SCNNode]] = [:]
        private var originalLampDiffuseIntensity: [ObjectIdentifier: CGFloat] = [:]
        private var requestedLampVisualFactors: [String: Float]? = nil
        private var appliedLampVisualFactors: [String: Float]? = nil
        // The real bulb UCM belongs to a separate tmo_ child object. Its
        // geometry is part of the source, not an intervening obstruction.
        private var opticalEmitterByPartID: [String: String] = [:]
        private var lastOpticalSampleTime: TimeInterval = -1
        private var previousOpticalSightlines: [CMOriginalOpticalSightline] = []

        func setOriginalAmmeterSignals(_ signals: [String: Float]?) {
            requestedAmmeterPowerSignals = signals?.filter { $0.value.isFinite }
            applyOriginalAmmeterSignals()
        }

        private func applyOriginalAmmeterSignals() {
            for (deviceID, needle) in originalAmmeterNeedles {
                guard let initial = originalAmmeterRestAngles[deviceID] else {
                    continue
                }
                // Native x86 0x450FF2 computes this exact target angle
                // from max(actual power, secondary +0xFE), capped at 10.
                // Unknown secondary input is set to 0 only in this
                // clearly labeled experimental display, not goal logic.
                let measured = requestedAmmeterPowerSignals?[deviceID] ?? 0
                let angle = CMOriginalWindowsAmmeter.needleAngle(
                    incomingPower: measured, sensorInput: 0
                ) ?? CMOriginalWindowsAmmeter.zeroNeedleAngle
                var euler = needle.eulerAngles
                euler.z = initial + angle -
                    CMOriginalWindowsAmmeter.zeroNeedleAngle
                if abs(needle.eulerAngles.z - euler.z) > 0.0001 {
                    // Win32's time-scale +0x128 has not yet been ported.
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.12
                    needle.eulerAngles = euler
                    SCNTransaction.commit()
                }
            }
        }

        func setOriginalLampVisualFactors(_ values: [String: Float]?) {
            sessionLock.lock()
            defer { sessionLock.unlock() }
            requestedLampVisualFactors = values?.filter { $0.value.isFinite }
            applyOriginalLampVisualFactors()
        }

        private func applyOriginalLampVisualFactors() {
            guard !originalLampBulbMaterials.isEmpty,
                  appliedLampVisualFactors != requestedLampVisualFactors else {
                return
            }
            appliedLampVisualFactors = requestedLampVisualFactors
            for (lampID, materials) in originalLampBulbMaterials {
                // Pure SceneKit display clamp only. The separately
                // recovered Win32 scalar is NOT clamped at its source.
                let displayFactor: CGFloat
                if let values = requestedLampVisualFactors {
                    displayFactor = CGFloat(min(1, max(0, values[lampID] ?? 0)))
                } else {
                    displayFactor = 1
                }
                for material in materials {
                    let original = originalLampDiffuseIntensity[
                        ObjectIdentifier(material)] ?? 1
                    material.diffuse.intensity = original * displayFactor
                }
                // The original scene's separate bulb bloom uses the
                // imported light_glow.tga, not a fictitious UCM. Make it
                // follow the SAME recovered power/10 signal as its bulb.
                for glow in originalLampGlowNodes[lampID] ?? [] {
                    glow.opacity = displayFactor
                }
            }
        }

        func setExperimentalMotorDrive(_ enabled: Bool) {
            sessionLock.lock()
            experimentalMotorDriveEnabled = enabled
            sessionLock.unlock()
        }

        func setExperimentalMagnetism(_ enabled: Bool) {
            sessionLock.lock()
            experimentalMagnetismEnabled = enabled
            sessionLock.unlock()
        }

        var onOriginalZoneContact: ((String) -> Void)?
        var onLinkedZoneContact: ((String, String) -> Void)?
        var onOriginalConnectionContact: ((String, String) -> Void)?
        private var reportedZoneContacts = Set<String>()
        var collectiblePrototypeTargets = Set<String>()
        private var collectedPrototypeSources = Set<String>()
        private var reportedOriginalConnections = Set<String>()
        private var physicsNodesByObjectID: [String: [SCNNode]] = [:]
        // All 46 original balloon objects are identified by their PC tmo_
        // type. Only the 45 with VALB's movable bit will actually float;
        // the fixed balloon is kept static by configuredPhysicsRoles.
        private var buoyantObjectIDs = Set<String>()
        private var pendingBalloonPops = Set<String>()
        private var poppedBalloonIDs = Set<String>()
        private var appliedPhysicsRoles: [String: CMOriginalGameplaySession.PhysicsRole] = [:]
        private var appliedReactionRules: [CMOriginalGameplaySession.ReactionRule] = []

        private var lastSwitchPressCount = 0

        func initializeSwitchPressCount(_ count: Int) {
            lastSwitchPressCount = count
        }

        func pressConfiguredSwitchIfNeeded(_ count: Int) {
            guard count > lastSwitchPressCount else { return }
            // SwiftUI can coalesce several button presses into one view update.
            // Replay each input rather than dropping all but the latest.
            let previous = lastSwitchPressCount
            lastSwitchPressCount = count
            sessionLock.lock()
            defer { sessionLock.unlock() }
            guard let source = session?.reactionRules.first?.objectID else { return }
            // Diagnostic actuator only; no undocumented electrical simulation.
            let replayCount = min(count - previous, 64)
            for _ in 0..<replayCount {
                _ = session?.pressObject(source)
            }
        }

        func setSessionPaused(_ paused: Bool) {
            sessionLock.lock()
            defer { sessionLock.unlock() }
            if paused {
                session?.pause()
                lastRendererTime = nil
            } else {
                session?.resume()
            }
        }

        /// Apply explicit level physics configuration without reconstructing
        /// the imported 3D geometry. Sensors generate contacts but no forces.
        func configurePhysicsRoles(_ roles: [String: CMOriginalGameplaySession.PhysicsRole]) {
            guard roles != appliedPhysicsRoles else { return }
            let previousRoles = appliedPhysicsRoles
            appliedPhysicsRoles = roles
            sessionLock.lock()
            session?.configurePhysicsRoles(roles)
            sessionLock.unlock()
            for (id, nodes) in physicsNodesByObjectID {
                // Animated switch levers must move their genuine collision
                // bodies along with the visible pose, not remain static.
                if originalTypesByID[id] == "tmo_power_switch_lever",
                   nodes.count == 1, let node = nodes.first,
                   switchLeverNodes.values.contains(where: { $0 === node }),
                   let body = node.physicsBody {
                    body.type = .kinematic
                    body.isAffectedByGravity = false
                    body.collisionBitMask = CMOriginalPhysicsLayers.collisionMask(for: body.categoryBitMask)
                    body.contactTestBitMask = CMOriginalPhysicsLayers.contactMask(for: body.categoryBitMask)
                    continue
                }
                // Script-driven original hammer arm and nail retain collision
                // geometry but are positioned by the mechanism state machine.
                if drivenHammerPartIDs.contains(id) || steamScriptedPartIDs.contains(id) || flagScriptedPartIDs.contains(id) || catapultSlingIDs.contains(id) {
                    for node in nodes {
                        guard let body = node.physicsBody else { continue }
                        body.type = .kinematic
                        body.isAffectedByGravity = false
                        body.collisionBitMask = CMOriginalPhysicsLayers.collisionMask(for: body.categoryBitMask)
                        body.contactTestBitMask = CMOriginalPhysicsLayers.contactMask(for: body.categoryBitMask)
                    }
                    continue
                }
                let role = roles[id] ?? .movable
                guard role != (previousRoles[id] ?? .movable) else { continue }
                for node in nodes {
                    guard let body = node.physicsBody else { continue }
                    // Preserve the simulated pose when changing a moving
                    // object into a fixed object or sensor. Otherwise SceneKit
                    // may restore its original authored transform.
                    if body.type == .dynamic && role != .movable {
                        node.transform = node.presentation.transform
                        body.clearAllForces()
                        body.velocity = SCNVector3Zero
                        body.angularVelocity = SCNVector4(0, 0, 0, 0)
                    }
                    switch role {
                    case .fixed:
                        body.type = .static
                        body.collisionBitMask = CMOriginalPhysicsLayers.collisionMask(
                            for: body.categoryBitMask)
                    case .movable:
                        body.type = .dynamic
                        body.collisionBitMask = CMOriginalPhysicsLayers.collisionMask(
                            for: body.categoryBitMask)
                    case .sensor:
                        body.type = .kinematic
                        body.collisionBitMask = 0
                    }
                    body.contactTestBitMask = CMOriginalPhysicsLayers.contactMask(
                        for: body.categoryBitMask)
                }
            }
        }

        private func physicsObjectID(for node: SCNNode) -> String? {
            if let mesh = node as? CMOriginalObjectMeshNode {
                return mesh.originalObjectID
            }
            if let owner = node as? CMOriginalPhysicsOwnerNode {
                return owner.originalObjectID
            }
            return nil
        }

        private func owningOriginalObjectID(for node: SCNNode?) -> String? {
            var current = node
            while let candidate = current {
                if let id = physicsObjectID(for: candidate) { return id }
                current = candidate.parent
            }
            return nil
        }

        /// Visible cables cannot steal taps from the genuine original
        /// CML plug UCM mesh beneath them. Keep the fast normal hit path.
        private func originalObjectHit(
            in view: SCNView, at point: CGPoint
        ) -> SCNHitTestResult? {
            let nearest = view.hitTest(
                point, options: [.firstFoundOnly: true]).first
            guard nearest?.node.name == "original-player-power-cable" || nearest?.node.name == "original-player-rope" || nearest?.node.name == "original-player-drive-belt"
            else { return nearest }
            return view.hitTest(
                point, options: [.firstFoundOnly: false])
                .first(where: {
                    $0.node.name != "original-player-power-cable" && $0.node.name != "original-player-rope" && $0.node.name != "original-player-drive-belt"
                })
        }

        private func physicalNode(for node: SCNNode?) -> SCNNode? {
            var current = node
            while let candidate = current {
                if candidate.physicsBody != nil { return candidate }
                current = candidate.parent
            }
            return nil
        }

        /// Draw actual player-paired original PC power plugs with the
        /// user's ORIGINAL power_cable.tga texture. Never use VALF as a
        /// cable ID, invent cables from nearby parts, or add physical
        /// collision shapes. Segment shape is explicitly SceneKit-only.
        func syncOriginalPowerCables(
            _ requested: [CMOriginalPowerCircuit.Cable],
            in scene: SCNScene,
            originalDirectory: URL,
            observedPower: [CMOriginalPowerCircuit.Cable: Float] = [:]
        ) {
            originalCableVisualLock.lock()
            defer { originalCableVisualLock.unlock() }
            if originalCableSceneRoot !== scene.rootNode {
                for cable in originalCableNodes.values {
                    cable.removeFromParentNode()
                }
                originalCableNodes.removeAll()
                originalCablePlugOwners.removeAll()
                originalCableWireMarkers.removeAll()
                originalCableMaterial = nil
                originalCableSceneRoot = scene.rootNode
                let known = Set((session?.objects ?? [])
                    .filter { $0.type == "tmo_power_plug" }.map(\.id))
                var duplicates = Set<String>()
                scene.rootNode.enumerateChildNodes { node, _ in
                    guard let original = node as? CMOriginalPhysicsOwnerNode,
                          let id = original.originalObjectID,
                          known.contains(id) else { return }
                    if originalCablePlugOwners[id] == nil {
                        originalCablePlugOwners[id] = original
                    } else {
                        duplicates.insert(id)
                    }
                }
                for duplicate in duplicates {
                    originalCablePlugOwners.removeValue(forKey: duplicate)
                }
                // Every original power_plug.ucm has distinct named
                // attachment frames "Plug" (socket) and "Wire" (wire exit).
                // A cable must be anchored at the *Wire* frame, not at
                // the owner center where the previous tube originated.
                for (id, owner) in originalCablePlugOwners {
                    var candidates: [SCNNode] = []
                    owner.enumerateChildNodes { node, _ in
                        guard let mesh = node.parent
                            as? CMOriginalObjectMeshNode,
                            mesh.originalObjectID == id
                        else { return }
                        candidates.append(node)
                    }
                    let names = candidates.map { marker in
                        CMOriginalRocketAnchorTelemetry.originalName(
                            inSceneNodeName: marker.name ?? "") ?? ""
                    }
                    guard let index = CMOriginalPowerCableAnchor
                        .uniqueWireMarkerIndex(
                            originalOwnerType: "tmo_power_plug",
                            originalUCMNames: names)
                    else { continue }
                    originalCableWireMarkers[id] = candidates[index]
                }
            }
            let desired = Set(requested.filter {
                $0.firstPlugID != $0.secondPlugID &&
                originalCableWireMarkers[$0.firstPlugID] != nil &&
                originalCableWireMarkers[$0.secondPlugID] != nil
            })
            originalPhysicalCablePairs = desired
            for (pair, cable) in originalCableNodes
                where !desired.contains(pair) {
                cable.removeFromParentNode()
                originalCableNodes.removeValue(forKey: pair)
            }
            guard !desired.isEmpty else { return }
            if originalCableMaterial == nil {
                // Missing original texture must not create a guessed color.
                guard let image = OriginalTextureCache(
                    directory: originalDirectory).image(
                        named: "power_cable") else { return }
                let material = SCNMaterial()
                material.lightingModel = .constant
                material.diffuse.contents = image
                material.isDoubleSided = true
                originalCableMaterial = material
            }
            for pair in desired where originalCableNodes[pair] == nil {
                let cylinder = SCNCylinder(radius: 0.010, height: 1)
                cylinder.radialSegmentCount = 8
                cylinder.materials = [originalCableMaterial!]
                let visual = SCNNode(geometry: cylinder)
                visual.name = "original-player-power-cable"
                visual.castsShadow = false
                visual.physicsBody = nil
                scene.rootNode.addChildNode(visual)
                originalCableNodes[pair] = visual
            }
            // Keep the ORIGINAL user-owned power_cable.tga material.
            // The brightness does not purport to be Win32 current:
            // 1.0 means both device ends received an identical known
            // nonzero scalar; 0.38 is an unpowered/unverified connection.
            // The physical circuit model, original UCM endpoints and
            // GOAL rules remain unchanged.
            for (pair, visual) in originalCableNodes {
                if let value = observedPower[pair],
                   value.isFinite && value != 0 {
                    visual.opacity = 1
                } else {
                    visual.opacity = 0.38
                }
            }
            refreshOriginalCableGeometryLocked()
        }

        /// SceneKit cylinders follow exact moving `Wire` UCM anchors at
        /// the ORIGINAL plug's cable exit, not model pivots or guessed
        /// geometric centers. CML cable IDs remain authoritative, and
        /// the visual is never an electrical/physics simulation itself.
        private func refreshOriginalCableGeometryLocked() {
            for (pair, visual) in originalCableNodes {
                guard let left = originalCableWireMarkers[pair.firstPlugID],
                      let right = originalCableWireMarkers[pair.secondPlugID]
                else { visual.isHidden = true; continue }
                let a = left.presentation.simdWorldPosition
                let b = right.presentation.simdWorldPosition
                let difference = b - a
                let length = simd_length(difference)
                guard a.x.isFinite, a.y.isFinite, a.z.isFinite,
                      b.x.isFinite, b.y.isFinite, b.z.isFinite,
                      length.isFinite, length >= 0.002,
                      length <= 30 else {
                    visual.isHidden = true
                    continue
                }
                let direction = difference / length
                let up = SIMD3<Float>(0, 1, 0)
                let dot = simd_dot(up, direction)
                visual.isHidden = false
                visual.simdPosition = (a + b) * 0.5
                // Explicit 180-degree case avoids undefined quaternion
                // when the cable points exactly down in the XY plane.
                if dot < -0.9999 {
                    visual.simdOrientation = simd_quatf(
                        angle: .pi, axis: SIMD3<Float>(1, 0, 0))
                } else {
                    visual.simdOrientation = simd_quatf(
                        from: up, to: direction)
                }
                (visual.geometry as? SCNCylinder)?.height = CGFloat(length)
            }
        }

        // The genuine scissors use the first blade's Cut01/Cut02 frames
        // once the two physical blade angles cross the native threshold.
        // We test the actual rendered straight cable, not a guessed owner
        // overlap. Native flexible cable tessellation is still unrecovered.
        private func sampleOriginalScissorsCuts() {
            guard !scissorsBladesByOwner.isEmpty else { return }
            for (owner, blades) in scissorsBladesByOwner {
                guard !firedScissorsIDs.contains(owner),
                      let first = physicsNodesByObjectID[blades.first]?.first,
                      let second = physicsNodesByObjectID[blades.second]?.first,
                      first.physicsBody?.type == .dynamic,
                      second.physicsBody?.type == .dynamic,
                      let start = exactOriginalAnchor("Cut01", on: blades.first),
                      let end = exactOriginalAnchor("Cut02", on: blades.first),
                      CMOriginalScissorsCableGeometry.activates(
                        firstAngle: first.presentation.eulerAngles.z,
                        secondAngle: second.presentation.eulerAngles.z)
                else { continue }
                firedScissorsIDs.insert(owner)
                let a = start.presentation.simdWorldPosition
                let b = end.presentation.simdWorldPosition
                cutOriginalRopes(bladeStart: a, bladeEnd: b)
                originalCableVisualLock.lock()
                // Texture/visual availability must not determine electrical cuts.
                let hits = originalPhysicalCablePairs.filter { pair in
                    guard !reportedCutCables.contains(pair),
                          let left = originalCableWireMarkers[pair.firstPlugID],
                          let right = originalCableWireMarkers[pair.secondPlugID]
                    else { return false }
                    return CMOriginalScissorsCableGeometry.cuts(
                        bladeStart: a, bladeEnd: b,
                        cableStart: left.presentation.simdWorldPosition,
                        cableEnd: right.presentation.simdWorldPosition)
                }
                reportedCutCables.formUnion(hits)
                originalCableVisualLock.unlock()
                for pair in hits {
                    DispatchQueue.main.async { [weak self] in
                        self?.onOriginalCableCut?(pair)
                    }
                }
            }
        }

        // Native scissors samples rope and power cable in separate calls.
        // Stop rope forces immediately on the renderer thread, before UI delivery.
        private func cutOriginalRopes(bladeStart: SIMD3<Float>, bladeEnd: SIMD3<Float>) {
            ropeLock.lock()
            let hits = ropeVisuals.keys.filter { pair in
                guard !severedRopes.contains(pair),
                      let first = ropeMarkers[pair.first], let second = ropeMarkers[pair.second]
                else { return false }
                return CMOriginalRope.intersectsScissors(
                    ropeStart: first.presentation.simdWorldPosition,
                    ropeEnd: second.presentation.simdWorldPosition,
                    bladeStart: bladeStart, bladeEnd: bladeEnd)
            }
            for pair in hits {
                severedRopes.insert(pair)
                ropeVisuals.removeValue(forKey: pair)?.removeFromParentNode()
                ropeLengths.removeValue(forKey: pair)
            }
            ropeLock.unlock()
            for pair in hits {
                DispatchQueue.main.async { [weak self] in self?.onOriginalRopeCut?(pair) }
            }
        }

        // The original wheel models contain exact named Wheel attachments.
        // Do not invent links from CONNECTED_TO or mere wheel proximity.
        func syncOriginalBelts(_ pairs: Set<CMOriginalDriveBelt.Pair>, in scene: SCNScene) {
            beltLock.lock()
            defer { beltLock.unlock() }
            if beltSceneRoot !== scene.rootNode {
                for spans in beltSpans.values { spans.forEach { $0.removeFromParentNode() } }
                beltSpans.removeAll()
                beltWheels.removeAll()
                beltSceneRoot = scene.rootNode
                let coefficients = Dictionary(uniqueKeysWithValues: (session?.objects ?? []).compactMap { object -> (String, Float)? in
                    guard CMOriginalDriveBelt.accepts(type: object.type),
                          let raw = object.fields["VALF"]?.first,
                          let value = Float(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
                          value.isFinite, value >= 0.008, value <= 3 else { return nil }
                    return (object.id, value)
                })
                var duplicates = Set<String>()
                scene.rootNode.enumerateChildNodes { node, _ in
                    guard CMOriginalRocketAnchorTelemetry.originalName(inSceneNodeName: node.name ?? "") == "Wheel",
                          let id = self.owningOriginalObjectID(for: node),
                          let coefficient = coefficients[id] else { return }
                    if self.beltWheels[id] != nil { duplicates.insert(id) }
                    else { self.beltWheels[id] = (node, coefficient) }
                }
                for id in duplicates { beltWheels.removeValue(forKey: id) }
            }
            for pair in Array(beltSpans.keys) where !pairs.contains(pair) {
                beltSpans.removeValue(forKey: pair)?.forEach { $0.removeFromParentNode() }
            }
            for pair in pairs where beltSpans[pair] == nil {
                guard beltWheels[pair.first] != nil, beltWheels[pair.second] != nil else { continue }
                let spans = (0..<2).map { _ -> SCNNode in
                    let shape = SCNBox(width: 0.012, height: 1, length: 0.025, chamferRadius: 0)
                    shape.firstMaterial?.diffuse.contents = UIColor.darkGray
                    let node = SCNNode(geometry: shape)
                    node.name = "original-player-drive-belt"
                    node.physicsBody = nil
                    scene.rootNode.addChildNode(node)
                    return node
                }
                beltSpans[pair] = spans
            }
            refreshOriginalBeltsLocked(applyTorque: false)
        }

        private func hasOriginalBeltWheel(_ id: String) -> Bool {
            beltLock.lock(); defer { beltLock.unlock() }
            return beltWheels[id] != nil
        }

        // Actual bidirectional physical coupling: belt-driven wheel moves
        // wings, and externally moved wings can drive the same wheel.
        private func registerOriginalCatapults(objects: [CMOriginalGameplaySession.Object]) {
            for owner in objects where owner.type == "tmo_catapult" {
                let children = objects.filter {
                    $0.parentID == owner.id && $0.type == "tmo_catapult_sling"
                }
                guard children.count == 1,
                      let nodes = physicsNodesByObjectID[children[0].id], nodes.count == 1,
                      let sling = nodes.first, let body = sling.physicsBody,
                      let button = exactOriginalAnchor("Button", on: owner.id),
                      let hinge = exactOriginalAnchor("Mechanic01", on: children[0].id),
                      let ammo = exactOriginalAnchor("Ammo", on: children[0].id),
                      let parent = sling.parent else { continue }
                let pivot = parent.simdConvertPosition(hinge.simdWorldPosition, from: nil)
                let tip = parent.simdConvertPosition(ammo.simdWorldPosition, from: nil)
                let arm = tip.x - pivot.x
                guard arm.isFinite, abs(arm) > 0.01, sling.eulerAngles.z.isFinite else { continue }
                // The signed pose is derived in the assembly frame; native
                // +DC to mirrored SceneKit transform mapping is provisional.
                catapultDrives[owner.id] = .init(sling: sling, button: button,
                    hinge: hinge, restAngle: sling.eulerAngles.z,
                    direction: arm > 0 ? 1 : -1)
                catapultSlingIDs.insert(children[0].id)
                body.type = .kinematic
                body.isAffectedByGravity = false
            }
        }

        private func observeOriginalCatapultContact(owner: String, striker: String,
                                                     point: SCNVector3) {
            guard var drive = catapultDrives[owner],
                  session?.physicsRole(for: striker) == .movable,
                  drive.stroke.trigger(contact: .init(point.x, point.y, point.z),
                      button: drive.button.presentation.simdWorldPosition) else { return }
            catapultDrives[owner] = drive
        }

        private func advanceOriginalCatapults(delta: Double) {
            for id in Array(catapultDrives.keys) {
                guard var drive = catapultDrives[id], let parent = drive.sling.parent,
                      drive.sling.physicsBody?.type == .kinematic,
                      let travel = drive.stroke.advance(delta: delta) else { continue }
                // Keep the genuine hinge world position fixed while
                // rotating the original collision mesh, so a ball in its
                // cup is moved by SceneKit contact, not a fabricated launch.
                let before = parent.simdConvertPosition(drive.hinge.simdWorldPosition, from: nil)
                drive.sling.eulerAngles.z = drive.restAngle + drive.direction * travel
                let after = parent.simdConvertPosition(drive.hinge.simdWorldPosition, from: nil)
                drive.sling.simdPosition += before - after
                drive.sling.physicsBody?.resetTransform()
                catapultDrives[id] = drive
                if drive.stroke.phase == .finished {
                    let deliver = onOriginalCatapultGoal
                    DispatchQueue.main.async { deliver?(id) }
                }
            }
        }

        private func registerOriginalHammerDrives(objects: [CMOriginalGameplaySession.Object]) {
            for owner in objects where owner.type == "tmo_hammer" {
                func unique(_ type: String) -> (String, SCNNode)? {
                    let children = objects.filter { $0.parentID == owner.id && $0.type == type }
                    guard children.count == 1,
                          let nodes = physicsNodesByObjectID[children[0].id], nodes.count == 1
                    else { return nil }
                    return (children[0].id, nodes[0])
                }
                guard let (_, wheel) = unique("tmo_hammer_wheel"),
                      let (hammerID, hammer) = unique("tmo_hammer_hammer"),
                      let (nailID, nail) = unique("tmo_hammer_nail"),
                      let hammerMarker = exactOriginalAnchor("Nail", on: hammerID),
                      let nailMarker = exactOriginalAnchor("Nail", on: nailID),
                      let parent = hammer.parent, parent === nail.parent,
                      parent === wheel.parent,
                      hammer.physicsBody != nil, nail.physicsBody != nil else { continue }
                let arm = hammer.simdConvertPosition(hammerMarker.simdWorldPosition, from: nil)
                let radius = hypot(arm.x, arm.y)
                let angle = hammer.eulerAngles.z
                guard radius.isFinite, radius > 0.01, radius <= 3,
                      arm.x.isFinite, abs(arm.x) > 0.01, angle.isFinite,
                      nail.position.y.isFinite, nail.position.y >= CMOriginalHammerDrive.nailLimit
                else { continue }
                // All three private CML hammer assemblies have the same
                // right-facing arm. Geometry determines lifting sign here;
                // this is NOT a recovered native +0xDC field.
                let direction: Float = arm.x > 0 ? 1 : -1
                hammerDrives[owner.id] = HammerDrive(wheel: wheel, hammer: hammer,
                    nail: nail, hammerMarker: hammerMarker, nailMarker: nailMarker,
                    armRadius: radius, direction: direction, angle: angle)
                drivenHammerPartIDs.formUnion([hammerID, nailID])
            }
        }

        private func advanceOriginalHammerDrives(delta: Double) {
            for id in Array(hammerDrives.keys) {
                guard var drive = hammerDrives[id], !drive.finished,
                      let body = drive.wheel.physicsBody, body.type == .dynamic,
                      let parent = drive.hammer.parent else { continue }
                let angular = body.angularVelocity
                let speed = angular.z * angular.w
                guard speed.isFinite, abs(speed) <= 80 else { continue }
                let wasReleasing = drive.releasing
                if !wasReleasing {
                    guard let lift = CMOriginalHammerDrive.lift(angle: drive.angle,
                        wheelSignal: speed, direction: drive.direction, step: delta) else { continue }
                    drive.angle = lift.angle
                    drive.releasing = lift.releases
                } else {
                    guard let release = CMOriginalHammerDrive.release(angle: drive.angle,
                        direction: drive.direction, step: delta) else { continue }
                    // Stop if the reconstructed geometry cannot strike; do
                    // not spin the arm through the housing or credit GOAL.
                    drive.angle = drive.direction * max(-CMOriginalHammerDrive.liftLimit,
                                                        drive.direction * release)
                }
                drive.hammer.eulerAngles.z = drive.angle
                drive.hammer.physicsBody?.resetTransform()
                if wasReleasing {
                    // Read the actual imported marker transforms after the
                    // new pose; evaluate Y in the original assembly frame.
                    let tip = parent.simdConvertPosition(drive.hammerMarker.simdWorldPosition, from: nil)
                    let head = parent.simdConvertPosition(drive.nailMarker.simdWorldPosition, from: nil)
                    let gap = head.y - tip.y
                    if let strike = CMOriginalHammerDrive.strike(nailY: drive.nail.position.y,
                            observedGap: gap),
                       let corrected = CMOriginalHammerDrive.correctedAngle(angle: drive.angle,
                            direction: drive.direction, gap: gap, scale: drive.armRadius) {
                        drive.angle = corrected
                        drive.hammer.eulerAngles.z = corrected
                        drive.hammer.physicsBody?.resetTransform()
                        drive.nail.position.y = strike.nailY
                        drive.nail.physicsBody?.resetTransform()
                        drive.releasing = false
                        drive.finished = strike.terminal
                        // Win32 0x44BF7D–0x44BFA5: only after the nail
                        // has been clamped to -0.17 and the arm enters
                        // its terminal state, dispatch channel zero for
                        // the original HAMMER OWNER, never the nail ID.
                        if drive.finished {
                            let deliver = onOriginalHammerGoal
                            DispatchQueue.main.async { deliver?(id) }
                        }
                    }
                }
                hammerDrives[id] = drive
            }
        }

        private func registerOriginalFlasks(objects: [CMOriginalGameplaySession.Object], directory: URL) {
            flaskDrives.removeAll()
            flaskSteamImage = nil
            for item in objects where item.type == "tmo_flask" {
                let acid = objects.filter { $0.parentID == item.id && $0.type == "tmo_flask_acid" }
                guard acid.count == 1,
                      let heat = exactOriginalAnchor("Heat", on: acid[0].id),
                      let gas = exactOriginalAnchor("Gas", on: item.id)
                else { continue }
                flaskDrives[item.id] = FlaskDrive(heat: heat, gas: gas)
            }
            if !flaskDrives.isEmpty {
                // Native TEXTURE_STEAM_EFFECT at 0x431602.
                flaskSteamImage = OriginalTextureCache(directory: directory).image(named: "steam")
            }
        }

        private func advanceOriginalFlasks(delta: Double, root: SCNNode?) {
            guard !flaskDrives.isEmpty else { return }
            let states = session?.originalHeatSourceStates ?? [:]
            let candles = CMOriginalRocketSceneHeatSources.litCandleIDs(
                sourceStates: states, originalTypesByID: originalTypesByID)
                .compactMap { exactOriginalAnchor("Heat", on: $0)?.presentation.simdWorldTransform }
            let torches = states.keys.sorted().filter {
                states[$0] == true && originalTypesByID[$0] == "tmo_heat_blowtorch"
            }.compactMap { exactOriginalAnchor("Heat", on: $0)?.presentation.simdWorldTransform }
            for id in flaskDrives.keys.sorted() {
                guard var drive = flaskDrives[id] else { continue }
                let target = drive.heat.presentation.simdWorldPosition
                var input: Float?
                for source in candles {
                    let o = source.columns.3, axis = source.columns.2
                    if let fraction = CMOriginalWindowsRocketNativeHeat.projectedUCMHeatFraction(
                        observedSourceWorldYAxis: .init(axis.x, axis.y, axis.z),
                        observedSourceToTargetWorldXY: .init(target.x-o.x, target.y-o.y, 0)),
                       fraction > 0 {
                        input = max(input ?? 0, fraction * 10)
                    }
                }
                for torch in torches {
                    let o = torch.columns.3, axis = torch.columns.0
                    if abs(axis.x) > 0.5, abs(axis.y) < 0.5,
                       CMOriginalWindowsBlowtorchHeat.hits(
                        sourceX: o.x, sourceY: o.y, receiverX: target.x, receiverY: target.y,
                        sourceHorizontalDirection: axis.x) == true { input = 10 }
                }
                for focus in magnifierFoci {
                    if let heat = CMOriginalFlaskGas.focusedHeat(
                        light: focus.light, displacement: target - focus.position) {
                        input = max(input ?? 0, heat)
                    }
                }
                let m = drive.gas.presentation.simdWorldTransform
                guard drive.state.advance(input: input, delta: delta,
                    origin: .init(m.columns.3.x, m.columns.3.y, m.columns.3.z),
                    forward: .init(m.columns.1.x, m.columns.1.y, m.columns.1.z))
                else { continue }
                // Render exactly the reconstructed live particles using the
                // original steam TGA. No texture is required for the count.
                if let root, let image = flaskSteamImage {
                    while drive.visuals.count < drive.state.particles.count {
                        let plane = SCNPlane(width: 0.25, height: 0.25)
                        let material = SCNMaterial()
                        material.diffuse.contents = image
                        material.lightingModel = .constant
                        material.isDoubleSided = true
                        material.writesToDepthBuffer = false
                        plane.materials = [material]
                        let node = SCNNode(geometry: plane)
                        node.name = "original-flask-steam-effect"
                        node.constraints = [SCNBillboardConstraint()]
                        root.addChildNode(node)
                        drive.visuals.append(node)
                    }
                    while drive.visuals.count > drive.state.particles.count {
                        drive.visuals.removeLast().removeFromParentNode()
                    }
                    for (index, particle) in drive.state.particles.enumerated() {
                        drive.visuals[index].simdWorldPosition = particle.position
                        drive.visuals[index].opacity = CGFloat(min(1, max(0, particle.remaining / 2)))
                    }
                }
                if drive.state.goalReached && !drive.reported {
                    drive.reported = true
                    let deliver = onOriginalFlaskGoal
                    DispatchQueue.main.async { deliver?(id) }
                }
                flaskDrives[id] = drive
            }
        }

        private func registerOriginalSteamNetwork(objects: [CMOriginalGameplaySession.Object]) {
            steamPortNodes.removeAll()
            boilerHeatSignals.removeAll()
            steamOutgoingSignals.removeAll()
            steamReceiverOwners.removeAll()
            steamWheelByBody.removeAll()
            steamValveLevers.removeAll()
            steamPistonDrives.removeAll()
            steamScriptedPartIDs.removeAll()
            reportedSteamGoals.removeAll()
            for object in objects {
                guard let count = CMOriginalSteamNetwork.portCount(type: object.type) else { continue }
                let ports = (originalNamedAnchorNodesByObjectID[object.id] ?? []).filter {
                    CMOriginalRocketAnchorTelemetry.originalName(inSceneNodeName: $0.name ?? "") == "Pipe"
                }
                guard ports.count == count else { continue }
                steamPortNodes.append(contentsOf: ports.map { (owner: object.id, node: $0) })
                if object.type == "tmo_boiler" { boilerHeatSignals[object.id] = 0 }
                if object.type == "tmo_pipe_ventil" {
                    let levers = objects.filter { $0.parentID == object.id && $0.type == "tmo_pipe_ventil_lever" }
                    if levers.count == 1,
                       let bases = physicsNodesByObjectID[object.id], bases.count == 1,
                       let nodes = physicsNodesByObjectID[levers[0].id], nodes.count == 1 {
                        steamValveLevers[object.id] = (bases[0], nodes[0])
                    }
                }
                if object.type == "tmo_steam_body",
                   let parent = object.parentID, originalTypesByID[parent] == "tmo_steam_machine" {
                    let wheels = objects.filter { $0.parentID == parent && $0.type == "tmo_steam_wheel" }
                    guard wheels.count == 1, let nodes = physicsNodesByObjectID[wheels[0].id],
                          nodes.count == 1 else { continue }
                    steamReceiverOwners[object.id] = parent
                    steamWheelByBody[object.id] = nodes[0]
                    let pistons = objects.filter { $0.parentID == parent && $0.type == "tmo_steam_piston" }
                    let rods = objects.filter { $0.parentID == parent && $0.type == "tmo_steam_pleul" }
                    if pistons.count == 1, rods.count == 1,
                       let p = physicsNodesByObjectID[pistons[0].id], p.count == 1,
                       let r = physicsNodesByObjectID[rods[0].id], r.count == 1,
                       let assembly = nodes[0].parent, p[0].parent === assembly,
                       r[0].parent === assembly,
                       abs(nodes[0].position.x - 0.4356) < 0.005,
                       abs(p[0].position.x - 0.106) < 0.005 {
                        steamPistonDrives.append(.init(wheel: nodes[0], piston: p[0], rod: r[0],
                            wheelX: nodes[0].position.x, wheelRestAngle: nodes[0].eulerAngles.z,
                            rodRestAngle: r[0].eulerAngles.z))
                        steamScriptedPartIDs.formUnion([pistons[0].id, rods[0].id])
                    }
                }
            }
        }

        private func registerOriginalFlagDrives(objects: [CMOriginalGameplaySession.Object]) {
            flagDrives.removeAll()
            flagWindmills.removeAll()
            bellowsDrives.removeAll()
            bellowsOwnerByLeverID.removeAll()
            flagScriptedPartIDs.removeAll()
            flagWindSourceIDs = Set(objects.filter {
                $0.type == "tmo_windmill" || $0.type == "tmo_wind_bellows"
            }.map(\.id))
            func child(_ parent: String, _ kind: String) -> CMOriginalGameplaySession.Object? {
                let found = objects.filter { $0.parentID == parent && $0.type == kind }
                return found.count == 1 ? found[0] : nil
            }
            func node(_ id: String) -> SCNNode? {
                guard let nodes = physicsNodesByObjectID[id], nodes.count == 1 else { return nil }
                return nodes[0]
            }
            for owner in objects where owner.type == "tmo_belt_flag" {
                guard let w = child(owner.id, "tmo_belt_flag_wheel"),
                      let t1 = child(owner.id, "tmo_belt_flag_telescope1"),
                      let t2 = child(t1.id, "tmo_belt_flag_telescope2"),
                      let t3 = child(t2.id, "tmo_belt_flag_telescope3"),
                      let t4 = child(t3.id, "tmo_belt_flag_telescope4"),
                      let wheel = node(w.id), let n3 = node(t3.id), let n4 = node(t4.id),
                      n4.parent === n3,
                      abs(n3.position.y) < 0.001, abs(n4.position.y) < 0.001,
                      let marker = exactOriginalAnchor("Wind", on: t4.id)
                else { continue }
                flagDrives[owner.id] = .init(wheel: wheel, telescope3: n3, telescope4: n4, wind: marker)
                flagScriptedPartIDs.formUnion([t3.id,t4.id])
            }
            for owner in objects where owner.type == "tmo_wind_bellows" {
                guard let lever = child(owner.id, "tmo_wind_bellows_lever"),
                      let body = node(lever.id),
                      let marker = exactOriginalAnchor("Wind", on: owner.id)
                else { continue }
                bellowsDrives[owner.id] = .init(lever: body, wind: marker)
                bellowsOwnerByLeverID[lever.id] = owner.id
            }
            for owner in objects where owner.type == "tmo_windmill" {
                guard let w = child(owner.id, "tmo_windmill_wheel"),
                      let wings = child(owner.id, "tmo_windmill_wings"),
                      let wheel = node(w.id), let wingNode = node(wings.id),
                      let base = wingNode.parent,
                      let marker = exactOriginalAnchor("Wind", on: wings.id)
                else { continue }
                // The native wind axis does not spin with the rotor.
                // Preserve the authored Wind marker in the fixed assembly.
                let frame = SCNNode()
                base.addChildNode(frame)
                frame.simdWorldTransform = marker.simdWorldTransform
                flagWindmills[owner.id] = .init(wheel: wheel, fixedFrame: frame)
            }
        }

        // Called under sessionLock from the genuine contact callback.
        private func strikeOriginalBellows(leverID: String, otherID: String,
                                            normalY: Float, point: SCNVector3) {
            guard let id = bellowsOwnerByLeverID[leverID], var drive = bellowsDrives[id],
                  session?.physicsRole(for: otherID) == .movable,
                  point.y >= drive.lever.presentation.simdWorldPosition.y - 0.02,
                  drive.state.strike(normalY: abs(normalY),
                      leverAngle: drive.lever.presentation.eulerAngles.z)
            else { return }
            // Capture state now; change the body on the next renderer frame,
            // not while SceneKit is delivering the contact.
            bellowsDrives[id] = drive
        }

        private func bellowsObservation(id: String, target: SIMD3<Float>)
            -> CMOriginalWindowsBeltFlag.WindObservation? {
            guard let drive = bellowsDrives[id] else { return nil }
            if drive.state.power == 0 {
                return .init(originalSourceID: id, originalSourceType: "tmo_wind_bellows",
                             signedIntersection: 0, originalWindPower: 0)
            }
            let m = drive.wind.presentation.simdWorldTransform
            guard let region = drive.state.region(axis: .init(m.columns.2.x,m.columns.2.y,m.columns.2.z))
            else { return nil }
            let axis = SIMD2<Float>(region.nativeAxis.x,region.nativeAxis.y)
            let length = simd_length(axis)
            guard length.isFinite, length > 0.00001 else { return nil }
            let o = SIMD2<Float>(m.columns.3.x,m.columns.3.y) - axis / length * sqrt(region.minRadiusSquared)
            return CMOriginalWindowsBeltFlag.observedSource(originalSourceID: id,
                originalSourceType: "tmo_wind_bellows", originalWindPower: drive.state.power,
                observedNativeRegion: region, observedNativeDisplacement: .init(target.x-o.x,target.y-o.y,0),
                sourceDepth: m.columns.3.x, targetDepth: target.x)
        }

        private func advanceOriginalBellows(delta: Double) {
            for id in bellowsDrives.keys.sorted() {
                guard var drive = bellowsDrives[id], drive.state.phase != .ready,
                      drive.state.advance(delta: delta) else { continue }
                if let body = drive.lever.physicsBody, body.type != .kinematic {
                    body.clearAllForces()
                    body.velocity = SCNVector3Zero
                    body.angularVelocity = SCNVector4(0,0,0,0)
                    body.collisionBitMask = 0
                    body.contactTestBitMask = 0
                    body.type = .kinematic
                }
                drive.lever.eulerAngles.z = drive.state.leverAngle
                drive.lever.physicsBody?.resetTransform()
                bellowsDrives[id] = drive
            }
        }

        private struct WindSourceSnapshot {
            let id: String
            let power: Float
            let mirror: Float
            let origin: SIMD2<Float>
            let region: CMOriginalWindowsWindRegion.Parameters
        }

        private func originalWindSources() -> [WindSourceSnapshot] {
            var sources: [WindSourceSnapshot] = []
            func append(_ id: String, _ power: Float, _ transform: simd_float4x4,
                        _ region: CMOriginalWindowsWindRegion.Parameters?) {
                guard power.isFinite, power != 0, let region else { return }
                let axis = SIMD2<Float>(region.nativeAxis.x, region.nativeAxis.y)
                let length = simd_length(axis)
                let determinant = simd_determinant(transform)
                guard length.isFinite, length > 0.00001,
                      determinant.isFinite, abs(determinant) > 0.00001 else { return }
                let origin = SIMD2<Float>(transform.columns.3.x,transform.columns.3.y)
                    - axis / length * sqrt(region.minRadiusSquared)
                sources.append(.init(id: id, power: power, mirror: determinant < 0 ? -1 : 1,
                                     origin: origin, region: region))
            }
            for (id, drive) in bellowsDrives {
                let m = drive.wind.presentation.simdWorldTransform
                append(id, drive.state.power, m,
                    drive.state.region(axis: .init(m.columns.2.x,m.columns.2.y,m.columns.2.z)))
            }
            for (id, drive) in flagWindmills {
                guard let body = drive.wheel.physicsBody, body.type == .dynamic else { continue }
                let v = body.angularVelocity
                let power = v.z * v.w
                let m = drive.fixedFrame.presentation.simdWorldTransform
                append(id, power, m, CMOriginalWindowsBeltFlag.windmillRegion(
                    axis: .init(m.columns.2.x,m.columns.2.y,m.columns.2.z), wheelSignal: power))
            }
            return sources.sorted { $0.id < $1.id }
        }

        private func applyOriginalWindReceivers(delta: Double) {
            let sources = originalWindSources()
            guard !sources.isEmpty else { return }
            func fraction(_ source: WindSourceSnapshot, _ target: SIMD3<Float>) -> Float? {
                CMOriginalWindowsWindRegion.measuredFraction(
                    nativeDisplacement: .init(target.x-source.origin.x,target.y-source.origin.y,0),
                    region: source.region)
            }
            // Native 0x44F528 checks only other windmills, then the
            // candle prefix. Do not invent generic forces on loose bodies.
            for (owner, receiver) in flagWindmills.sorted(by: { $0.key < $1.key }) {
                guard let wingsID = windmillIDByWingsID.first(where: { $0.value == owner })?.key,
                      let wings = physicsNodesByObjectID[wingsID]?.first?.physicsBody,
                      wings.type == .dynamic else { continue }
                let matrix = receiver.fixedFrame.presentation.simdWorldTransform
                let determinant = simd_determinant(matrix)
                guard determinant.isFinite, abs(determinant) > 0.00001 else { continue }
                let mirror: Float = determinant < 0 ? -1 : 1
                let angular = wings.angularVelocity
                let previous = angular.z * angular.w
                var command = previous
                let target = receiver.fixedFrame.presentation.simdWorldPosition
                for source in sources where source.id != owner {
                    guard let f = fraction(source,target), f > 0,
                          let desired = CMOriginalWindReceiver.wingsTarget(fraction: f,
                            power: source.power, sourceMirror: source.mirror, receiverMirror: mirror),
                          let next = CMOriginalWindReceiver.nextWingsSignal(previous: command,
                            target: desired, delta: delta) else { continue }
                    command = next
                }
                // Convert the native scalar increment to bounded SceneKit
                // torque; actual Win32 inertia correspondence is provisional.
                guard delta > 0 else { continue }
                let torque = max(-2,min(2,(command-previous)/Float(delta)*0.5))
                guard torque.isFinite, abs(torque) > 0.001 else { continue }
                wings.applyTorque(SCNVector4(0,0,torque < 0 ? -1 : 1,abs(torque)), asImpulse: false)
            }
            // 0x44F6AD checks the tmo_candle prefix, selector 3 and lit
            // state, then 0x44F749..0x44F7C0 extinguishes and dispatches GOAL.
            let lit = CMOriginalRocketSceneHeatSources.litCandleIDs(
                sourceStates: session?.originalHeatSourceStates ?? [:],
                originalTypesByID: originalTypesByID)
            for id in lit {
                guard let marker = exactOriginalAnchor("Heat", on: id),
                      sources.contains(where: { source in
                          guard let f = fraction(source, marker.presentation.simdWorldPosition) else { return false }
                          return CMOriginalWindReceiver.extinguishesCandle(lit: true, fraction: f, power: source.power)
                      }),
                      session?.toggleOriginalHeatSource(id) == false else { continue }
                for glow in originalCandleGlowNodes[id] ?? [] { glow.opacity = 0 }
                let deliver = onOriginalEnvironmentalCandleGoal
                DispatchQueue.main.async { deliver?(id) }
            }
        }

        private func advanceOriginalFlags(delta: Double) {
            for id in flagDrives.keys.sorted() {
                guard var drive = flagDrives[id], let body = drive.wheel.physicsBody,
                      body.type == .dynamic else { continue }
                let angular = body.angularVelocity
                let wheelSignal = angular.z * angular.w
                guard let height = CMOriginalWindowsBeltFlag.nextExtension(
                    previous: drive.extensionValue, wheelSignal: wheelSignal, delta: delta)
                else { continue }
                drive.extensionValue = height
                drive.telescope3.position.y = height
                drive.telescope4.position.y = height
                drive.telescope3.physicsBody?.resetTransform()
                drive.telescope4.physicsBody?.resetTransform()
                // Only the authentic authored retracted flag mode is
                // reconstructed here; the alternate editor mode is not.
                // Missing bellows or any other source fails closed.
                let target = drive.wind.simdWorldPosition
                var samples: [CMOriginalWindowsBeltFlag.WindObservation] = []
                for sourceID in flagWindSourceIDs.sorted() {
                    if let sample = bellowsObservation(id: sourceID, target: target) {
                        samples.append(sample)
                        continue
                    }
                    guard let source = flagWindmills[sourceID],
                          let rotor = source.wheel.physicsBody, rotor.type == .dynamic else { continue }
                    let a = rotor.angularVelocity
                    let signal = a.z * a.w
                    guard signal.isFinite, abs(signal) <= 80 else { continue }
                    let m = source.fixedFrame.simdWorldTransform
                    if signal == 0 {
                        samples.append(.init(originalSourceID: sourceID, originalSourceType: "tmo_windmill",
                                             signedIntersection: 0, originalWindPower: 0))
                    } else if let region = CMOriginalWindowsBeltFlag.windmillRegion(
                        axis: .init(m.columns.2.x,m.columns.2.y,m.columns.2.z), wheelSignal: signal) {
                        // 0x409860 shifts the native cone origin behind
                        // its source aperture by its near distance.
                        let axis = SIMD2<Float>(region.nativeAxis.x,region.nativeAxis.y)
                        let length = simd_length(axis)
                        guard length.isFinite, length > 0.00001 else { continue }
                        let o = SIMD2<Float>(m.columns.3.x,m.columns.3.y)
                            - axis / length * sqrt(region.minRadiusSquared)
                        if let sample = CMOriginalWindowsBeltFlag.observedSource(
                            originalSourceID: sourceID, originalSourceType: "tmo_windmill",
                            originalWindPower: signal, observedNativeRegion: region,
                            observedNativeDisplacement: .init(target.x-o.x,target.y-o.y,0),
                            sourceDepth: m.columns.3.x, targetDepth: target.x) {
                            samples.append(sample)
                        }
                    }
                }
                if !drive.reported,
                   let wind = CMOriginalWindowsBeltFlag.nativeWindSum(observations: samples,
                        requiredOriginalWindSourceIDs: flagWindSourceIDs,
                        allOriginalWindSourcesObserved: samples.count == flagWindSourceIDs.count),
                   CMOriginalWindowsBeltFlag.triggersGoal(.init(telescopeIndicator: height,
                       flagState: 0, observedNetWindForce: wind)) {
                    drive.reported = true
                    let deliver = onOriginalFlagGoal
                    DispatchQueue.main.async { deliver?(id) }
                }
                flagDrives[id] = drive
            }
        }

        private func advanceOriginalSteamPistons() {
            // Native piston position is evaluated even when the wheel is
            // driven by another mechanism or the boiler has cooled.
            for drive in steamPistonDrives {
                guard let pose = CMOriginalSteamPiston.pose(wheelX: drive.wheelX,
                    wheelAngle: drive.wheel.presentation.eulerAngles.z - drive.wheelRestAngle)
                else { continue }
                drive.piston.position.x = pose.sliderX
                drive.rod.position.x = pose.sliderX
                drive.rod.eulerAngles.z = drive.rodRestAngle + pose.rodAngle
                drive.piston.physicsBody?.resetTransform()
                drive.rod.physicsBody?.resetTransform()
            }
        }

        private func advanceOriginalSteamNetwork(delta: Double) {
            guard !boilerHeatSignals.isEmpty else { return }
            let lit = CMOriginalRocketSceneHeatSources.litCandleIDs(
                sourceStates: session?.originalHeatSourceStates ?? [:],
                originalTypesByID: originalTypesByID)
            // Use the recovered candle cone on actual moving Heat markers.
            // This remains a projected SceneKit reconstruction, not a
            // measured Win32 selector-3 region or full thermal solver.
            let sources = lit.compactMap { exactOriginalAnchor("Heat", on: $0)?
                .presentation.simdWorldTransform }
            var output: [String: Float] = [:]
            for id in Array(boilerHeatSignals.keys) {
                let previous = boilerHeatSignals[id] ?? 0
                guard var heat = CMOriginalSteamNetwork.decayedBoilerHeat(previous, delta: delta)
                else { continue }
                if let target = exactOriginalAnchor("Heat", on: id)?.presentation.simdWorldPosition {
                    for source in sources {
                        let o = source.columns.3, axis = source.columns.2
                        guard let fraction = CMOriginalWindowsRocketNativeHeat.projectedUCMHeatFraction(
                            observedSourceWorldYAxis: .init(axis.x, axis.y, axis.z),
                            observedSourceToTargetWorldXY: .init(target.x-o.x, target.y-o.y, 0)),
                            fraction > 0,
                            let signal = CMOriginalSteamNetwork.heatedBoilerSignal(fraction: fraction)
                        else { continue }
                        heat = max(heat, signal)
                    }
                }
                boilerHeatSignals[id] = heat
                // Native boiler copies previous heat before decay.
                output[id] = previous
                if heat > CMOriginalWindowsSteamWhistle.cutoff,
                   reportedSteamGoals.insert(id).inserted {
                    let deliver = onOriginalSteamGoal
                    DispatchQueue.main.async { deliver?(id) }
                }
            }
            let ports = steamPortNodes.map { entry -> CMOriginalSteamNetwork.Port in
                let m = entry.node.presentation.simdWorldTransform
                return .init(owner: entry.owner, position: .init(m.columns.3.x, m.columns.3.y, m.columns.3.z),
                             normal: .init(m.columns.2.x, m.columns.2.y, m.columns.2.z))
            }
            let openValveIDs = Set(steamValveLevers.compactMap { id, pair -> String? in
                // Project the actual owner and lever local X axes into the
                // original puzzle's XY plane. World Euler-Z is ambiguous
                // under a mirrored or nested assembly.
                let a = pair.owner.presentation.simdWorldTransform.columns.0
                let b = pair.lever.presentation.simdWorldTransform.columns.0
                guard a.x*a.x+a.y*a.y > 0.00001, b.x*b.x+b.y*b.y > 0.00001,
                      CMOriginalSteamNetwork.valveConducts(ownerAngle: atan2(a.y,a.x),
                                                          leverAngle: atan2(b.y,b.x))
                else { return nil }
                return id
            })
            let state = CMOriginalSteamNetwork.advance(ports: ports, types: originalTypesByID,
                boilerSignals: output, previous: steamOutgoingSignals, delta: delta,
                openValveIDs: openValveIDs)
            steamOutgoingSignals = state.outgoing
            for (id, signal) in state.receiverSignals where originalTypesByID[id] == "tmo_pipe_whistle" {
                if CMOriginalWindowsSteamWhistle.triggersGoal(steamPower: signal),
                   reportedSteamGoals.insert(id).inserted {
                    let deliver = onOriginalSteamGoal
                    DispatchQueue.main.async { deliver?(id) }
                }
            }
            // Native 0x44C703 uses -steam/2 as the wheel target.
            // Bounded SceneKit torque is an explicit physical adapter,
            // not a recovered native force coefficient.
            for (id, wheel) in steamWheelByBody {
                guard let body = wheel.physicsBody, body.type == .dynamic else { continue }
                let velocity = body.angularVelocity
                let speed = velocity.z * velocity.w
                let target = -(state.receiverSignals[id] ?? 0) / 2
                guard speed.isFinite, target.isFinite else { continue }
                let torque = max(-2, min(2, (target - speed) * 0.5))
                if abs(torque) > 0.001 {
                    body.applyTorque(SCNVector4(0, 0, torque < 0 ? -1 : 1, abs(torque)), asImpulse: false)
                }
            }
        }

        private func registerOriginalGrillDrives(objects: [CMOriginalGameplaySession.Object]) {
            for owner in objects where owner.type == "tmo_heat_grill" {
                func unique(_ type: String) -> SCNNode? {
                    let children = objects.filter { $0.parentID == owner.id && $0.type == type }
                    guard children.count == 1,
                          let nodes = physicsNodesByObjectID[children[0].id],
                          nodes.count == 1 else { return nil }
                    return nodes[0]
                }
                guard let wheel = unique("tmo_heat_grill_wheel"),
                      let spit = unique("tmo_heat_grill_spit"),
                      let sausage = unique("tmo_heat_grill_sausage"),
                      let sausageID = objects.first(where: { $0.parentID == owner.id && $0.type == "tmo_heat_grill_sausage" })?.id,
                      let heatMarker = exactOriginalAnchor("Heat", on: sausageID),
                      spit.parent === sausage.parent,
                      simd_distance(spit.simdPosition, sausage.simdPosition) < 0.001
                else { continue }
                // Authentic spit and sausage have the same authored POSREL;
                // the long spit UCM and Mechanic01/03 markers define local X.
                var materials: [SCNMaterial] = []
                // Isolate this sausage's material; never darken other shared meshes.
                sausage.enumerateChildNodes { node, _ in
                    guard let geometry = node.geometry?.copy() as? SCNGeometry else { return }
                    geometry.materials = geometry.materials.map { ($0.copy() as? SCNMaterial) ?? $0 }
                    node.geometry = geometry
                    materials.append(contentsOf: geometry.materials)
                }
                grillDrives[owner.id] = GrillDrive(wheel: wheel, spit: spit,
                    sausage: sausage, spitRest: spit.simdOrientation,
                    sausageRest: sausage.simdOrientation, heatMarker: heatMarker,
                    materials: materials)
            }
        }

        private func advanceOriginalGrillDrives(delta: Float) {
            guard !grillDrives.isEmpty else { return }
            let lit = CMOriginalRocketSceneHeatSources.litCandleIDs(
                sourceStates: session?.originalHeatSourceStates ?? [:],
                originalTypesByID: originalTypesByID)
            let sources = lit.compactMap {
                exactOriginalAnchor("Heat", on: $0)?.presentation.simdWorldTransform
            }
            for id in Array(grillDrives.keys).sorted() {
                guard var drive = grillDrives[id],
                      let wheelBody = drive.wheel.physicsBody,
                      wheelBody.type == .dynamic else { continue }
                let angular = wheelBody.angularVelocity
                guard let phase = CMOriginalGrillDrive.phase(previous: drive.phase,
                    wheelSpeed: angular.z * angular.w, delta: delta) else { continue }
                // Both original child records receive the same signed scalar.
                // Rotate about local X, not the puzzle's planar Z wheel axis.
                let rotation = simd_quatf(angle: phase, axis: SIMD3<Float>(1, 0, 0))
                drive.spit.simdOrientation = drive.spitRest * rotation
                drive.sausage.simdOrientation = drive.sausageRest * rotation
                drive.spit.physicsBody?.resetTransform()
                drive.sausage.physicsBody?.resetTransform()
                drive.phase = phase
                // Native candle branch uses the sausage's first Heat receiver.
                // UCM marker cone projection is the current SceneKit adapter.
                let target = drive.heatMarker.presentation.simdWorldPosition
                let spitSignal = -(angular.z * angular.w)
                let wasCompleted = drive.heat.completed
                let oldShade = drive.heat.shade
                for source in sources {
                    let origin = source.columns.3, axis = source.columns.2
                    guard let fraction = CMOriginalWindowsRocketNativeHeat.projectedUCMHeatFraction(
                        observedSourceWorldYAxis: .init(axis.x, axis.y, axis.z),
                        observedSourceToTargetWorldXY: .init(target.x-origin.x, target.y-origin.y, 0)),
                        let next = CMOriginalGrillHeat.advance(drive.heat, fraction: fraction,
                            spitSignal: spitSignal, delta: Double(delta))
                    else { continue }
                    drive.heat = next
                }
                if drive.heat.shade != oldShade {
                    for material in drive.materials {
                        material.multiply.contents = UIColor(white: CGFloat(drive.heat.shade), alpha: 1)
                    }
                }
                if drive.heat.completed && !wasCompleted {
                    let deliver = onOriginalGrillGoal
                    DispatchQueue.main.async { deliver?(id) }
                }
                grillDrives[id] = drive
            }
        }

        private func transferOriginalWindmillMotion() {
            for (wingsID, wheelID) in windmillWheelByWingsID {
                guard let wheels = physicsNodesByObjectID[wheelID], wheels.count == 1,
                      let wings = physicsNodesByObjectID[wingsID], wings.count == 1,
                      let wheelBody = wheels[0].physicsBody, wheelBody.type == .dynamic,
                      let wingsBody = wings[0].physicsBody, wingsBody.type == .dynamic,
                      wheelBody !== wingsBody else { continue }
                let w = wheelBody.angularVelocity
                let v = wingsBody.angularVelocity
                guard let torque = CMOriginalWindowsWindmill.coupledTorque(
                    wheelSpeed: w.z * w.w, wingsSpeed: v.z * v.w) else { continue }
                let axisTorque = SCNVector4(0, 0, torque < 0 ? -1 : 1, abs(torque))
                wheelBody.applyTorque(axisTorque, asImpulse: false)
                wingsBody.applyTorque(axisTorque, asImpulse: false)
            }
        }

        private func refreshOriginalBelts(applyTorque: Bool = false) {
            beltLock.lock(); defer { beltLock.unlock() }
            refreshOriginalBeltsLocked(applyTorque: applyTorque)
        }

        private func refreshOriginalBeltsLocked(applyTorque: Bool) {
            for (pair, spans) in beltSpans {
                guard let first = beltWheels[pair.first], let second = beltWheels[pair.second] else { continue }
                let a = first.marker.presentation.simdWorldPosition
                let b = second.marker.presentation.simdWorldPosition
                let offset = b - a
                guard let normals = CMOriginalDriveBelt.tangentNormals(
                    dx: offset.x, dy: offset.y, dz: offset.z,
                    firstRadius: first.coefficient, secondRadius: second.coefficient)
                else { spans.forEach { $0.isHidden = true }; continue }
                for (index, normal) in [normals.0, normals.1].enumerated() {
                    let n = SIMD3<Float>(normal.x, normal.y, 0)
                    let start = a + n * first.coefficient
                    let end = b + n * second.coefficient
                    let vector = end - start
                    let length = simd_length(vector)
                    let node = spans[index]
                    guard length.isFinite, length > 0.002 else { node.isHidden = true; continue }
                    node.isHidden = false
                    node.simdPosition = (start + end) * 0.5
                    node.eulerAngles.z = atan2(vector.y, vector.x) - .pi / 2
                    (node.geometry as? SCNBox)?.height = CGFloat(length)
                }
                guard applyTorque,
                      let firstBody = physicalNode(for: first.marker)?.physicsBody, firstBody.type == .dynamic,
                      let secondBody = physicalNode(for: second.marker)?.physicsBody, secondBody.type == .dynamic,
                      firstBody !== secondBody else { continue }
                func speed(_ body: SCNPhysicsBody) -> Float {
                    let rotation = body.angularVelocity
                    return rotation.z < 0 ? -rotation.w : rotation.w
                }
                guard let torque = CMOriginalDriveBelt.correction(
                    firstSpeed: speed(firstBody), secondSpeed: speed(secondBody),
                    firstVALF: first.coefficient, secondVALF: second.coefficient) else { continue }
                func apply(_ body: SCNPhysicsBody, _ value: Float) {
                    body.applyTorque(SCNVector4(0, 0, value < 0 ? -1 : 1, abs(value)), asImpulse: false)
                }
                apply(firstBody, torque.first)
                apply(secondBody, torque.second)
            }
        }

        // Cache only unambiguous original rope markers, including in the
        // arrangement scene (which has no physics registration pass).
        func syncOriginalRopes(_ pairs: Set<CMOriginalRope.Pair>, in scene: SCNScene) {
            ropeLock.lock()
            defer { ropeLock.unlock() }
            if ropeSceneRoot !== scene.rootNode {
                ropeVisuals.values.forEach { $0.removeFromParentNode() }
                ropeVisuals.removeAll(); ropeLengths.removeAll(); ropeMarkers.removeAll()
                severedRopes.removeAll()
                ropeSceneRoot = scene.rootNode
                let types = Dictionary(uniqueKeysWithValues: (session?.objects ?? []).map { ($0.id, $0.type) })
                var duplicates = Set<CMOriginalRope.Endpoint>()
                scene.rootNode.enumerateChildNodes { node, _ in
                    guard let name = CMOriginalRocketAnchorTelemetry.originalName(inSceneNodeName: node.name ?? ""),
                          let id = self.owningOriginalObjectID(for: node), let type = types[id],
                          CMOriginalRope.accepts(type: type, marker: name) else { return }
                    let endpoint = CMOriginalRope.Endpoint(objectID: id, marker: name)
                    if self.ropeMarkers[endpoint] != nil { duplicates.insert(endpoint) }
                    else { self.ropeMarkers[endpoint] = node }
                }
                for endpoint in duplicates { ropeMarkers.removeValue(forKey: endpoint) }
            }
            for pair in Array(ropeVisuals.keys) where !pairs.contains(pair) {
                ropeVisuals.removeValue(forKey: pair)?.removeFromParentNode()
                ropeLengths.removeValue(forKey: pair)
            }
            for pair in pairs where ropeVisuals[pair] == nil && !severedRopes.contains(pair) {
                guard let a = ropeMarkers[pair.first], let b = ropeMarkers[pair.second] else { continue }
                let length = simd_distance(a.simdWorldPosition, b.simdWorldPosition)
                guard length.isFinite, length >= 0.01, length <= 30 else { continue }
                let cylinder = SCNCylinder(radius: 0.006, height: 1)
                cylinder.firstMaterial?.diffuse.contents = UIColor(red: 0.64, green: 0.49, blue: 0.30, alpha: 1)
                let visual = SCNNode(geometry: cylinder)
                visual.name = "original-player-rope"
                scene.rootNode.addChildNode(visual)
                ropeVisuals[pair] = visual
                // Freeze the arranged distance on construction of each run.
                ropeLengths[pair] = length
            }
            refreshOriginalRopesLocked(applyTension: false)
        }

        private func originalRopeEndpoint(ownerID: String, at hit: SCNVector3) -> CMOriginalRope.Endpoint? {
            ropeLock.lock(); defer { ropeLock.unlock() }
            let point = SIMD3<Float>(hit.x, hit.y, hit.z)
            return ropeMarkers.filter { $0.key.objectID == ownerID }.min {
                simd_distance_squared($0.value.presentation.simdWorldPosition, point) <
                simd_distance_squared($1.value.presentation.simdWorldPosition, point)
            }?.key
        }

        private func refreshOriginalRopes(applyTension: Bool = false) {
            ropeLock.lock(); defer { ropeLock.unlock() }
            refreshOriginalRopesLocked(applyTension: applyTension)
        }

        private func refreshOriginalRopesLocked(applyTension: Bool) {
            for (pair, visual) in ropeVisuals {
                guard let first = ropeMarkers[pair.first], let second = ropeMarkers[pair.second],
                      let rest = ropeLengths[pair] else { continue }
                let a = first.presentation.simdWorldPosition, b = second.presentation.simdWorldPosition
                let span = b - a, length = simd_length(span)
                guard length.isFinite, length >= 0.002, length <= 60 else { visual.isHidden = true; continue }
                let direction = span / length
                visual.isHidden = false
                visual.simdPosition = (a + b) * 0.5
                let up = SIMD3<Float>(0, 1, 0)
                visual.simdOrientation = simd_dot(up, direction) < -0.9999
                    ? simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0))
                    : simd_quatf(from: up, to: direction)
                (visual.geometry as? SCNCylinder)?.height = CGFloat(length)
                guard applyTension else { continue }
                let force = direction * CMOriginalRope.tension(distance: length, restLength: rest)
                func pull(_ marker: SCNNode, _ value: SIMD3<Float>) {
                    guard let owner = physicalNode(for: marker), let body = owner.physicsBody,
                          body.type == .dynamic else { return }
                    body.applyForce(SCNVector3(value.x, value.y, value.z), asImpulse: false)
                    let lever = marker.presentation.simdWorldPosition - owner.presentation.simdWorldPosition
                    let moment = simd_cross(lever, value).z
                    guard moment.isFinite, abs(moment) > 0.00001 else { return }
                    body.applyTorque(SCNVector4(0, 0, moment < 0 ? -1 : 1, min(abs(moment), 25)), asImpulse: false)
                }
                pull(first, force); pull(second, -force)
            }
        }

        private func refreshOriginalCableGeometry() {
            originalCableVisualLock.lock()
            refreshOriginalCableGeometryLocked()
            originalCableVisualLock.unlock()
        }

        func registerPhysicsNodes(in scene: SCNScene, originalDirectory: URL) {
            collectedPrototypeSources.removeAll()
            physicsNodesByObjectID.removeAll()
            appliedPhysicsRoles.removeAll()
            conveyorWheelNodes.removeAll()
            conveyorRollerNodes.removeAll()
            conveyorBeltNodes.removeAll()
            conveyorBeltMaterials.removeAll()
            conveyorTextureOffsets.removeAll()
            switchLeverNodes.removeAll()
            switchLeverRestAngles.removeAll()
            conductingSwitchIDs.removeAll()
            switchImpactGoal = CMOriginalSwitchImpactGoal()
            opticalEmitterMeshes.removeAll()
            opticalSolarMeshes.removeAll()
            originalAmmeterNeedles.removeAll()
            originalAmmeterRestAngles.removeAll()
            originalPocketLampGlowNodes.removeAll()
            originalCandleGlowNodes.removeAll()
            originalNamedAnchorNodesByObjectID.removeAll()
            originalRocketChildIDs.removeAll()
            originalRocketParentByChildID.removeAll()
            rocketSceneStages.removeAll()
            rocketSceneTerminalGate = CMOriginalRocketTerminalGate()
            rocketOriginalExplosionSpritesByChildID.removeAll()
            pendingNativeRocketEngineObservations.removeAll()
            lastNativeRocketEngineSequenceByChildID.removeAll()
            previousOriginalRocketAnchorSnapshots.removeAll()
            previousCandleRocketHeatPairs.removeAll()
            lastOriginalRocketAnchorPollTime = -1
            originalLampBulbMaterials.removeAll()
            originalLampGlowNodes.removeAll()
            originalLampDiffuseIntensity.removeAll()
            appliedLampVisualFactors = nil
            opticalEmitterByPartID.removeAll()
            previousOpticalSightlines.removeAll()
            lastOpticalSampleTime = -1
            coastingMotorRotorIDs.removeAll()
            generatorIDByRotorID.removeAll()
            windmillIDByWingsID.removeAll()
            windmillWheelByWingsID.removeAll()
            grillDrives.removeAll()
            hammerDrives.removeAll()
            drivenHammerPartIDs.removeAll()
            catapultDrives.removeAll()
            catapultSlingIDs.removeAll()
            qualifiedWindmillGoalIDs.removeAll()
            disrupterIDByWheelID.removeAll()
            lastDisrupterConduction.removeAll()
            lastGeneratorScalars.removeAll()
            lastGeneratorPollTime = 0
            catchGoalMarkerMeshes.removeAll()
            originalBallMeshes.removeAll()
            catchGoalKindsByID.removeAll()
            linkedContainerSourcesByTarget.removeAll()
            ballObjectIDs.removeAll()
            capturedCatchGoalIDs.removeAll()
            let originalObjects = session?.objects ?? []
            if let runningSession = session {
                let catchPlan = CMOriginalContainerCatchLinks(
                    session: runningSession
                )
                catchGoalKindsByID = catchPlan.goalContainerKindsByID
                linkedContainerSourcesByTarget =
                    catchPlan.linkedSourcesByTargetID
            }
            ballObjectIDs = Set(originalObjects.filter {
                $0.type.hasPrefix("tmo_ball_")
            }.map(\.id))
            switchContacts = CMOriginalSwitchContactMapper(objects: originalObjects.map {
                .init(id: $0.id, type: $0.type, parentID: $0.parentID)
            })
            originalTypesByID = Dictionary(
                uniqueKeysWithValues: originalObjects.map { ($0.id, $0.type) }
            )
            scissorsBladesByOwner.removeAll()
            firedScissorsIDs.removeAll()
            reportedCutCables.removeAll()
            for owner in originalObjects where owner.type == "tmo_rope_scissors" {
                let first = originalObjects.filter { $0.parentID == owner.id && $0.type == "tmo_rope_scissors_1" }
                let second = originalObjects.filter { $0.parentID == owner.id && $0.type == "tmo_rope_scissors_2" }
                if first.count == 1, second.count == 1 {
                    scissorsBladesByOwner[owner.id] = (first[0].id, second[0].id)
                }
            }
            originalRocketParentByChildID = Dictionary(
                uniqueKeysWithValues: originalObjects.compactMap { child
                    -> (String, String)? in
                    guard child.type == "tmo_heat_rocket_rocket",
                          let parentID = child.parentID,
                          originalTypesByID[parentID] == "tmo_heat_rocket"
                    else { return nil }
                    return (child.id, parentID)
                }
            )
            originalRocketChildIDs = Set(originalObjects.compactMap { object in
                guard object.type == "tmo_heat_rocket_rocket",
                      let parentID = object.parentID,
                      originalTypesByID[parentID] == "tmo_heat_rocket"
                else { return nil }
                return object.id
            })
            originalMechanicalVALFByID = Dictionary(
                uniqueKeysWithValues: originalObjects.compactMap { object
                    -> (String, Float)? in
                    guard let raw = object.fields["VALF"]?.first,
                          let original = Float(
                            raw.trimmingCharacters(in: .whitespacesAndNewlines)),
                          original.isFinite, original > 0 else { return nil }
                    return (object.id, original)
                }
            )
            pendingBalloonPops.removeAll()
            poppedBalloonIDs.removeAll()
            buoyantObjectIDs = Set(
                (session?.objects ?? [])
                    .filter { $0.type == "tmo_balloon" }
                    .map(\.id)
            )
            // Use only original tmo_power_motor_rotor identifiers, not
            // inferred nearby gear proximity or decorative motor meshes.
            motorRotorObjectIDs = Set(
                (session?.objects ?? [])
                    .filter { $0.type == "tmo_power_motor_rotor" }
                    .map(\.id)
            )
            generatorIDByRotorID = Dictionary(
                uniqueKeysWithValues: originalObjects.compactMap {
                    rotor -> (String, String)? in
                    guard rotor.type == "tmo_power_generator_rotor",
                          let parent = rotor.parentID,
                          originalTypesByID[parent] == "tmo_power_generator"
                    else { return nil }
                    return (rotor.id, parent)
                }
            )
            // Win32 0x44F48F selects tmo_windmill_wings (NOT wheel) via
            // 0x41F5C0, then reads wing +0xE0 for the owner GOAL.
            windmillIDByWingsID = Dictionary(uniqueKeysWithValues:
                originalObjects.compactMap { wings -> (String, String)? in
                    guard wings.type == "tmo_windmill_wings",
                          let ownerID = wings.parentID,
                          originalTypesByID[ownerID] == "tmo_windmill"
                    else { return nil }
                    return (wings.id, ownerID)
                })
            // Win32 copies the negated wheel +0xE8 to this owner's
            // wings +0xE0 (0x44BB49), and the inverse at 0x451201.
            // Only a unique pair under the same genuine windmill is valid.
            for (wingsID, ownerID) in windmillIDByWingsID {
                let wheels = originalObjects.filter {
                    $0.parentID == ownerID && $0.type == "tmo_windmill_wheel"
                }
                let wings = originalObjects.filter {
                    $0.parentID == ownerID && $0.type == "tmo_windmill_wings"
                }
                guard wheels.count == 1, wings.count == 1 else { continue }
                windmillWheelByWingsID[wingsID] = wheels[0].id
            }
            // Read the EXACT original hierarchy. Never attach a disrupter
            // to an arbitrary nearby gear by model name or proximity.
            disrupterIDByWheelID = Dictionary(
                uniqueKeysWithValues: originalObjects.compactMap {
                    wheel -> (String, String)? in
                    guard wheel.type == "tmo_power_disrupter_wheel",
                          let owner = wheel.parentID,
                          originalTypesByID[owner] == "tmo_power_disrupter"
                    else { return nil }
                    return (wheel.id, owner)
                }
            )
            magneticSourceIDs = Set(originalObjects
                .filter { $0.type == "tmo_magnetic_permanent" }.map(\.id))
            magneticTargetIDs = Set(originalObjects
                .filter { CMOriginalMagneticAttraction.responds($0.type) }
                .map(\.id))
            axleObjectIDs = Set(
                (session?.objects ?? [])
                    .filter {
                        CMOriginalAxleParts.rotatingKinds.contains($0.type)
                            || $0.type == "tmo_rope_seesaw_lever"
                    }
                    .map(\.id)
            )
            // Both genuine original optical sources have a physical tmo_
            // child whose UCM can anchor a candidate sightline. Do not
            // replace these meshes with an invented light origin.
            let emitterByPartID = Dictionary(uniqueKeysWithValues:
                originalObjects.compactMap { part -> (String, String)? in
                    guard let parent = part.parentID else { return nil }
                    let lampBulb = part.type == "tmo_power_lamp_bulb"
                        && originalTypesByID[parent] == "tmo_power_lamp"
                    let pocketGlass = part.type == "tmo_light_pocketlamp_glass"
                        && originalTypesByID[parent] == "tmo_light_pocketlamp"
                    guard lampBulb || pocketGlass else { return nil }
                    return (part.id, parent)
                }
            )
            opticalEmitterByPartID = emitterByPartID
            // Match the real CML ancestor traversal already authenticated
            // by the physical switch contact mapper. A genuine lever can
            // be nested under an original mount; direct parent-only
            // mapping silently omitted such playable switches.
            let switchByLeverID = Dictionary(uniqueKeysWithValues:
                originalObjects.compactMap { part -> (String, String)? in
                    guard part.type == "tmo_power_switch_lever",
                          let actualOwner = switchContacts?
                            .originalSwitchID(forLeverID: part.id)
                    else { return nil }
                    return (part.id, actualOwner)
                }
            )
            let ambiguousSwitchIDs = Set(Dictionary(grouping: switchByLeverID.values, by: { $0 }).filter { $0.value.count != 1 }.keys)
            scene.rootNode.enumerateChildNodes { node, _ in
                if node.name?.hasPrefix("original-ucm-anchor-") == true,
                   let owner = self.owningOriginalObjectID(for: node) {
                    self.originalNamedAnchorNodesByObjectID[owner, default: []]
                        .append(node)
                }
                if node.name == "original-rocket-effect-original-tga",
                   let owner = self.owningOriginalObjectID(for: node),
                   self.originalRocketChildIDs.contains(owner) {
                    self.rocketOriginalExplosionSpritesByChildID[
                        owner, default: []
                    ].append(node)
                    node.opacity = 0
                }
                if node.name == "original-effect-glow-to_candle_glow",
                   let heatID = self.owningOriginalObjectID(for: node),
                   ["tmo_candle", "tmo_candle_dyn"].contains(
                       self.originalTypesByID[heatID] ?? ""
                   ) {
                    self.originalCandleGlowNodes[heatID, default: []].append(node)
                    node.opacity = self.session?
                        .originalHeatSourceStates[heatID] == true ? 1 : 0
                }
                if node.name == "original-effect-glow-to_light_pocketlamp_glow",
                   let pocketlampID = self.owningOriginalObjectID(for: node),
                   self.originalTypesByID[pocketlampID] == "tmo_light_pocketlamp" {
                    self.originalPocketLampGlowNodes[pocketlampID, default: []]
                        .append(node)
                    // Win32 pocketlamp source state +0xEC begins zero.
                    // Show the genuine original glow TGA only when the
                    // actual source has been toggled to 1.
                    node.opacity = self.session?
                        .originalPocketLampStates[pocketlampID] == true ? 1 : 0
                }
                if node.name == "original-effect-glow-to_power_lamp_bulb_bb",
                   let bulbID = self.owningOriginalObjectID(for: node),
                   let lampID = emitterByPartID[bulbID],
                   self.originalTypesByID[lampID] == "tmo_power_lamp" {
                    self.originalLampGlowNodes[lampID, default: []].append(node)
                }
                if let mesh = node as? CMOriginalObjectMeshNode,
                   let owner = mesh.originalObjectID {
                    // These are real UCM vertices; synthetic glow sprites
                    // and the housing have no role in ray occlusion.
                    if let emitterID = emitterByPartID[owner],
                       ["to_power_lamp_bulb", "to_light_pocketlamp_glass"]
                           .contains(mesh.name?.lowercased() ?? "") {
                        self.opticalEmitterMeshes[emitterID] = mesh
                    }
                    if mesh.name?.lowercased() == "to_power_lamp_bulb",
                       let lampID = emitterByPartID[owner],
                       self.originalTypesByID[lampID] == "tmo_power_lamp" {
                        for material in mesh.geometry?.materials ?? [] {
                            self.originalLampBulbMaterials[lampID, default: []]
                                .append(material)
                            self.originalLampDiffuseIntensity[
                                ObjectIdentifier(material)] = material.diffuse.intensity
                        }
                    }
                    if mesh.name?.lowercased() == "to_power_solarcell",
                       self.originalTypesByID[owner] == "tmo_power_solarcell" {
                        self.opticalSolarMeshes[owner] = mesh
                    }
                }
                if let mesh = node as? CMOriginalObjectMeshNode,
                   let id = mesh.originalObjectID {
                    if (self.catchGoalKindsByID[id] != nil
                        || self.linkedContainerSourcesByTarget[id] != nil),
                       mesh.name?.lowercased() == "to_dummy_bounding" {
                        self.catchGoalMarkerMeshes[id] = mesh
                    }
                    if self.ballObjectIDs.contains(id),
                       mesh.name?.lowercased().hasPrefix("to_ball_") == true {
                        self.originalBallMeshes[id] = mesh
                    }
                }
                if let owner = node as? CMOriginalPhysicsOwnerNode,
                   let indicatorID = owner.originalObjectID,
                   self.originalTypesByID[indicatorID] ==
                       "tmo_power_amperemeter_indicator",
                   let ammeterID = originalObjects.first(where: {
                       $0.id == indicatorID
                   })?.parentID,
                   self.originalTypesByID[ammeterID] ==
                       "tmo_power_amperemeter" {
                    self.originalAmmeterNeedles[ammeterID] = owner
                    self.originalAmmeterRestAngles[ammeterID] =
                        owner.eulerAngles.z
                }
                if let owner = node as? CMOriginalPhysicsOwnerNode,
                   let leverID = owner.originalObjectID,
                   let switchID = switchByLeverID[leverID],
                   !ambiguousSwitchIDs.contains(switchID) {
                    self.switchLeverNodes[switchID] = owner
                    self.switchLeverRestAngles[switchID] = owner.eulerAngles
                }
                // Only the authentic conveyor-belt visual texture scrolls.
                // Each belt has its own copied material, so separate
                // conveyors can reverse or stop without affecting each other.
                if let mesh = node as? CMOriginalObjectMeshNode,
                   mesh.name?.lowercased() == "to_belt_conveyer_belt",
                   let ownerID = mesh.originalObjectID,
                   let material = mesh.geometry?.firstMaterial {
                    self.conveyorBeltMaterials[ownerID] = material
                    self.conveyorBeltNodes[ownerID] = mesh
                    material.diffuse.wrapS = .repeat
                }
                guard let body = node.physicsBody,
                      let id = self.physicsObjectID(for: node) else { return }
                self.physicsNodesByObjectID[id, default: []].append(node)
                if self.experimentalOriginalRocketFlight,
                   self.originalRocketChildIDs.contains(id),
                   body.type == .dynamic {
                    // The genuine PC rocket child starts attached to its
                    // parent mount. Letting it fall with SceneKit gravity at
                    // time zero detaches it before any heat is applied and
                    // prevents ignition at the authored original location.
                    // Keep its real UCM rigid body kinematic UNTIL the
                    // two-stage rocket state machine actually launches it.
                    body.clearAllForces()
                    body.velocity = SCNVector3Zero
                    body.angularVelocity = SCNVector4(0, 0, 0, 0)
                    body.type = .kinematic
                }
                if self.buoyantObjectIDs.contains(id) {
                    // The PC's balloons cannot share the standard
                    // downward-gravity behavior of crates and balls.
                    // Approximate upward buoyancy below; do not claim
                    // the acceleration matches the Windows solver.
                    body.isAffectedByGravity = false
                }
                if self.axleObjectIDs.contains(id) {
                    // These authentic original mechanisms are pinned to
                    // non-translating world hinges. Gravity on their moving
                    // bodies was constantly pulling at the hinge constraint
                    // and made the compound axles vibrate or drift.
                    // A seesaw is still tipped by colliding objects.
                    body.isAffectedByGravity = false
                }
            }
            registerOriginalGrillDrives(objects: originalObjects)
            registerOriginalHammerDrives(objects: originalObjects)
            registerOriginalCatapults(objects: originalObjects)
            registerOriginalSteamNetwork(objects: originalObjects)
            registerOriginalFlagDrives(objects: originalObjects)
            registerOriginalFlasks(objects: originalObjects, directory: originalDirectory)
            registerLiveOptics(objects: originalObjects)
            scene.rootNode.enumerateChildNodes { node, _ in
                if let id = self.owningOriginalObjectID(for: node),
                   self.originalTypesByID[id] == "tmo_light_magnifier" {
                    let side: CMOriginalMagnifier.Side?
                    switch node.name {
                    case "original-effect-glow-to_light_magnifier_glow_left": side = .negative
                    case "original-effect-glow-to_light_magnifier_glow_right": side = .positive
                    default: side = nil
                    }
                    if let side {
                        self.magnifierGlows[id, default: [:]][side] = node
                        node.opacity = 0
                    }
                }
                guard let mesh = node as? CMOriginalObjectMeshNode,
                      let id = mesh.originalObjectID,
                      self.originalTypesByID[id] == "tmo_light_flower",
                      mesh.name?.lowercased() == "to_light_flower",
                      let morpher = mesh.morpher, morpher.targets.count == 1 else { return }
                self.liveFlowerMorphers[id] = morpher
            }
            applyOriginalLampVisualFactors()
            applyOriginalAmmeterSignals()
            // Each original conveyor has a distinct child tmo_belt_conveyer_wheel
            // whose rotational velocity determines its belt movement. Never
            // connect unrelated conveyors or activate a motionless wheel.
            for part in originalObjects where part.type == "tmo_belt_conveyer_wheel" {
                guard let parentID = part.parentID,
                      originalTypesByID[parentID] == "tmo_belt_conveyer",
                      let wheelNode = physicsNodesByObjectID[part.id]?.first,
                      wheelNode.physicsBody != nil else { continue }
                conveyorWheelNodes[parentID] = wheelNode
            }
            // Each genuine conveyor has one large and three small rollers.
            // Authenticate exact CML parent ownership rather than proximity.
            for part in originalObjects {
                guard CMOriginalConveyorContact.rollerRadius(for: part.type) != nil,
                      let parentID = part.parentID,
                      originalTypesByID[parentID] == "tmo_belt_conveyer",
                      conveyorWheelNodes[parentID] != nil,
                      let nodes = physicsNodesByObjectID[part.id], nodes.count == 1,
                      let node = nodes.first, node.physicsBody != nil else { continue }
                conveyorRollerNodes[parentID, default: []].append((part.type, node))
            }
        }

        /// Inspect authentic UCM triangles along a candidate
        /// lamp-bulb/pocketlamp-glass to solar-cell segment.
        /// sightline. This measures blocking geometry and path length ONLY.
        /// The original Win32 bulb beam directions, hit fraction and
        /// reflections are not recovered, so this observation deliberately
        /// cannot activate a solar cell or a puzzle GOAL.
        func setLiveOpticalLampPower(_ values: [String: Float]) {
            sessionLock.lock()
            defer { sessionLock.unlock() }
            liveOpticalLampPower = values.filter { $0.value.isFinite && $0.value >= 0 }
        }

        private func registerLiveOptics(objects: [CMOriginalGameplaySession.Object]) {
            liveOpticalEmitters.removeAll()
            liveOpticalReceivers.removeAll()
            magnifierGlows.removeAll()
            magnifierFoci.removeAll()
            liveFlowerProgress.removeAll()
            liveFlowerMorphers.removeAll()
            liveFlowerLight.removeAll()
            reportedFlowerGoals.removeAll()
            lastSolarRays.removeAll()
            lastLiveOpticalTime = -1
            for item in objects {
                switch item.type {
                case "tmo_power_lamp":
                    let bulbs = objects.filter { $0.parentID == item.id && $0.type == "tmo_power_lamp_bulb" }
                    if bulbs.count == 1, let marker = exactOriginalAnchor("Light", on: bulbs[0].id) {
                        liveOpticalEmitters[item.id] = marker
                    }
                case "tmo_light_pocketlamp":
                    if let marker = exactOriginalAnchor("Light", on: item.id) {
                        liveOpticalEmitters[item.id] = marker
                    }
                case "tmo_power_solarcell", "tmo_light_flower", "tmo_light_magnifier":
                    if let marker = exactOriginalAnchor("Light", on: item.id) {
                        liveOpticalReceivers[item.id] = marker
                        if item.type == "tmo_light_flower" {
                            // Initial unilluminated state uses the original wilted frame.
                            liveFlowerProgress[item.id] = 1
                        }
                    }
                default: break
                }
            }
        }

        private func advanceLiveOptics(renderer: SCNSceneRenderer, at time: TimeInterval,
                                       delta: Double) {
            guard !liveOpticalReceivers.isEmpty else { return }
            if time - lastLiveOpticalTime >= 0.10, let root = renderer.scene?.rootNode {
                lastLiveOpticalTime = time
                var solar: [String: [Float]] = [:]
                var flowers: [String: Float] = [:]
                magnifierFoci.removeAll(keepingCapacity: true)
                for glows in magnifierGlows.values { for glow in glows.values { glow.opacity = 0 } }
                for (id, receiver) in liveOpticalReceivers.sorted(by: { $0.key < $1.key }) {
                    var rays: [Float] = []
                    var lensRays: [CMOriginalMagnifier.Side: [Float]] = [:]
                    let to = receiver.presentation.simdWorldPosition
                    let lens = originalTypesByID[id] == "tmo_light_magnifier"
                    let lensBasis = receiver.presentation.simdWorldTransform.columns.2
                    let lensAxis = SIMD3<Float>(lensBasis.x, lensBasis.y, lensBasis.z)
                    for (sourceID, marker) in liveOpticalEmitters.sorted(by: { $0.key < $1.key }) {
                        let kind = originalTypesByID[sourceID]
                        let power = liveOpticalLampPower[sourceID] ?? 0
                        let lit = session?.originalPocketLampStates[sourceID] == true
                        guard (kind == "tmo_power_lamp" && power > 0)
                            || (kind == "tmo_light_pocketlamp" && lit) else { continue }
                        let m = marker.presentation.simdWorldTransform
                        let from = SIMD3<Float>(m.columns.3.x, m.columns.3.y, m.columns.3.z)
                        let offset = to - from
                        let length = simd_length(offset)
                        guard length.isFinite, length > 0.001 else { continue }
                        // Direct visibility of genuine imported UCM meshes.
                        // Native optical region coordinates and occlusion are
                        // not identical to SceneKit; fail closed on blockers.
                        let hits = root.hitTestWithSegment(
                            from: SCNVector3(from.x, from.y, from.z),
                            to: SCNVector3(to.x, to.y, to.z),
                            options: [SCNHitTestOption.firstFoundOnly.rawValue: false,
                                      SCNHitTestOption.ignoreHiddenNodes.rawValue: true])
                        let unobstructed = !hits.contains { hit in
                            guard hit.node is CMOriginalObjectMeshNode else { return false }
                            guard let part = owningOriginalObjectID(for: hit.node) else { return true }
                            let owner = opticalEmitterByPartID[part] ?? part
                            return owner != id && owner != sourceID
                        }
                        let ray: Float?
                        if kind == "tmo_power_lamp" {
                            ray = CMOriginalLiveOptics.lampContribution(
                                power: power, pathLength: length, unobstructed: unobstructed)
                        } else {
                            ray = CMOriginalLiveOptics.pocketContribution(lit: lit,
                                axis: .init(m.columns.2.x, m.columns.2.y, m.columns.2.z),
                                displacement: offset, unobstructed: unobstructed)
                        }
                        if lens {
                            guard let side = CMOriginalMagnifier.incomingSide(axis: lensAxis, sourceOffset: -offset) else { continue }
                            let accepted = kind == "tmo_power_lamp"
                                ? CMOriginalMagnifier.acceptsLamp(axis: lensAxis, sourceOffset: -offset,
                                    power: power, pathLength: length, unobstructed: unobstructed)
                                : ray
                            if let accepted, accepted > 0 { lensRays[side, default: []].append(accepted) }
                        } else if let ray, ray > 0 { rays.append(ray) }
                    }
                    if lens {
                        for side in [CMOriginalMagnifier.Side.negative, .positive] {
                            let light = CMOriginalMagnifier.clampedLight(lensRays[side] ?? []) ?? 0
                            let opposite: CMOriginalMagnifier.Side = side == .negative ? .positive : .negative
                            magnifierGlows[id]?[opposite]?.opacity = CGFloat(light)
                            // Both authentic CML glow offsets are +/-0.3 on
                            // the lens's local X (Light marker local Z).
                            // Missing optional TGA must not disable physics.
                            let focus = receiver.presentation.simdConvertPosition(
                                SIMD3<Float>(0, 0, Float(opposite.rawValue) * 0.3), to: nil)
                            magnifierFoci.append((owner: id, position: focus, light: light))
                        }
                    } else if originalTypesByID[id] == "tmo_power_solarcell" {
                        solar[id] = rays
                    } else if let light = CMOriginalWindowsSolarSignal.collectedPower(rayContributions: rays) {
                        flowers[id] = light / 10
                    }
                }
                // Native 0x44CD30/0x44CF59 directly ignites a cold
                // candle at a measured focus, then dispatches owner GOAL.
                // updateAtTime already owns sessionLock.
                for id in originalTypesByID.keys.sorted() {
                    guard let type = originalTypesByID[id],
                          type == "tmo_candle" || type == "tmo_candle_dyn",
                          session?.originalHeatSourceStates[id] != true,
                          let marker = exactOriginalAnchor("Heat", on: id),
                          magnifierFoci.contains(where: { focus in
                              focus.owner != id && CMOriginalMagnifier.heats(
                                  light: focus.light, focus: focus.position,
                                  receiver: marker.presentation.simdWorldPosition)
                          }),
                          session?.igniteOriginalCandleFromFocus(id) == true else { continue }
                    for glow in originalCandleGlowNodes[id] ?? [] { glow.opacity = 1 }
                    let deliver = onOriginalEnvironmentalCandleGoal
                    DispatchQueue.main.async { deliver?(id) }
                }
                liveFlowerLight = flowers
                if solar != lastSolarRays {
                    lastSolarRays = solar
                    let deliver = onOriginalSolarRays
                    DispatchQueue.main.async { deliver?(solar) }
                }
            }
            for id in Array(liveFlowerProgress.keys).sorted() {
                guard let previous = liveFlowerProgress[id],
                      let light = liveFlowerLight[id],
                      let progress = CMOriginalWindowsFlower.nextProgress(
                        previous: previous, observedLightInput: light,
                        observedNativeDelta: delta) else { continue }
                liveFlowerProgress[id] = progress
                // Native progress 1 = unlit, 0 = fully lit. Group 1 is
                // wilted and group 0 is upright in the actual UCM.
                // Rendering clamp is separate from the native scalar.
                if let morpher = liveFlowerMorphers[id] {
                    morpher.setWeight(CGFloat(min(1, max(0, progress))), forTargetAt: 0)
                }
                if light > 0, CMOriginalWindowsFlower.triggersGoal(observedNativeProgress: progress),
                   reportedFlowerGoals.insert(id).inserted {
                    let deliver = onOriginalFlowerGoal
                    DispatchQueue.main.async { deliver?(id) }
                }
            }
        }

        private func sampleOriginalOpticalSightlines(
            renderer: SCNSceneRenderer, at time: TimeInterval
        ) {
            guard time - lastOpticalSampleTime >= 0.45 else { return }
            lastOpticalSampleTime = time

            func worldCenter(_ node: SCNNode) -> SCNVector3 {
                let bounds = node.boundingBox
                let local = SCNVector3(
                    (bounds.min.x + bounds.max.x) * 0.5,
                    (bounds.min.y + bounds.max.y) * 0.5,
                    (bounds.min.z + bounds.max.z) * 0.5
                )
                return node.presentation.convertPosition(local, to: nil)
            }
            // Segment hit testing is on SCNNode, not the SceneKit
            // renderer protocol. The scene root uses world coordinates.
            guard let root = renderer.scene?.rootNode else { return }
            let emitters = opticalEmitterMeshes.sorted { $0.key < $1.key }
            let receivers = opticalSolarMeshes.sorted { $0.key < $1.key }
            var observations: [CMOriginalOpticalSightline] = []
            // Work is bounded per renderer sample even for future complex
            // imported levels. No inferred results for unmeasured pairs.
            for (sourceID, emitterMesh) in emitters {
                for (solarID, receiverMesh) in receivers {
                    if observations.count >= 128 { break }
                    let from = worldCenter(emitterMesh)
                    let to = worldCenter(receiverMesh)
                    let hits = root.hitTestWithSegment(
                        from: from, to: to,
                        options: [
                            SCNHitTestOption.firstFoundOnly.rawValue: false,
                            SCNHitTestOption.ignoreHiddenNodes.rawValue: true
                        ]
                    )
                    // hitTestWithSegment is in nearest-to-farthest order.
                    // Ignore self-intersections at the endpoints, while any
                    // intervening original UCM object's mesh is opaque.
                    let hitOwners = hits.compactMap { hit -> String? in
                        guard hit.node is CMOriginalObjectMeshNode else { return nil }
                        guard let id = owningOriginalObjectID(for: hit.node) else {
                            // A real UCM with unresolvable ownership blocks
                            // the ray; failing closed avoids invented light.
                            return "unresolved-original-mesh"
                        }
                        return opticalEmitterByPartID[id] ?? id
                    }
                    let a = CMOriginalOpticalSightlineGeometry.Point(
                        x: from.x, y: from.y, z: from.z
                    )
                    let b = CMOriginalOpticalSightlineGeometry.Point(
                        x: to.x, y: to.y, z: to.z
                    )
                    if let result = CMOriginalOpticalSightlineGeometry.measure(
                        emitterID: sourceID, receiverID: solarID,
                        emitter: a, receiver: b,
                        obstructingObjectIDs: hitOwners
                    ) {
                        observations.append(result)
                    }
                }
                if observations.count >= 128 { break }
            }
            guard observations != previousOpticalSightlines else { return }
            previousOpticalSightlines = observations
            DispatchQueue.main.async { [weak self] in
                self?.onOriginalOpticalSightlines?(observations)
            }
        }


        /// Observe actual model-space -> world-space motion on the imported
        /// original UCM frames. Source names and ownership are validated
        /// before emitting; this is NOT original heat-region or thrust data.
        private func sampleOriginalRocketAnchorFrames(at time: TimeInterval) {
            guard !originalRocketChildIDs.isEmpty,
                  time - lastOriginalRocketAnchorPollTime >= 0.4 else { return }
            lastOriginalRocketAnchorPollTime = time
            var complete: [CMOriginalRocketAnchorTelemetry.Complete] = []
            let required = ["Heat", "Engine", "Explode", "Direction"]
            for childID in originalRocketChildIDs.sorted() {
                var frames: [CMOriginalRocketAnchorTelemetry.Frame] = []
                for node in originalNamedAnchorNodesByObjectID[childID] ?? [] {
                    guard let fullName = node.name,
                          let originalName = CMOriginalRocketAnchorTelemetry
                            .originalName(inSceneNodeName: fullName),
                          required.contains(originalName) else { continue }
                    let name = originalName
                    let matrix = node.presentation.simdWorldTransform
                    let p = matrix.columns.3
                    let y = matrix.columns.1
                    frames.append(.init(
                        rocketChildID: childID, name: name,
                        originalUCMMarkerName: originalName,
                        worldOrigin: .init(p.x, p.y, p.z),
                        worldYAxis: .init(y.x, y.y, y.z)
                    ))
                }
                // Measure the actual dynamic rocket child's SceneKit
                // body COM rather than a model or Engine-marker pivot.
                let measuredCenter: CMOriginalRocketAnchorTelemetry.Vector3?
                if let rigidNode = physicsNodesByObjectID[childID]?
                    .first(where: { $0.physicsBody?.type == .dynamic }),
                   let dynamicBody = rigidNode.physicsBody {
                    let center = rigidNode.presentation.convertPosition(
                        dynamicBody.centerOfMassOffset, to: nil)
                    measuredCenter = .init(center.x, center.y, center.z)
                } else {
                    measuredCenter = nil
                }
                if let record = CMOriginalRocketAnchorTelemetry.complete(
                    rocketChildID: childID,
                    originalParentType: "tmo_heat_rocket",
                    frames: frames,
                    observedDynamicBodyCenter: measuredCenter
                ) {
                    complete.append(record)
                }
            }
            // Native Win32 source +0xEC comes from the actual gameplay
            // session. The following links WORLD UCM Heat markers only:
            // no selector-3 region bounds, therefore never ignite.
            let litCandleIDs = (session?.originalHeatSourceStates ?? [:])
                .filter { $0.value && originalTypesByID[$0.key] == "tmo_candle" }
                .map { $0.key }.sorted().prefix(64)
            var heatPairs: [CMOriginalRocketCandleHeatPair.Observation] = []
            for candleID in litCandleIDs {
                // The original level-58 candle contains BOTH
                // candle_body.ucm and candle.ucm. Both expose the SAME
                // real Heat attachment at (0, 0.2147, 0) with the
                // identical +Z forward basis. Accept coincident real
                // attachments but never invent an arbitrary winner
                // when their physical frames differ.
                guard let sourceNode = exactOriginalAnchor(
                        "Heat", on: candleID),
                      let fullSourceName = sourceNode.name,
                      let originalSourceName = CMOriginalRocketAnchorTelemetry
                        .originalName(inSceneNodeName: fullSourceName),
                      CMOriginalWindowsNamedRegionRegistry
                        .isHeatRegionCandidate(originalSourceName)
                else { continue }
                let s = sourceNode.presentation.simdWorldTransform.columns.3
                for rocket in complete {
                    guard heatPairs.count < 512,
                          let parentID = originalRocketParentByChildID[
                            rocket.rocketChildID
                          ],
                          let measured = CMOriginalRocketCandleHeatPair.measure(
                            candleID: candleID,
                            sourceType: originalTypesByID[candleID] ?? "",
                            sourceLit: true,
                            sourceOriginalUCMMarkerName: originalSourceName,
                            sourceHeatWorld: .init(s.x, s.y, s.z),
                            rocketParentID: parentID,
                            rocketChildID: rocket.rocketChildID,
                            parentType: originalTypesByID[parentID] ?? "",
                            childType: originalTypesByID[
                                rocket.rocketChildID
                            ] ?? "",
                            rocketOriginalUCMMarkerName:
                                rocket.heat.originalUCMMarkerName,
                            targetHeatWorld: .init(
                                rocket.heat.worldOrigin.x,
                                rocket.heat.worldOrigin.y,
                                rocket.heat.worldOrigin.z)
                          ) else { continue }
                    heatPairs.append(measured)
                }
            }
            if heatPairs != previousCandleRocketHeatPairs {
                previousCandleRocketHeatPairs = heatPairs
                DispatchQueue.main.async { [weak self] in
                    self?.onOriginalCandleRocketHeatPairs?(heatPairs)
                }
            }
            guard complete != previousOriginalRocketAnchorSnapshots else { return }
            previousOriginalRocketAnchorSnapshots = complete
            DispatchQueue.main.async { [weak self] in
                self?.onOriginalRocketAnchorSnapshots?(complete)
            }
        }

        /// Reactions must be explicitly configured; imported scene data
        /// alone does not authorize an invented impulse or activation.
        func configureExperimentalReactions(_ rules: [CMOriginalGameplaySession.ReactionRule]) {
            guard rules != appliedReactionRules else { return }
            appliedReactionRules = rules
            sessionLock.lock()
            defer { sessionLock.unlock() }
            session?.configureReactions(rules)
        }

        private func applyPendingActions() {
            sessionLock.lock()
            let actions = session?.resolveActions() ?? []
            sessionLock.unlock()
            for pending in actions {
                switch pending.action {
                case .impulse(let x, let y, let z):
                    let vector = SCNVector3(Float(x), Float(y), Float(z))
                    for node in physicsNodesByObjectID[pending.sourceID] ?? [] {
                        guard let body = node.physicsBody, body.type == .dynamic else { continue }
                        body.applyForce(vector, asImpulse: true)
                    }
                case .impulseTarget(let target, let x, let y, let z):
                    let vector = SCNVector3(Float(x), Float(y), Float(z))
                    for node in physicsNodesByObjectID[target] ?? [] {
                        guard let body = node.physicsBody, body.type == .dynamic else { continue }
                        body.applyForce(vector, asImpulse: true)
                    }
                case .activate:
                    // Activation links are resolved by the gameplay session.
                    break
                }
            }
        }

        /// When an original generator rotor loses its physical SceneKit
        /// body (or its sample becomes nonfinite), do NOT keep the last
        /// nonzero electrical signal alive. Dispatch the STOP once.
        private func clearUnavailableGenerator(_ generatorID: String) {
            guard let stopped =
                CMOriginalGeneratorRotorObservation.sourceUnavailable(
                    previous: lastGeneratorScalars[generatorID])
            else { return }
            lastGeneratorScalars[generatorID] = stopped
            DispatchQueue.main.async { [weak self] in
                self?.onOriginalGeneratorSignal?(generatorID, stopped)
            }
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            // Real original power-plug endpoints follow the imported bodies
            // in both editor and physics scenes. Geometry is non-colliding.
            refreshOriginalCableGeometry()
            guard physicsEnabled else { return }
            // The renderer clock may continue while SwiftUI pauses playback.
            // Discard the first delta after pause/resume rather than crediting
            // the paused interval as simulated gameplay time.
            sessionLock.lock()
            defer { sessionLock.unlock() }
            guard session?.phase == .running else {
                lastRendererTime = nil
                return
            }
            defer { lastRendererTime = time }
            guard let previous = lastRendererTime else { return }
            let delta = time - previous
            guard delta.isFinite, delta > 0, delta <= 0.25 else { return }
            // Original Win32: abs(generator rotor +0xE8) → power at +0x40.
            // Observe real 3D rotor angular velocity; no idle generator
            // becomes a fictional constant electrical source.
            // Sample actual moving SceneKit UCM scene geometry. This is
            // independent of electric power propagation and cannot energize
            // solar cells without original ray emission/hit validation.
            sampleOriginalOpticalSightlines(renderer: renderer, at: time)
            advanceLiveOptics(renderer: renderer, at: time, delta: delta)
            sampleOriginalSwitchConduction()
            sampleOriginalScissorsCuts()
            refreshOriginalRopes(applyTension: true)
            refreshOriginalBelts(applyTorque: true)
            transferOriginalWindmillMotion()
            advanceOriginalGrillDrives(delta: Float(delta))
            advanceOriginalHammerDrives(delta: delta)
            advanceOriginalCatapults(delta: delta)
            advanceOriginalSteamNetwork(delta: delta)
            advanceOriginalSteamPistons()
            advanceOriginalBellows(delta: delta)
            applyOriginalWindReceivers(delta: delta)
            advanceOriginalFlags(delta: delta)
            advanceOriginalFlasks(delta: delta, root: renderer.scene?.rootNode)
            sampleOriginalRocketAnchorFrames(at: time)
            if time - lastGeneratorPollTime >= 0.16 {
                lastGeneratorPollTime = time
                // Win32 0x44CA59..0x44CAC8: the wheel angle modulo Pi is
                // a power gate. Observe original imported 3D wheel rotation.
                // This SceneKit Euler-Z mapping to Win32's +0xD0 scalar
                // is approximate and is not a recovered torque constant.
                for (wheelID, disrupterID) in disrupterIDByWheelID {
                    // A lost original wheel must clear its last conducting
                    // phase, not leave the connected motor/lamp energized.
                    // NaN is an unavailable observation; the native gate
                    // rejects it and the existing change latch sends it once.
                    let angle: Float
                    if let wheel = physicsNodesByObjectID[wheelID]?.first {
                        angle = wheel.presentation.eulerAngles.z
                    } else {
                        angle = .nan
                    }
                    let conducting = CMOriginalWindowsPowerDisrupter.conducts(
                        rotorAngle: angle)
                    guard lastDisrupterConduction[disrupterID] != conducting
                    else { continue }
                    lastDisrupterConduction[disrupterID] = conducting
                    DispatchQueue.main.async { [weak self] in
                        self?.onOriginalDisrupterAngle?(disrupterID, angle)
                    }
                }
                for (wingsID, windmillID) in windmillIDByWingsID {
                    // A native windmill GOAL is a once-only transition;
                    // never make SwiftUI redraw repeatedly on every rotor
                    // sample as the SceneKit angular velocity changes.
                    guard !qualifiedWindmillGoalIDs.contains(windmillID),
                          let wings = physicsNodesByObjectID[wingsID]?.first,
                          let body = wings.physicsBody,
                          body.type == .dynamic else { continue }
                    let angular = body.angularVelocity
                    let measured = angular.z < 0 ? -angular.w : angular.w
                    guard CMOriginalWindowsWindmill.triggersGoal(
                        nativeWingsSignal: measured
                    ) else { continue }
                    qualifiedWindmillGoalIDs.insert(windmillID)
                    DispatchQueue.main.async { [weak self] in
                        self?.onOriginalWindmillSignal?(windmillID, measured)
                    }
                }
                for (rotorID, generatorID) in generatorIDByRotorID {
                    guard let node = physicsNodesByObjectID[rotorID]?.first,
                          let body = node.physicsBody, body.type == .dynamic
                    else {
                        clearUnavailableGenerator(generatorID)
                        continue
                    }
                    let rotation = body.angularVelocity
                    let speed = rotation.z < 0 ? -rotation.w : rotation.w
                    guard speed.isFinite else {
                        clearUnavailableGenerator(generatorID)
                        continue
                    }
                    // Do not keep an outdated nonzero generator signal
                    // just because the new speed is within the polling
                    // threshold. A rotor entering numerical rest must emit
                    // a single real ZERO and remove its electrical source.
                    guard let reported =
                        CMOriginalGeneratorRotorObservation.report(
                            previous: lastGeneratorScalars[generatorID],
                            measured: speed) else { continue }
                    lastGeneratorScalars[generatorID] = reported
                    DispatchQueue.main.async { [weak self] in
                        self?.onOriginalGeneratorSignal?(generatorID, reported)
                    }
                }
            }
            retireOriginalBalloons()
            // Render-timestep-aware buoyancy for authentic tmo_balloon
            // parts: the original puzzles treat them as rising objects,
            // not heavy falling crates. Use a conservative acceleration
            // and speed cap until Windows physical constants are decoded.
            // Never move VALB-fixed balloons or bodies in a paused scene.
            for id in buoyantObjectIDs {
                for node in physicsNodesByObjectID[id] ?? [] {
                    guard let body = node.physicsBody,
                          body.type == .dynamic else { continue }
                    let velocity = body.velocity
                    let upSpeed = min(2.0, velocity.y + Float(delta) * 1.25)
                    body.velocity = SCNVector3(velocity.x, upSpeed, velocity.z)
                }
            }
            // Couple real internal rollers mechanically even without belt texture.
            for (conveyorID, wheel) in conveyorWheelNodes {
                guard let drive = wheel.physicsBody, drive.type == .dynamic else { continue }
                let angular = drive.angularVelocity
                let speed = angular.z < 0 ? -angular.w : angular.w
                for roller in conveyorRollerNodes[conveyorID] ?? [] {
                    guard let body = roller.node.physicsBody, body.type == .dynamic else { continue }
                    let spin = body.angularVelocity
                    let rollerSpeed = spin.z < 0 ? -spin.w : spin.w
                    guard let torque = CMOriginalConveyorContact.rollerTorque(
                        kind: roller.kind, driveSpeed: speed,
                        rollerSpeed: rollerSpeed, rollerMass: Float(body.mass)) else { continue }
                    drive.applyTorque(SCNVector4(0, 0, torque.drive < 0 ? -1 : 1,
                                                 abs(torque.drive)), asImpulse: false)
                    body.applyTorque(SCNVector4(0, 0, torque.roller < 0 ? -1 : 1,
                                                abs(torque.roller)), asImpulse: false)
                }
            }
            // Scroll the REAL original 512x64 belt texture using the same
            // signed wheel angular velocity as physical belt friction.
            // No motion is shown when the wheel is stationary, and each
            // user's SCAL-mirrored belt retains its authored mesh transform.
            for (conveyorID, wheel) in conveyorWheelNodes {
                guard let beltMaterial = conveyorBeltMaterials[conveyorID],
                      let body = wheel.physicsBody,
                      body.type == .dynamic else { continue }
                let axisSpeed = body.angularVelocity
                let omega = Float(axisSpeed.z >= 0 ? 1 : -1) * axisSpeed.w
                guard omega.isFinite, abs(omega) > 0.01 else { continue }
                let surfaceSpeed = max(-2.0, min(2.0, -omega * 0.09))
                let step = surfaceSpeed * Float(delta) / 1.18144
                let next = (conveyorTextureOffsets[conveyorID] ?? 0) + step
                let fraction = next.truncatingRemainder(dividingBy: 1.0)
                conveyorTextureOffsets[conveyorID] = fraction
                beltMaterial.diffuse.contentsTransform = SCNMatrix4MakeTranslation(
                    fraction, 0, 0
                )
            }
            // The Win32 motor writes its signed -power to rotor +0xE8
            // even when abs(power) <= 0.5; that cutoff only calls GOAL.
            // Our SceneKit speed/acceleration mapping is a bounded prototype.
            // Keep previously driven UCM rotors under control until they
            // coast to rest after the actual cable power disappears.
            let activeMotorIDs = experimentalMotorDriveEnabled
                ? motorRotorObjectIDs
                : poweredMotorRotorIDs.intersection(motorRotorObjectIDs)
            let motorsToUpdate = activeMotorIDs.union(coastingMotorRotorIDs)
            var keepCoasting = activeMotorIDs
            for id in motorsToUpdate {
                let energized = activeMotorIDs.contains(id)
                // The manual diagnostic toggle requests full prototype
                // drive. Real opt-in circuit power uses -power from Win32.
                let command: Float = energized
                    ? (poweredMotorDriveSignals[id]
                        ?? (experimentalMotorDriveEnabled ? 10 : 0))
                    : 0
                guard let targetSpeed = CMOriginalMotorActuator
                    .prototypeTargetSpeed(rotorCommand: command) else {
                    continue
                }
                var stillSpinning = false
                for node in physicsNodesByObjectID[id] ?? [] {
                    guard let body = node.physicsBody,
                          body.type == .dynamic else { continue }
                    let angular = body.angularVelocity
                    let signedSpeed = angular.z >= 0 ? angular.w : -angular.w
                    guard let nextSpeed = CMOriginalMotorActuator.prototypeStep(
                        signedAngularSpeed: signedSpeed,
                        targetSpeed: targetSpeed,
                        elapsedSeconds: delta
                    ) else { continue }
                    body.angularVelocity = SCNVector4(
                        0, 0, nextSpeed >= 0 ? 1 : -1, abs(nextSpeed)
                    )
                    if abs(nextSpeed) > 0.01 { stillSpinning = true }
                }
                if !energized && stillSpinning { keepCoasting.insert(id) }
            }
            coastingMotorRotorIDs = keepCoasting
            if experimentalMagnetismEnabled {
                // Gather ORIGINAL magnet-owner world positions once per
                // renderer frame. Some PC puzzles contain several sources;
                // each target receives only ONE capped resultant force.
                let magnets: [(x: Float, y: Float)] = magneticSourceIDs.compactMap { id in
                    guard let magnet = physicsNodesByObjectID[id]?.first else {
                        return nil
                    }
                    let center = magnet.presentation.worldPosition
                    return (x: center.x, y: center.y)
                }
                if !magnets.isEmpty {
                    for targetID in magneticTargetIDs {
                        for target in physicsNodesByObjectID[targetID] ?? [] {
                            guard let body = target.physicsBody,
                                  body.type == .dynamic else { continue }
                            let point = target.presentation.worldPosition
                            if let force = CMOriginalMagneticAttraction.combinedForce(
                                magnets: magnets,
                                targetX: point.x, targetY: point.y,
                                mass: Float(body.mass)
                            ) {
                                body.applyForce(SCNVector3(force.x, force.y, 0),
                                                asImpulse: false)
                            }
                        }
                    }
                }
            }
            session?.advance(by: delta)
            if let clock = session?.elapsedSimulationTime {
                advanceExperimentalRocketFlight(at: clock)
            }
        }


        // Win32 0x444045..0x4441A7 and 0x445110..0x4451C1:
        // a real contact near Pike or Cut marks balloon state 1.
        // 0x451734 then calls 0x458360, emits owner GOAL and removes
        // the balloon body. SceneKit contact position is a provisional
        // mapping of the native contact coordinates.
        private func observeOriginalBalloonContact(balloon: String, sharp: String,
                                                    point: SCNVector3) {
            guard buoyantObjectIDs.contains(balloon),
                  !poppedBalloonIDs.contains(balloon),
                  !pendingBalloonPops.contains(balloon),
                  let type = originalTypesByID[sharp],
                  let rule = CMOriginalBalloonPuncture.rule(for: type),
                  let marker = exactOriginalAnchor(rule.marker, on: sharp),
                  CMOriginalBalloonPuncture.hits(
                    point: SIMD3<Float>(point.x, point.y, point.z),
                    marker: marker.presentation.simdWorldPosition,
                    radius: rule.radius) else { return }
            pendingBalloonPops.insert(balloon)
        }

        private func retireOriginalBalloons() {
            for id in pendingBalloonPops.sorted() {
                guard !poppedBalloonIDs.contains(id),
                      let nodes = physicsNodesByObjectID[id], !nodes.isEmpty else { continue }
                poppedBalloonIDs.insert(id)
                buoyantObjectIDs.remove(id)
                for node in nodes {
                    node.physicsBody = nil
                    node.isHidden = true
                }
                let deliver = onOriginalBalloonGoal
                DispatchQueue.main.async { deliver?(id) }
            }
            pendingBalloonPops.removeAll()
        }

        private func exactOriginalAnchor(
            _ name: String, on ownerID: String
        ) -> SCNNode? {
            let nodes = (originalNamedAnchorNodesByObjectID[ownerID] ?? [])
                .filter { node in
                    guard let full = node.name else { return false }
                    return CMOriginalRocketAnchorTelemetry.originalName(
                        inSceneNodeName: full) == name
                }
            guard let first = nodes.first else { return nil }
            let a = first.presentation.simdWorldTransform
            let ap = a.columns.3, az = a.columns.2
            let fields = [ap.x, ap.y, ap.z, az.x, az.y, az.z]
            guard fields.allSatisfy(\.isFinite) else { return nil }
            // Genuine candle_body.ucm and candle.ucm duplicate the exact
            // Heat attachment. They represent ONE physical emitter.
            // Duplicates are safe only when origin and oriented +Z
            // agree in world space. Otherwise reject ambiguous records.
            for node in nodes.dropFirst() {
                let b = node.presentation.simdWorldTransform
                let p = b.columns.3, z = b.columns.2
                let differences = [
                    p.x - ap.x, p.y - ap.y, p.z - ap.z,
                    z.x - az.x, z.y - az.y, z.z - az.z
                ]
                guard differences.allSatisfy({
                    $0.isFinite && abs($0) <= Float(0.0001)
                }) else { return nil }
            }
            return first
        }

        /// A playable original-geometry reconstruction: live lit-candle
        /// Heat and rocket Heat/Direction UCM frames, verified PC 17-degree
        /// cone shape and >0.84 heat cutoff, then two separate >3s phases.
        /// In Stage 1 this is explicitly experimental: actual native
        /// selector-3 records, current +0xFC, Engine effect and GOAL still
        /// require independent recovery. Never credit victory here.
        private func advanceExperimentalRocketFlight(at clock: Double) {
            guard experimentalOriginalRocketFlight, clock.isFinite,
                  clock >= 0 else { return }
            // Genuine level 80 and 102 use moving tmo_candle_dyn.
            // candle_dyn.ucm has one original Heat anchor with local
            // +Z=(0,1,0). Sample its MOVING SceneKit presentation pose,
            // not a fixed decorative glow or the owner's stale start pose.
            // Its native Win32 path is different; cone projection here
            // remains explicitly experimental until selector-3 matching
            // and dynamical source-region transforms are recovered.
            // The real Win32 tmo_candle_dyn update at 0x44DAA8 checks
            // its normalized native heat direction Y < -0.8 and calls
            // the same source toggle used for mouse interaction. Without
            // this, an upside-down original moving candle would continue
            // heating the rocket forever in SceneKit. The UCM Heat +Z
            // forward vector is the ORIGINAL model's observed direction;
            // native +0x30 region-space equivalence remains provisional.
            let movingCandles = (session?.originalHeatSourceStates ?? [:])
                .filter {
                    $0.value && originalTypesByID[$0.key] == "tmo_candle_dyn"
                }.map { $0.key }.sorted().prefix(64)
            for candleID in movingCandles {
                guard let basis = exactOriginalAnchor(
                        "Heat", on: candleID)?
                        .presentation.simdWorldTransform.columns.2,
                      CMOriginalWindowsDynamicCandleTilt.shouldExtinguish(
                        observedDirectionX: basis.x,
                        observedDirectionY: basis.y,
                        observedDirectionZ: basis.z) == true
                else { continue }
                // renderer(updateAtTime:) already owns sessionLock.
                // Never lock recursively; the native auto-toggle is
                // effective during the same simulated frame.
                if session?.toggleOriginalHeatSource(candleID) == false {
                    for glow in originalCandleGlowNodes[candleID] ?? [] {
                        glow.opacity = 0
                    }
                }
            }
            let litCandles = CMOriginalRocketSceneHeatSources.litCandleIDs(
                sourceStates: session?.originalHeatSourceStates ?? [:],
                originalTypesByID: originalTypesByID)
            let sources: [simd_float4x4] = litCandles.compactMap { candleID in
                exactOriginalAnchor("Heat", on: candleID)?
                    .presentation.simdWorldTransform
            }
            // Exact original Win32 at 0x44E7E6 treats an active
            // tmo_heat_blowtorch separately from a tmo_candle. Its rocket
            // hit is a directional XY strip (0x44CC70), NOT the candle cone.
            let litBlowtorches = (session?.originalHeatSourceStates ?? [:])
                .filter {
                    $0.value && originalTypesByID[$0.key] == "tmo_heat_blowtorch"
                }
                .map { $0.key }.sorted().prefix(64)
            let blowtorchSources: [simd_float4x4] = litBlowtorches
                .compactMap { sourceID in
                    exactOriginalAnchor("Heat", on: sourceID)?
                        .presentation.simdWorldTransform
                }
            for childID in originalRocketChildIDs.sorted() {
                guard let parentID = originalRocketParentByChildID[childID],
                      originalTypesByID[parentID] == "tmo_heat_rocket",
                      originalTypesByID[childID] == "tmo_heat_rocket_rocket"
                else { continue }
                let target = exactOriginalAnchor("Heat", on: childID)?
                    .presentation.simdWorldTransform.columns.3
                // Genuine heat_rocket_rocket.ucm Direction marker has
                // local Y=(0,0,-1) and Z=(0,1,0); its plane-forward
                // vector is local +Z, NOT the out-of-plane Y axis.
                // The incorrect Y basis made planar thrust always zero.
                let direction = exactOriginalAnchor("Direction", on: childID)?
                    .presentation.simdWorldTransform.columns.2
                // The body is held kinematic on the original mount until
                // Engine activation; do NOT require dynamic state merely
                // to check launch eligibility. Parent ownership is already
                // established by originalRocketParentByChildID.
                let body = physicsNodesByObjectID[childID]?
                    .first(where: {
                        $0.physicsBody?.type == .kinematic
                            || $0.physicsBody?.type == .dynamic
                    })?.physicsBody
                let initialFC = rocketInitialFCByChildID[childID]
                var projectedFraction: Float?
                if let target {
                    for source in sources {
                        let origin = source.columns.3
                        // The ACTUAL candle.ucm Heat attachment has
                        // local Y=(0,0,-1) and Z=(0,1,0). Its local +Z
                        // is the flame's forward XY direction. Using
                        // marker +Y fed a zero XY axis into 0x409650,
                        // so a candle could NEVER heat any receiver.
                        let axis = source.columns.2
                        guard let fraction = CMOriginalWindowsRocketNativeHeat
                            .projectedUCMHeatFraction(
                                observedSourceWorldYAxis: .init(
                                    axis.x, axis.y, axis.z),
                                observedSourceToTargetWorldXY: .init(
                                    target.x - origin.x,
                                    target.y - origin.y, 0))
                        else { continue }
                        projectedFraction = max(
                            projectedFraction ?? fraction, fraction)
                    }
                }
                // Win32 calls the blowtorch strip test only on real,
                // active source/receiver selector-3 records. Here their
                // exact user-UCM Heat world positions are the explicit
                // SceneKit projection, and the authored X basis supplies
                // an estimated horizontal direction sign (+0x30 is not
                // yet directly observable from native Windows runtime).
                var projectedBlowtorchHit = false
                if let target {
                    for torch in blowtorchSources {
                        let origin = torch.columns.3
                        let horizontal = torch.columns.0
                        guard horizontal.x.isFinite,
                              horizontal.y.isFinite,
                              abs(horizontal.x) > 0.5,
                              abs(horizontal.y) < 0.5
                        else { continue }
                        if CMOriginalWindowsBlowtorchHeat.hits(
                            sourceX: origin.x, sourceY: origin.y,
                            receiverX: target.x, receiverY: target.y,
                            sourceHorizontalDirection: horizontal.x) == true {
                            projectedBlowtorchHit = true
                            break
                        }
                    }
                }
                let force: SCNVector3?
                if let direction, let initialFC,
                   direction.x.isFinite, direction.y.isFinite,
                   initialFC.isFinite, initialFC > 0,
                   Double(direction.x) * Double(direction.x)
                     + Double(direction.y) * Double(direction.y) > 0 {
                    let x = Double(direction.x) * Double(initialFC)
                    let y = Double(direction.y) * Double(initialFC)
                    if x.isFinite && y.isFinite,
                       abs(x) <= Double(Float.greatestFiniteMagnitude),
                       abs(y) <= Double(Float.greatestFiniteMagnitude) {
                        force = SCNVector3(Float(x), Float(y), 0)
                    } else { force = nil }
                } else { force = nil }
                var state = rocketSceneStages[childID]
                    ?? CMOriginalRocketStageMachine()
                let phase = state.advance(
                    time: clock, projectedCandleHeat: projectedFraction,
                    projectedBlowtorchHit: projectedBlowtorchHit,
                    rocketBodyPresent: body != nil,
                    directionAndInitialVelocityUsable: force != nil,
                    projectedMagnifierHeatHit: target.map { point in
                        magnifierFoci.contains { focus in
                            CMOriginalMagnifier.heats(light: focus.light,
                                focus: focus.position,
                                receiver: .init(point.x, point.y, point.z))
                        }
                    } ?? false)
                rocketSceneStages[childID] = state
                // Show only the genuine user's rocket_effect.tga on the
                // actual imported Explode attachment; never a fabricated
                // SceneKit particle texture or native GOAL. Playback timing
                // of this 0.45s glow is explicitly experimental until the
                // Win32 effect object's own animation is recovered.
                let visualOpacity: CGFloat
                if phase == .ended, let launchTime = state.launchTime {
                    let elapsedAfterFuse = clock - launchTime - 3
                    visualOpacity = CGFloat(max(0, min(1,
                        1 - elapsedAfterFuse / 0.45)))
                } else {
                    visualOpacity = 0
                }
                for glow in rocketOriginalExplosionSpritesByChildID[
                    childID
                ] ?? [] {
                    glow.opacity = visualOpacity
                }
                // Native EXE branch 0x44F2AD..0x44F354 emits Explode
                // BEFORE deactivating/removing the rocket rigid body via
                // 0x420A80/0x428770. Keep the authentic rocket_effect.tga
                // visible at the moving original Explode UCM frame by
                // preserving its world transform, then detach it from the
                // child BEFORE hiding/removing the exploded child mesh.
                // There is NO radial impulse in the verified x86 branch:
                // do not invent damage/force/GOAL from a texture flash.
                if phase == .ended,
                   let owner = physicsNodesByObjectID[childID]?
                       .first(where: { $0.physicsBody != nil }),
                   rocketSceneTerminalGate.consume(
                       childID: childID, phase: phase) {
                    for sprite in rocketOriginalExplosionSpritesByChildID[
                        childID
                    ] ?? [] {
                        let originalWorld = sprite.presentation.simdWorldTransform
                        var sceneRoot: SCNNode = sprite
                        while let parent = sceneRoot.parent {
                            sceneRoot = parent
                        }
                        sprite.removeFromParentNode()
                        sceneRoot.addChildNode(sprite)
                        sprite.simdWorldTransform = originalWorld
                    }
                    owner.enumerateChildNodes { child, _ in
                        guard let originalMesh = child
                            as? CMOriginalObjectMeshNode,
                            originalMesh.originalObjectID == childID
                        else { return }
                        originalMesh.isHidden = true
                    }
                    // One physical cleanup only. The original owner mount
                    // remains; no after-explosion ghost rigid body can
                    // trigger SceneKit contacts or fall through the level.
                    owner.physicsBody = nil
                    // The user's original Professor 24 and 58 each
                    // contain a GOAL-marked rocket parent. Original Win32
                    // sends this channel-0 event AFTER Explode and disposal.
                    // Use exact CML identity, original UCM Explode anchor
                    // and retired SceneKit child as the gameplay evidence.
                    // An optional TGA texture load never controls win state.
                    // Never credit GOAL from elapsed time or proximity.
                    let originalParentGoal = session?.objects.first(where: {
                        $0.id == parentID
                    })?.goalAnnotation
                    if CMOriginalRocketTerminalGate.supportsReconstructedGoal(
                        originalParentType: originalTypesByID[parentID] ?? "",
                        originalChildType: originalTypesByID[childID] ?? "",
                        originalParentGoal: originalParentGoal,
                        phase: phase,
                        genuineOriginalExplodeMarker:
                            exactOriginalAnchor("Explode", on: childID) != nil,
                        originalChildPhysicsRetired: owner.physicsBody == nil
                    ) {
                        DispatchQueue.main.async { [weak self] in
                            self?.onOriginalReconstructedRocketGoal?(
                                parentID, childID)
                        }
                    }
                }
                // Physically release the real original rocket child from
                // its launch mount ONLY when heat/fuse and Engine force
                // have both been established. No pre-ignition free fall.
                // This is a SceneKit playback approximation, not a native
                // Win32 Engine effect or a level-completion signal.
                if phase == .flying, let body, let force {
                    if body.type == .kinematic {
                        body.velocity = SCNVector3Zero
                        body.angularVelocity = SCNVector4(0, 0, 0, 0)
                        body.type = .dynamic
                    }
                    guard body.type == .dynamic else { continue }
                    body.isAffectedByGravity = false
                    body.applyForce(force, asImpulse: false)
                }
            }
        }

        /// Win32 0x44F1DD..0x44F27D applies a continuous force at the
        /// real rocket child's physical body center every engine tick.
        /// SceneKit's applyForce without a custom point uses its center
        /// of mass; a custom mesh anchor must NOT add artificial torque.
        /// No source supplies actual +0xFC yet, so normal gameplay is
        /// inert here until an independently observed Engine sample arrives.
        private func deliverObservedNativeRocketForces() {
            sessionLock.lock()
            let fresh = pendingNativeRocketEngineObservations
            pendingNativeRocketEngineObservations.removeAll()
            sessionLock.unlock()
            guard !fresh.isEmpty else { return }
            var seen = Set<String>()
            for observed in fresh {
                guard seen.insert(observed.rocketChildID).inserted,
                      CMOriginalRocketForceDelivery.fresh(
                        observed,
                        afterLastApplied:
                            lastNativeRocketEngineSequenceByChildID[
                                observed.rocketChildID
                            ]
                      ),
                      let parentID = originalRocketParentByChildID[
                        observed.rocketChildID
                      ],
                      let owner = physicsNodesByObjectID[
                        observed.rocketChildID
                      ]?.first(where: { $0.physicsBody?.type == .dynamic }),
                      let body = owner.physicsBody else { continue }
                guard let native = CMOriginalRocketForceDelivery.force(
                    observed: observed,
                    realParentID: parentID,
                    realChildID: observed.rocketChildID,
                    actualParentType: originalTypesByID[parentID] ?? "",
                    actualChildType: originalTypesByID[
                        observed.rocketChildID
                    ] ?? "",
                    childPhysicsIsDynamic: body.type == .dynamic
                ) else { continue }
                // Native physics at 0x486400 accumulates force each
                // update, never an instantaneous 3.0 or 4.0 impulse.
                body.applyForce(
                    SCNVector3(native.force.x, native.force.y, native.force.z),
                    asImpulse: false
                )
                lastNativeRocketEngineSequenceByChildID[
                    observed.rocketChildID
                ] = observed.nativeSampleSequence
            }
        }

        func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
            guard physicsEnabled else { return }
            applyPendingActions()
            sessionLock.lock()
            let running = session?.phase == .running
            sessionLock.unlock()
            guard running else { return }
            // The original force is applied ONLY with real Engine
            // telemetry and only to the matching dynamic rocket child.
            deliverObservedNativeRocketForces()

            // Win32 0x44D874..0x44D9A2: actual ball center must approach
            // the original target's Catch/Test helper at distance <0.1.
            // This is true for a GOAL bucket/cage AND an original ball
            // linked to a bucket/cage by CONNECTED_TO. A collision with
            // the outside of a container is never equivalent to catching
            // that ball. Ten authentic PC inputs use the latter channel.
            //
            // We continue sampling all balls even after a container's
            // GOAL latches: another uniquely linked original ball may
            // still need to reach the same Catch/Test point.
            for (targetID, markerMesh) in catchGoalMarkerMeshes.sorted(
                by: { $0.key < $1.key }
            ) {
                let goalKind = catchGoalKindsByID[targetID]
                let linked = linkedContainerSourcesByTarget[targetID] ?? []
                guard (goalKind != nil && !capturedCatchGoalIDs.contains(targetID))
                    || !linked.isEmpty else { continue }
                let targetWorld = markerMesh.presentation.worldPosition
                for (ballID, ballMesh) in originalBallMeshes.sorted(
                    by: { $0.key < $1.key }
                ) {
                    let needsGoal = goalKind != nil
                        && !capturedCatchGoalIDs.contains(targetID)
                    let candidateLink = linked.contains(ballID)
                    guard needsGoal || candidateLink,
                          physicsNodesByObjectID[ballID]?.first?
                            .physicsBody?.type == .dynamic else { continue }
                    let (low, high) = ballMesh.boundingBox
                    let localCenter = SCNVector3(
                        (low.x + high.x) * 0.5,
                        (low.y + high.y) * 0.5,
                        (low.z + high.z) * 0.5
                    )
                    let ballWorld = ballMesh.presentation.convertPosition(
                        localCenter, to: nil
                    )
                    guard CMOriginalWindowsCatchRadius.withinGoalRadius(
                        ballX: ballWorld.x, ballY: ballWorld.y,
                        ballZ: ballWorld.z, targetX: targetWorld.x,
                        targetY: targetWorld.y, targetZ: targetWorld.z
                    ) else { continue }

                    // GOAL is owned by the container and latches once.
                    if needsGoal, let goalKind {
                        capturedCatchGoalIDs.insert(targetID)
                        DispatchQueue.main.async { [weak self] in
                            if goalKind == "tmo_bucket" {
                                self?.onOriginalBucketCapture?(ballID, targetID)
                            } else {
                                self?.onOriginalCageCapture?(ballID, targetID)
                            }
                        }
                    }
                    // CONNECTED_TO is owned by a specific ball source.
                    // Do not award it to a different ball in the same
                    // container, nor twice from repeated physics frames.
                    if candidateLink {
                        let key = ballID + "|" + targetID
                        sessionLock.lock()
                        let fresh = reportedOriginalConnections.insert(key)
                            .inserted
                        sessionLock.unlock()
                        if fresh {
                            DispatchQueue.main.async { [weak self] in
                                self?.onOriginalConnectionContact?(ballID, targetID)
                            }
                        }
                    }
                }
            }
        }

        /// Move a ball or crate along the ORIGINAL conveyor surface only
        /// while its own authentic drive wheel is actually rotating.
        ///
        /// belt_conveyor_belt.ucm spans x=±0.59072 and tops out at y=0.08646;
        /// belt_conveyor_wheel.ucm has radius approximately 0.09 in XY.
        /// The local top-of-belt contact filter avoids pushing objects which
        /// hit the underside or frame. SceneKit supplies the physical contact;
        /// we do not manufacture conveyor motion or invent belt links.
        private func transferConveyorMotion(_ contact: SCNPhysicsContact) {
            let physicalA = physicalNode(for: contact.nodeA)
            let physicalB = physicalNode(for: contact.nodeB)
            guard let first = physicalA, let second = physicalB,
                  first !== second,
                  let aID = owningOriginalObjectID(for: first),
                  let bID = owningOriginalObjectID(for: second) else { return }

            let object: SCNNode
            let conveyorID: String
            if originalTypesByID[aID] == "tmo_belt_conveyer" {
                object = second
                conveyorID = aID
            } else if originalTypesByID[bID] == "tmo_belt_conveyer" {
                object = first
                conveyorID = bID
            } else {
                return
            }
            guard let wheel = conveyorWheelNodes[conveyorID],
                  let beltMesh = conveyorBeltNodes[conveyorID],
                  let wheelBody = wheel.physicsBody,
                  wheelBody.type == .dynamic,
                  let objectBody = object.physicsBody,
                  objectBody.type == .dynamic,
                  let kind = originalTypesByID[
                      owningOriginalObjectID(for: object) ?? ""
                  ],
                  !CMOriginalAxleParts.rotatingKinds.contains(kind)
            else { return }

            // The physical root represents the compound housing, but actual
            // contact must be tested in the belt's original 3DO coordinates.
            // This preserves nested POSREL/ROTREL and mirrored SCAL values.
            let local = beltMesh.convertPosition(contact.contactPoint, from: nil)
            let (low, high) = beltMesh.boundingBox
            let tangent = beltMesh.convertVector(SCNVector3(1, 0, 0), to: nil)
            let spin = wheelBody.angularVelocity
            let velocity = objectBody.velocity
            guard let force = CMOriginalConveyorContact.surfaceForce(
                localX: local.x, localY: local.y,
                beltMinX: low.x, beltMaxX: high.x, beltTopY: high.y,
                wheelAngularSpeed: spin.z * spin.w,
                tangentX: tangent.x, tangentY: tangent.y,
                objectVelocityX: velocity.x, objectVelocityY: velocity.y,
                mass: Float(objectBody.mass)
            ) else { return }
            objectBody.applyForce(SCNVector3(force.x, force.y, 0),
                                  asImpulse: false)
        }

        /// Consume ONLY a verified original first-level delivery, so later
        /// balls/crates can also enter the same capture zone. Keep the
        /// imported UCM model and its original authored position untouched;
        /// removing the transient SceneKit physics body is prototype-only.
        private func collectFirstLevelPrototypeSource(_ sourceID: String) {
            guard collectedPrototypeSources.insert(sourceID).inserted else { return }
            for node in physicsNodesByObjectID.removeValue(forKey: sourceID) ?? [] {
                node.physicsBody = nil
                node.isHidden = true
            }
        }

        /// Real SceneKit collision between actual original axle UCM bodies.
        /// Motors already get electrical rotor motion in updateAtTime; gears
        /// and conveyor rollers receive *physical* contact correction here.
        /// Do not infer gearbox links from CML proximity or GOAL metadata.
        private func transferGearContact(_ contact: SCNPhysicsContact) {
            guard let a = physicalNode(for: contact.nodeA),
                  let b = physicalNode(for: contact.nodeB),
                  a !== b,
                  let aID = owningOriginalObjectID(for: a),
                  let bID = owningOriginalObjectID(for: b),
                  let kindA = originalTypesByID[aID],
                  let kindB = originalTypesByID[bID],
                  CMOriginalGearContactTransfer.accepts(kindA, kindB),
                  let aBody = a.physicsBody, aBody.type == .dynamic,
                  let bBody = b.physicsBody, bBody.type == .dynamic
            else { return }
            let p = contact.contactPoint
            let posA = a.presentation.worldPosition
            let posB = b.presentation.worldPosition
            let radiusA = hypot(p.x - posA.x, p.y - posA.y)
            let radiusB = hypot(p.x - posB.x, p.y - posB.y)
            let av = aBody.angularVelocity, bv = bBody.angularVelocity
            let speedA = av.z < 0 ? -av.w : av.w
            let speedB = bv.z < 0 ? -bv.w : bv.w
            guard let pair = CMOriginalGearContactTransfer.correction(
                firstKind: kindA, secondKind: kindB,
                firstRadius: radiusA, secondRadius: radiusB,
                firstAngularSpeed: speedA, secondAngularSpeed: speedB,
                firstMass: Float(aBody.mass), secondMass: Float(bBody.mass),
                nativeFirstVALF: originalMechanicalVALFByID[aID],
                nativeSecondVALF: originalMechanicalVALFByID[bID]
            ) else { return }
            // Apply equal/opposing LINEAR contact forces as signed axle
            // torques; the native +0x84-to-angular-speed mapping is unknown.
            func torque(_ value: Float) -> SCNVector4 {
                SCNVector4(0, 0, value < 0 ? -1 : 1, abs(value))
            }
            aBody.applyTorque(torque(pair.first), asImpulse: false)
            bBody.applyTorque(torque(pair.second), asImpulse: false)
        }

        func physicsWorld(_ world: SCNPhysicsWorld, didUpdate contact: SCNPhysicsContact) {
            guard physicsEnabled else { return }
            sessionLock.lock()
            let running = session?.phase == .running
            sessionLock.unlock()
            if running {
                transferConveyorMotion(contact)
                transferGearContact(contact)
                // SceneKit commonly provides an initial didBegin impulse
                // of 0, followed by the actual positive force in didUpdate.
                // Keep the authenticated active CML pair and deliver the
                // FIRST real physical switch impact exactly once.
                guard let a = owningOriginalObjectID(
                        for: physicalNode(for: contact.nodeA)),
                      let b = owningOriginalObjectID(
                        for: physicalNode(for: contact.nodeB)),
                      a != b else { return }
                sessionLock.lock()
                guard session?.phase == .running else { sessionLock.unlock(); return }
                let actualImpact = switchContacts?.consumeImpact(
                    a, b, impulse: Double(contact.collisionImpulse),
                    aIsMovable: session?.physicsRole(for: a) == .movable,
                    bIsMovable: session?.physicsRole(for: b) == .movable)
                var newSwitch: (id: String, on: Bool)?
                if let hit = actualImpact,
                   switchLeverNodes[hit.switchID] != nil,
                   switchLeverRestAngles[hit.switchID] != nil,
                   session?.originalSwitchStates[hit.switchID] != true,
                   let state = session?.toggleOriginalSwitch(hit.switchID) {
                    switchImpactGoal.arm(hit.switchID, requestedOn: state,
                        previouslyClosed: conductingSwitchIDs.contains(hit.switchID))
                    newSwitch = (hit.switchID, state)
                }
                sessionLock.unlock()
                if let event = newSwitch {
                    DispatchQueue.main.async { [weak self] in
                        self?.animateOriginalSwitchLever(
                            event.id, isOn: event.on)
                    }
                }
            }
        }

        func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
            guard physicsEnabled else { return }
            // A pending SceneKit callback may arrive immediately after Pause.
            // Do not move a body or credit a contact outside running phase.
            sessionLock.lock()
            let running = session?.phase == .running
            sessionLock.unlock()
            guard running else { return }
            // First contact often lasts just one physics frame. Apply the
            // same authentic wheel-driven surface transfer immediately.
            transferConveyorMotion(contact)
            transferGearContact(contact)
            guard let physicalA = physicalNode(for: contact.nodeA),
                  let physicalB = physicalNode(for: contact.nodeB),
                  physicalA !== physicalB,
                  let a = owningOriginalObjectID(for: physicalA),
                  let b = owningOriginalObjectID(for: physicalB),
                  a != b else { return }
            // SceneKit can report a child mesh rather than the owning compound
            // physics node. Resolve both owners before attributing contacts.
            sessionLock.lock()
            guard session?.phase == .running else { sessionLock.unlock(); return }
            session?.recordContact(a, b, impulse: Double(contact.collisionImpulse))
            observeOriginalBalloonContact(balloon: a, sharp: b, point: contact.contactPoint)
            observeOriginalBalloonContact(balloon: b, sharp: a, point: contact.contactPoint)
            observeOriginalCatapultContact(owner: a, striker: b, point: contact.contactPoint)
            observeOriginalCatapultContact(owner: b, striker: a, point: contact.contactPoint)
            strikeOriginalBellows(leverID: a, otherID: b, normalY: contact.contactNormal.y, point: contact.contactPoint)
            strikeOriginalBellows(leverID: b, otherID: a, normalY: contact.contactNormal.y, point: contact.contactPoint)
            // Map actual SceneKit collision owners back to an original PC
            // tmo_power_switch_lever, never an adjacent housing or base.
            let leverHit = switchContacts?.beginContact(
                a, b, impulse: Double(contact.collisionImpulse),
                aIsMovable: session?.physicsRole(for: a) == .movable,
                bIsMovable: session?.physicsRole(for: b) == .movable
            )
            // This contact is the user's ACTUAL moving UCM object striking
            // the genuine CML switch lever; it can now operate the iOS
            // experimental mechanical switch and its already wired circuit.
            // Original Win32 impulse threshold/contact fields are still
            // unknown. Do not award GOAL merely from this impact.
            var impactSwitchState: (id: String, on: Bool)?
            let firstImpact = switchContacts?.consumeImpact(
                a, b, impulse: Double(contact.collisionImpulse),
                aIsMovable: session?.physicsRole(for: a) == .movable,
                bIsMovable: session?.physicsRole(for: b) == .movable)
            if let hit = firstImpact,
               switchLeverNodes[hit.switchID] != nil,
               switchLeverRestAngles[hit.switchID] != nil,
               session?.originalSwitchStates[hit.switchID] != true,
               let newState = session?.toggleOriginalSwitch(hit.switchID) {
                switchImpactGoal.arm(hit.switchID, requestedOn: newState,
                    previouslyClosed: conductingSwitchIDs.contains(hit.switchID))
                impactSwitchState = (hit.switchID, newState)
            }
            // CONNECTED_TO refers to another original level element, not
            // necessarily a tmo_zone. Report exact linked contact pairs:
            // 67 originals point to capture zones; the other 13 point to
            // crates, buckets, cages, the pocket lamp and the board.
            // Do not count generic collisions as original puzzle progress.
            var newlyObservedConnections: [(String, String)] = []
            if session?.phase == .running {
                for link in session?.originalConnections ?? [] {
                    guard (link.sourceID == a && link.targetID == b)
                           || (link.sourceID == b && link.targetID == a)
                    else { continue }
                    // Containers use their native internal Catch/Test
                    // radius, not exterior-wall physics contact. Otherwise
                    // ten original ball->bucket/cage CONNECTED_TO inputs
                    // would be falsely marked solved on first collision.
                    if link.targetType == "tmo_bucket"
                        || link.targetType == "tmo_rope_cage" {
                        continue
                    }
                    let key = link.sourceID + "|" + link.targetID
                    if reportedOriginalConnections.insert(key).inserted {
                        newlyObservedConnections.append((link.sourceID, link.targetID))
                    }
                }
            }
            // Original PC 'tmo_zone' nodes are collection areas. Notify the
            // UI of ACTUAL SceneKit contacts, not of inferred puzzle victory.
            // Report each object only once for this simulation run.
            // The registry is already built when SceneKit bodies are
            // registered. Rebuilding a dictionary for EVERY collision is
            // expensive on original levels with dozens of moving parts.
            let types = originalTypesByID
            let candidate: String?
            let zoneID: String?
            if types[a] == "tmo_zone" && types[b] != "tmo_zone" {
                candidate = b
                zoneID = a
            } else if types[b] == "tmo_zone" && types[a] != "tmo_zone" {
                candidate = a
                zoneID = b
            } else {
                candidate = nil
                zoneID = nil
            }
            let contactType: String?
            let contactIDs: (String, String)?
            let collectibleSourceID: String?
            // Each source-zone pair counts once. Original puzzles may have
            // multiple zones, and a random zone must not count as the
            // CONNECTED_TO target encoded by the Windows scene.
            if let candidate, let zoneID,
               session?.phase == .running,
               session?.physicsRole(for: candidate) == .movable,
               reportedZoneContacts.insert(candidate + "|" + zoneID).inserted {
                contactType = types[candidate]
                contactIDs = (candidate, zoneID)
                collectibleSourceID = collectiblePrototypeTargets.contains(
                    candidate + "|" + zoneID
                ) ? candidate : nil
            } else {
                contactType = nil
                contactIDs = nil
                collectibleSourceID = nil
            }
            sessionLock.unlock()
            // Never mutate SwiftUI state from the SceneKit renderer thread.
            if contactType != nil || !newlyObservedConnections.isEmpty
                || leverHit != nil || impactSwitchState != nil {
                DispatchQueue.main.async { [weak self] in
                    if let contactType, let contactIDs {
                        self?.onOriginalZoneContact?(contactType)
                        self?.onLinkedZoneContact?(contactIDs.0, contactIDs.1)
                        // SceneKit contact delegates run on the renderer
                        // thread; never delete a physics node mid-callback.
                        // The SwiftUI progress callback runs first.
                        if let collectibleSourceID {
                            self?.collectFirstLevelPrototypeSource(
                                collectibleSourceID
                            )
                        }
                    }
                    for (sourceID, targetID) in newlyObservedConnections {
                        self?.onOriginalConnectionContact?(sourceID, targetID)
                    }
                    if let leverHit {
                        self?.onOriginalSwitchContact?(leverHit)
                    }
                    if let event = impactSwitchState {
                        self?.animateOriginalSwitchLever(
                            event.id, isOn: event.on)
                    }
                }
            }
        }

        func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
            guard physicsEnabled,
                  let a = owningOriginalObjectID(
                      for: physicalNode(for: contact.nodeA)),
                  let b = owningOriginalObjectID(
                      for: physicalNode(for: contact.nodeB)) else { return }
            sessionLock.lock()
            switchContacts?.endContact(a, b)
            sessionLock.unlock()
        }

        private var originalEmission: Any?
        private weak var dragging: SCNNode?
        private var dragInitialPosition: SCNVector3?
        private var lastDragPoint: CGPoint?
        private var lastCameraPanPoint: CGPoint?
        private var dragWasActive = false
        private var rotationStartZ: Float?
        private var rotationBeforePose: CMOriginalPlacementHistory.Pose?
        private var dragBeforePose: CMOriginalPlacementHistory.Pose?
        private var placementHistory = CMOriginalPlacementHistory()
        var onCanUndoPlacementChange: ((Bool) -> Void)?
        var lastUndoPlacementRevision = 0
        private var pinchStartFieldOfView: CGFloat?
        var initialCameraTransform: SCNMatrix4?
        var initialCameraFieldOfView: CGFloat?
        var lastCameraResetRevision = 0
        var storageKey = ""
        var rotationStorageKey = ""
        var physicsEnabled = false
        var diagnosticTapImpulses = false
        private weak var pendingHingeEndpoint: SCNNode?
        private var pendingEndpointOriginalEmission: Any?
        private func clearPendingHingeEndpoint() {
            if let node = pendingHingeEndpoint {
                node.geometry?.firstMaterial?.emission.contents = pendingEndpointOriginalEmission
            }
            pendingHingeEndpoint = nil
            pendingEndpointOriginalEmission = nil
        }
        private var manualHinges: [(joint: SCNPhysicsHingeJoint, marker: SCNNode)] = []
        var originalPositions: [String: SCNVector3] = [:]
        var originalRotations: [String: SCNVector3] = [:]

        private func placementPose(of owner: SCNNode) -> CMOriginalPlacementHistory.Pose? {
            guard let id = owner.name else { return nil }
            let position = owner.position
            let angles = owner.eulerAngles
            return CMOriginalPlacementHistory.Pose(
                identifier: id,
                position: [Double(position.x), Double(position.y), Double(position.z)],
                rotation: [Double(angles.x), Double(angles.y), Double(angles.z)]
            )
        }

        private func notifyCanUndoPlacement() {
            // updateUIView may perform an Undo while SwiftUI is rendering.
            // Deliver the button-state update on the next main-queue turn.
            let available = placementHistory.canUndo
            DispatchQueue.main.async { [weak self] in
                self?.onCanUndoPlacementChange?(available)
            }
        }

        private func recordPlacement(before: CMOriginalPlacementHistory.Pose?,
                                     owner: SCNNode) {
            guard let before, let after = placementPose(of: owner),
                  placementHistory.record(before: before, after: after) else {
                return
            }
            notifyCanUndoPlacement()
        }

        func undoPlacement(in view: SCNView) {
            guard !physicsEnabled, let previous = placementHistory.undo() else { return }
            guard let owner = view.scene?.rootNode.childNode(
                withName: previous.identifier, recursively: true
            ) as? CMOriginalPhysicsOwnerNode,
                  owner.isUnlockedInOriginalLevel else {
                placementHistory.clear()
                notifyCanUndoPlacement()
                return
            }
            owner.position = SCNVector3(
                Float(previous.position[0]), Float(previous.position[1]),
                Float(previous.position[2]))
            owner.eulerAngles = SCNVector3(
                Float(previous.rotation[0]), Float(previous.rotation[1]),
                Float(previous.rotation[2]))
            // Persist the reverted pose, otherwise exiting and reopening the
            // puzzle would incorrectly replay the move that was undone.
            var positions = UserDefaults.standard.dictionary(forKey: storageKey)
                as? [String: [Double]] ?? [:]
            positions[previous.identifier] = previous.position
            UserDefaults.standard.set(positions, forKey: storageKey)
            var rotations = UserDefaults.standard.dictionary(forKey: rotationStorageKey)
                as? [String: [Double]] ?? [:]
            rotations[previous.identifier] = previous.rotation
            UserDefaults.standard.set(rotations, forKey: rotationStorageKey)
            notifyCanUndoPlacement()
        }

        // Original 3DO meshes can sit beneath any number of helper nodes.
        // Find the nearest owning tmo_ transform instead of assuming a
        // fixed mesh -> 3DO -> object hierarchy.
        private func originalOwner(for node: SCNNode?) -> CMOriginalPhysicsOwnerNode? {
            var current = node
            while let candidate = current {
                if let owner = candidate as? CMOriginalPhysicsOwnerNode { return owner }
                current = candidate.parent
            }
            return nil
        }

        @objc func resetSelected(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let view = gesture.view as? SCNView else { return }
            if physicsEnabled {
                guard let node = originalObjectHit(
                       in: view, at: gesture.location(in: view))?.node,
                      let physical = physicalNode(for: node),
                      let body = physical.physicsBody else { return }
                // A pending hinge selection must not survive a body-type
                // change: its cached endpoint can become a static body.
                clearPendingHingeEndpoint()
                // Diagnostic-only manual classification: we have not decoded
                // which original game components are fixed versus movable.
                // Convert the current simulated world pose into a stable local
                // transform before changing the body's simulation type.
                // Otherwise SceneKit can snap a moving part back to its
                // initial authored transform when it becomes static.
                let makeStatic = body.type == .dynamic
                if makeStatic {
                    physical.transform = physical.presentation.transform
                }
                if makeStatic {
                    // Stop existing motion before pinning a test component.
                    body.clearAllForces()
                    body.velocity = SCNVector3Zero
                    body.angularVelocity = SCNVector4(0, 0, 0, 0)
                }
                body.type = makeStatic ? .static : .dynamic
                // Visual feedback is per node, so shared imported geometry
                // and the original GOAL material tint are left untouched.
                physical.opacity = makeStatic ? 0.55 : 1.0
                return
            }
            guard
                  let selected = highlighted,
                  originalObjectHit(
                       in: view, at: gesture.location(in: view))?.node === selected,
                  let owner = originalOwner(for: selected),
                  owner.isUnlockedInOriginalLevel,
                  let identifier = owner.name,
                  let original = originalPositions[identifier] else { return }
            let before = placementPose(of: owner)
            owner.position = original
            if let originalAngles = originalRotations[identifier] {
                owner.eulerAngles = originalAngles
            }
            var positions = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: [Double]] ?? [:]
            positions.removeValue(forKey: identifier)
            UserDefaults.standard.set(positions, forKey: storageKey)
            var rotations = UserDefaults.standard.dictionary(forKey: rotationStorageKey)
                as? [String: [Double]] ?? [:]
            rotations.removeValue(forKey: identifier)
            UserDefaults.standard.set(rotations, forKey: rotationStorageKey)
            recordPlacement(before: before, owner: owner)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIRotationGestureRecognizer {
                return !physicsEnabled
                    && originalOwner(for: highlighted)?.isUnlockedInOriginalLevel == true
            }
            if gestureRecognizer is UIPinchGestureRecognizer {
                return !physicsEnabled
            }
            // Two-finger camera panning works without a selected part.
            // One-finger dragging can start immediately on ANY authentic
            // UNLOCKED object; a preliminary selection tap is unnecessary.
            if let pan = gestureRecognizer as? UIPanGestureRecognizer,
               pan.minimumNumberOfTouches == 2 {
                return !physicsEnabled
            }
            guard gestureRecognizer is UIPanGestureRecognizer else { return true }
            guard !physicsEnabled,
                  let view = gestureRecognizer.view as? SCNView,
                  let hit = originalObjectHit(
                     in: view, at: gestureRecognizer.location(in: view)
                   ),
                  originalOwner(for: hit.node)?.isUnlockedInOriginalLevel == true
            else { return false }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            false
        }

        @objc func panCamera(_ gesture: UIPanGestureRecognizer) {
            guard !physicsEnabled,
                  let view = gesture.view as? SCNView,
                  let camera = view.pointOfView else {
                lastCameraPanPoint = nil
                return
            }
            let point = gesture.location(in: view)
            switch gesture.state {
            case .began:
                lastCameraPanPoint = point
            case .changed:
                guard let previous = lastCameraPanPoint else {
                    lastCameraPanPoint = point
                    return
                }
                // Project the authored scene center, NOT a point one unit
                // in front of the lens. At real puzzle scale a near-camera
                // plane makes even large finger swipes barely move the view.
                // The invisible target is fixed in scene space and does not
                // change the imported models, camera orbit or physics.
                let focus = view.scene?.rootNode.childNode(
                    withName: "original-level-framing-target", recursively: false
                )?.presentation.worldPosition ?? camera.presentation.convertPosition(
                    SCNVector3(0, 0, -1), to: nil
                )
                let depth = view.projectPoint(focus).z
                guard depth.isFinite else { return }
                let from = view.unprojectPoint(SCNVector3(
                    Float(previous.x), Float(view.bounds.height - previous.y),
                    depth
                ))
                let to = view.unprojectPoint(SCNVector3(
                    Float(point.x), Float(view.bounds.height - point.y),
                    depth
                ))
                // Move the camera opposite the finger's world-space motion
                // so the original meshes track the two-finger drag. The
                // imported level geometry and saved object poses are intact.
                let next = SCNVector3(
                    camera.position.x + from.x - to.x,
                    camera.position.y + from.y - to.y,
                    camera.position.z + from.z - to.z
                )
                if [next.x, next.y, next.z].allSatisfy({
                    $0.isFinite && abs($0) < 1_000_000
                }) {
                    camera.position = next
                    lastCameraPanPoint = point
                }
            case .ended, .cancelled, .failed:
                lastCameraPanPoint = nil
            default:
                break
            }
        }

        @objc func zoomCamera(_ gesture: UIPinchGestureRecognizer) {
            guard !physicsEnabled,
                  let view = gesture.view as? SCNView,
                  let camera = view.pointOfView?.camera else { return }
            switch gesture.state {
            case .began:
                pinchStartFieldOfView = camera.fieldOfView
            case .changed:
                guard let initial = pinchStartFieldOfView, gesture.scale > 0 else { return }
                let requested = initial / gesture.scale
                guard requested.isFinite else { return }
                // Preserve the camera's authored placement and orientation;
                // only change its framing while editing the imported puzzle.
                camera.fieldOfView = min(95, max(15, requested))
            case .ended, .cancelled, .failed:
                pinchStartFieldOfView = nil
            default:
                break
            }
        }

        @objc func rotateSelected(_ gesture: UIRotationGestureRecognizer) {
            // Placement changes the tmo_ object's own transform. Rendering
            // and physics will inherit the original nested 3DO offsets.
            guard !physicsEnabled,
                  let selected = highlighted,
                  let owner = originalOwner(for: selected),
                  owner.isUnlockedInOriginalLevel else { return }
            switch gesture.state {
            case .began:
                rotationStartZ = owner.eulerAngles.z
                rotationBeforePose = placementPose(of: owner)
            case .changed:
                guard let initial = rotationStartZ else { return }
                let next = initial + Float(gesture.rotation)
                if next.isFinite && abs(next) <= 100_000 {
                    owner.eulerAngles.z = next
                    refreshOriginalCableGeometry()
                    refreshOriginalRopes()
                    refreshOriginalBelts()
                }
            case .ended:
                if let identifier = owner.name,
                   identifier.hasPrefix("original-node-") {
                    var saved = UserDefaults.standard.dictionary(forKey: rotationStorageKey)
                        as? [String: [Double]] ?? [:]
                    let angles = owner.eulerAngles
                    saved[identifier] = [
                        Double(angles.x), Double(angles.y), Double(angles.z)
                    ]
                    UserDefaults.standard.set(saved, forKey: rotationStorageKey)
                }
                recordPlacement(before: rotationBeforePose, owner: owner)
                rotationBeforePose = nil
                rotationStartZ = nil
            case .cancelled, .failed:
                if let original = rotationStartZ { owner.eulerAngles.z = original }
                rotationBeforePose = nil
                rotationStartZ = nil
            default:
                break
            }
        }

        @objc func dragSelected(_ gesture: UIPanGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            let point = gesture.location(in: view)
            switch gesture.state {
            case .began:
                guard !physicsEnabled,
                      let hit = originalObjectHit(in: view, at: point),
                      let owner = originalOwner(for: hit.node),
                      owner.isUnlockedInOriginalLevel else { return }
                // Select the dragged original UCM for consistent tint and
                // VoiceOver feedback. Never move a locked or decorative mesh.
                highlightOriginalMesh(hit.node, in: view)
                // Move the owning original object transform, not its 3DO
                // wrapper; keep every nested model offset intact.
                dragging = owner
                dragBeforePose = placementPose(of: owner)
                dragInitialPosition = owner.position
                lastDragPoint = point
                dragWasActive = true
            case .changed:
                guard let target = dragging, let previous = lastDragPoint,
                      view.pointOfView != nil else { return }
                // Move in the camera-facing plane, preserving the object's
                // depth and original parent coordinate system.
                let world = target.presentation.worldPosition
                let projected = view.projectPoint(world)
                // UIKit gestures use top-left origin; SceneKit projection
                // coordinates use bottom-left origin.
                let from = view.unprojectPoint(SCNVector3(Float(previous.x), Float(view.bounds.height - previous.y), projected.z))
                let to = view.unprojectPoint(SCNVector3(Float(point.x), Float(view.bounds.height - point.y), projected.z))
                let parent = target.parent
                let fromLocal = parent?.convertPosition(from, from: nil) ?? from
                let toLocal = parent?.convertPosition(to, from: nil) ?? to
                let delta = SCNVector3(toLocal.x - fromLocal.x,
                                       toLocal.y - fromLocal.y,
                                       toLocal.z - fromLocal.z)
                let next = SCNVector3(target.position.x + delta.x,
                                      target.position.y + delta.y,
                                      target.position.z + delta.z)
                if next.x.isFinite && next.y.isFinite && next.z.isFinite {
                    target.position = next
                    refreshOriginalCableGeometry()
                    refreshOriginalRopes()
                    refreshOriginalBelts()
                    lastDragPoint = point
                }
             default:
                if gesture.state == .cancelled || gesture.state == .failed,
                   let target = dragging, let initial = dragInitialPosition {
                    target.position = initial
                }
                if gesture.state == .ended, let target = dragging,
                   let identifier = target.name, identifier.hasPrefix("original-node-") {
                    var positions = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: [Double]] ?? [:]
                    positions[identifier] = [Double(target.position.x),
                                             Double(target.position.y),
                                             Double(target.position.z)]
                    UserDefaults.standard.set(positions, forKey: storageKey)
                    recordPlacement(before: dragBeforePose, owner: target)
                }
                dragging = nil
                dragBeforePose = nil
                dragInitialPosition = nil
                lastDragPoint = nil
                dragWasActive = false
            }
        }

        @objc func removeLastManualHinge(_ gesture: UITapGestureRecognizer) {
            guard physicsEnabled, gesture.state == .ended,
                  let view = gesture.view as? SCNView,
                  let scene = view.scene else { return }
            // A pending first endpoint is a selection, not an installed
            // constraint. Cancel it before undoing an older hinge.
            if pendingHingeEndpoint != nil {
                clearPendingHingeEndpoint()
                return
            }
            guard let last = manualHinges.popLast() else { return }
            let wasPlaying = view.isPlaying
            view.isPlaying = false
            scene.physicsWorld.removeBehavior(last.joint)
            last.marker.removeFromParentNode()
            clearPendingHingeEndpoint()
            view.isPlaying = wasPlaying
        }

        @objc func selectHingeEndpoint(_ gesture: UITapGestureRecognizer) {
            guard physicsEnabled, gesture.state == .ended,
                  let view = gesture.view as? SCNView,
                  let scene = view.scene,
                  let node = originalObjectHit(
                       in: view, at: gesture.location(in: view))?.node,
                  // The temporary support floor and hinge markers are not
                  // original parts. Never let them become hinge endpoints.
                  node is CMOriginalObjectMeshNode,
                  let body = physicalNode(for: node)?.physicsBody else { return }
            if let first = pendingHingeEndpoint {
                // A second tap on the same mesh or another mesh belonging
                // to the same rigid body is not a new hinge endpoint.
                // Preserve the pending selection so the user can still
                // choose a different original object. If the first body's
                // physics was removed, cancel the now-stale endpoint.
                guard let firstPhysical = physicalNode(for: first),
                      let secondPhysical = physicalNode(for: node) else {
                    clearPendingHingeEndpoint()
                    return
                }
                guard first !== node,
                      firstPhysical !== secondPhysical else { return }
            }
            guard let first = pendingHingeEndpoint else {
                // First tap: retain a visible endpoint until another body is chosen.
                // Imported UCM geometries are cached and shared across
                // instances. Give this endpoint its own geometry/materials
                // before tinting it, or every copy of the part turns cyan.
                if let geometry = node.geometry {
                    let unique = geometry.copy() as! SCNGeometry
                    unique.materials = geometry.materials.map { $0.copy() as! SCNMaterial }
                    node.geometry = unique
                }
                pendingHingeEndpoint = node
                pendingEndpointOriginalEmission = node.geometry?.firstMaterial?.emission.contents
                node.geometry?.firstMaterial?.emission.contents = UIColor.systemCyan
                return
            }
            guard let firstPhysical = physicalNode(for: first),
                  let secondPhysical = physicalNode(for: node),
                  let firstBody = firstPhysical.physicsBody else {
                clearPendingHingeEndpoint()
                return
            }
            // Both endpoints exist and belong to distinct rigid bodies.
            // Keep the first endpoint highlighted until all validation passes.
            // A world-space midpoint gives a reproducible test connection.
            // This is not a recovered original-game joint.
            let a = first.presentation.convertPosition(SCNVector3Zero, to: nil)
            let b = node.presentation.convertPosition(SCNVector3Zero, to: nil)
            // Use the actual visible surface hit on the second part as
            // the attachment location, rather than a midpoint of pivots.
            let anchor = originalObjectHit(
                in: view, at: gesture.location(in: view))?.worldCoordinates ?? SCNVector3(
                (a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)
            // Reject hinges based on the nearest visible surfaces, not the
            // distance between model pivots. Original UCM pivots can be far
            // outside the mesh, even when two parts visibly touch.
            func surfaceCorners(_ mesh: SCNNode) -> [SCNVector3] {
                let (lo, hi) = mesh.boundingBox
                return [lo.x, hi.x].flatMap { x in
                    [lo.y, hi.y].flatMap { y in
                        [lo.z, hi.z].map { z in
                            mesh.presentation.convertPosition(SCNVector3(x, y, z), to: nil)
                        }
                    }
                }
            }
            let firstCorners = surfaceCorners(first)
            let secondCorners = surfaceCorners(node)
            // Corner-to-corner distances incorrectly reject two long parts
            // touching at their faces or edges. Compare world-space bounding
            // intervals instead; overlapping intervals have zero gap.
            func bounds(_ corners: [SCNVector3]) -> (SCNVector3, SCNVector3)? {
                guard let first = corners.first else { return nil }
                var low = first, high = first
                for corner in corners {
                    guard corner.x.isFinite, corner.y.isFinite, corner.z.isFinite else {
                        return nil
                    }
                    low.x = min(low.x, corner.x); high.x = max(high.x, corner.x)
                    low.y = min(low.y, corner.y); high.y = max(high.y, corner.y)
                    low.z = min(low.z, corner.z); high.z = max(high.z, corner.z)
                }
                return (low, high)
            }
            guard let (firstLow, firstHigh) = bounds(firstCorners),
                  let (secondLow, secondHigh) = bounds(secondCorners) else { return }
            func gap(_ aMin: Float, _ aMax: Float, _ bMin: Float, _ bMax: Float) -> Float {
                max(0, max(aMin - bMax, bMin - aMax))
            }
            let dx = gap(firstLow.x, firstHigh.x, secondLow.x, secondHigh.x)
            let dy = gap(firstLow.y, firstHigh.y, secondLow.y, secondHigh.y)
            let dz = gap(firstLow.z, firstHigh.z, secondLow.z, secondHigh.z)
            let separationSquared = dx * dx + dy * dy + dz * dz
            let (aMin, aMax) = first.boundingBox
            let (bMin, bMax) = node.boundingBox
            let adx = aMax.x - aMin.x, ady = aMax.y - aMin.y, adz = aMax.z - aMin.z
            let bdx = bMax.x - bMin.x, bdy = bMax.y - bMin.y, bdz = bMax.z - bMin.z
            let aSize = sqrt(adx * adx + ady * ady + adz * adz)
            let bSize = sqrt(bdx * bdx + bdy * bdy + bdz * bdz)
            // Account for imported model scale: local-space dimensions
            // alone can reject valid joints between scaled parts.
            let aScale = first.presentation.worldTransform
            let bScale = node.presentation.worldTransform
            func worldScale(_ t: SCNMatrix4) -> Float {
                let sx = sqrt(t.m11 * t.m11 + t.m12 * t.m12 + t.m13 * t.m13)
                let sy = sqrt(t.m21 * t.m21 + t.m22 * t.m22 + t.m23 * t.m23)
                let sz = sqrt(t.m31 * t.m31 + t.m32 * t.m32 + t.m33 * t.m33)
                return max(sx, max(sy, sz))
            }
            let maxSeparation = max(0.1, 2 * max(aSize * worldScale(aScale),
                                                  bSize * worldScale(bScale)))
            guard separationSquared.isFinite, maxSeparation.isFinite,
                  separationSquared <= maxSeparation * maxSeparation else { return }
            let axis = SCNVector3(0, 0, 1)
            // Hinge anchors must be expressed in the rigid body's local
            // coordinate system, not in a clicked child mesh's coordinates.
            // A multi-mesh original object has its body on the tmo owner.
            let anchorA = firstPhysical.presentation.convertPosition(anchor, from: nil)
            let anchorB = secondPhysical.presentation.convertPosition(anchor, from: nil)
            func unit(_ vector: SCNVector3) -> SCNVector3 {
                let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
                guard length.isFinite, length > 0.00001 else { return SCNVector3(0, 0, 1) }
                return SCNVector3(vector.x / length, vector.y / length, vector.z / length)
            }
            let axisA = unit(firstPhysical.presentation.convertVector(axis, from: nil))
            let axisB = unit(secondPhysical.presentation.convertVector(axis, from: nil))
            let values = [anchorA.x, anchorA.y, anchorA.z,
                          anchorB.x, anchorB.y, anchorB.z,
                          axisA.x, axisA.y, axisA.z,
                          axisB.x, axisB.y, axisB.z]
            guard values.allSatisfy({ $0.isFinite }) else { return }
            // The joint must not connect an object to itself, even if
            // hit-testing returns distinct mesh nodes sharing one body.
            guard firstBody !== body else { return }
            // Avoid stacking duplicate constraints on the same two bodies:
            // repeated double taps should not over-constrain the solver.
            let alreadyConnected = manualHinges.contains { existing in
                let a = existing.joint.bodyA
                let b = existing.joint.bodyB
                return (a === firstBody && b === body) || (a === body && b === firstBody)
            }
            guard !alreadyConnected else { return }
            // Pause integration while installing a constraint between moving
            // bodies, then restore the prior playback state. This prevents
            // the solver from observing a half-configured joint.
            let wasPlaying = view.isPlaying
            view.isPlaying = false
            let hinge = SCNPhysicsHingeJoint(bodyA: firstBody, axisA: axisA,
                                             anchorA: anchorA, bodyB: body,
                                             axisB: axisB, anchorB: anchorB)
            scene.physicsWorld.addBehavior(hinge)
            clearPendingHingeEndpoint()
            view.isPlaying = wasPlaying
            let marker = SCNNode(geometry: SCNSphere(radius: 0.08))
            marker.name = "manual-hinge-anchor"
            marker.geometry?.firstMaterial?.diffuse.contents = UIColor.systemGreen
            // The diagnostic marker is visual only. Parent it to the first
            // rigid body so it follows a moving hinge instead of remaining
            // frozen at its creation-time world coordinate.
            marker.position = firstPhysical.convertPosition(anchor, from: nil)
            firstPhysical.addChildNode(marker)
            manualHinges.append((joint: hinge, marker: marker))
        }

        /// Common real UCM lever presentation for both direct player taps
        /// and physically observed impacts. Do not mutate the session here:
        /// the source-of-truth switch state was already changed once.
        // Called only from a running renderer frame under sessionLock.
        // Presentation transforms describe actual interpolated lever motion.
        // A request to turn on is not itself a closed electrical contact.
        private func sampleOriginalSwitchConduction() {
            let observed = Set(switchLeverNodes.compactMap { id, lever -> String? in
                guard let rest = switchLeverRestAngles[id],
                      lever.parent != nil,
                      CMOriginalWindowsSwitchContactGate.sceneContactClosed(
                        authoredOpenAngle: rest.x,
                        observedAngle: lever.presentation.eulerAngles.x)
                else { return nil }
                return id
            })
            // Native impact sets motion -10 at 0x4441DE, then the
            // 0x450820..0x45086E terminal branch dispatches owner GOAL.
            // The iOS observed angle is an explicitly reconstructed adapter.
            for id in switchLeverNodes.keys.sorted() {
                if switchImpactGoal.observe(id,
                    requestedOn: session?.originalSwitchStates[id] == true,
                    observedClosed: observed.contains(id)) {
                    let deliver = onOriginalSwitchImpactGoal
                    DispatchQueue.main.async { deliver?(id) }
                }
            }
            let changed = observed.symmetricDifference(conductingSwitchIDs)
            conductingSwitchIDs = observed
            for id in changed.sorted() {
                let closed = observed.contains(id)
                let deliver = onOriginalSwitchToggle
                DispatchQueue.main.async { deliver?(id, closed) }
            }
        }

        private func animateOriginalSwitchLever(
            _ switchID: String, isOn: Bool
        ) {
            guard let lever = switchLeverNodes[switchID],
                  let original = switchLeverRestAngles[switchID]
            else { return }
            // The imported lever has a genuine PC rest ROT x=1.
            // The -0.6 alternate angle is a SceneKit approximation,
            // not a claim of measured native +0xEC contact position.
            lever.removeAction(forKey: "original-switch")
            lever.runAction(
                SCNAction.rotateTo(
                    x: CGFloat(original.x + (isOn ? CMOriginalWindowsSwitchContactGate.sceneClosedOffset : 0)),
                    y: CGFloat(original.y), z: CGFloat(original.z),
                    duration: 0.16, usesShortestUnitArc: true
                ),
                forKey: "original-switch"
            )
        }

        /// A player tap and a collision share the same UCM lever output,
        /// but only explicit original CML identities may operate it.
        private func flipOriginalPowerSwitch(_ hitNode: SCNNode?) -> Bool {
            guard let objectID = owningOriginalObjectID(for: hitNode) else {
                return false
            }
            let switchID: String
            if originalTypesByID[objectID] == "tmo_power_switch" {
                switchID = objectID
            } else if originalTypesByID[objectID] == "tmo_power_switch_lever" {
                // Resolve the real switch through zero or more original
                // mounting ancestors, not only a direct CML parent.
                sessionLock.lock()
                let owner = switchContacts?
                    .originalSwitchID(forLeverID: objectID)
                sessionLock.unlock()
                guard let owner else { return false }
                switchID = owner
            } else {
                return false
            }
            guard switchLeverNodes[switchID] != nil,
                  switchLeverRestAngles[switchID] != nil else { return false }
            // The session is the source of truth for genuine switch
            // positions. Reject taps while paused, rather than visually
            // flipping a lever when the simulation cannot accept the input.
            sessionLock.lock()
            let nextState = session?.toggleOriginalSwitch(switchID)
            if nextState != nil { switchImpactGoal.cancel(switchID) }
            sessionLock.unlock()
            guard let isOn = nextState else { return false }
            animateOriginalSwitchLever(switchID, isOn: isOn)
            return true
        }

        /// Win32 0x434A9A checks the exact tmo_light_pocketlamp type,
        /// toggles its physical +0xEC value 0<->1 (0x434ACA..0x434AE6),
        /// then separately compares native +0xF0 before dispatching
        /// a GOAL. This ports SOURCE STATE ONLY, not the unknown native
        /// +0xF0 latch or a fabricated beam/solar GOAL event.
        private func flipOriginalPocketLamp(_ node: SCNNode?) -> Bool {
            guard let id = owningOriginalObjectID(for: node) else {
                return false
            }
            let pocketlampID: String
            if originalTypesByID[id] == "tmo_light_pocketlamp" {
                pocketlampID = id
            } else if originalTypesByID[id] == "tmo_light_pocketlamp_glass",
                      let parent = session?.objects.first(
                          where: { $0.id == id }
                      )?.parentID,
                      originalTypesByID[parent] == "tmo_light_pocketlamp" {
                pocketlampID = parent
            } else { return false }
            sessionLock.lock()
            let next = session?.toggleOriginalPocketLamp(pocketlampID)
            let nativeGoal = session?.nativeClickedSourceGoalSatisfied(pocketlampID)
            sessionLock.unlock()
            guard let on = next else { return false }
            for glow in originalPocketLampGlowNodes[pocketlampID] ?? [] {
                glow.opacity = on ? 1 : 0
            }
            // Win32 0x434AF6..0x434B12 only: physical source state
            // changed from its captured +0xF0 snapshot, with GOAL 1.
            if nativeGoal == true {
                onOriginalPlayerSourceGoal?(pocketlampID)
            }
            return true
        }

        /// The authentic PC click handler toggles real candle or
        /// blowtorch +0xEC from 0 to 1 and back. It then separately
        /// compares +0xEC with +0xF0 before a native GOAL callback.
        /// Visual flames respond, but unknown heat transport and GOAL
        /// conditions remain disabled instead of being fabricated.
        private func flipOriginalHeatSource(_ node: SCNNode?) -> Bool {
            guard let id = owningOriginalObjectID(for: node) else {
                return false
            }
            sessionLock.lock()
            let next = session?.toggleOriginalHeatSource(id)
            let nativeGoal = session?.nativeClickedSourceGoalSatisfied(id)
            sessionLock.unlock()
            guard let isOn = next else { return false }
            for sprite in originalCandleGlowNodes[id] ?? [] {
                sprite.opacity = isOn ? 1 : 0
            }
            // Win32 0x434A50..0x434A76: current +0xEC differs
            // from original run-snapshot +0xF0. Not a generic tap GOAL.
            if nativeGoal == true {
                onOriginalPlayerSourceGoal?(id)
            }
            return true
        }

        @objc func selectObject(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView,
                  gesture.state == .ended, !dragWasActive else { return }
            let point = gesture.location(in: view)
            let hit = originalObjectHit(in: view, at: point)
            let node = hit?.node
            if physicsEnabled {
                // Explicitly configured prototype mechanisms can be started
                // by tapping their imported mesh. Without a configured rule,
                // retain the existing diagnostic tap impulse behavior.
                if let id = (node as? CMOriginalObjectMeshNode)?.originalObjectID {
                    sessionLock.lock()
                    let hasRule = session?.reactionRules.contains(where: { $0.objectID == id }) == true
                    if hasRule { _ = session?.pressObject(id) }
                    sessionLock.unlock()
                    if hasRule { return }
                }
                // Preserve the player's genuine PC switch gesture while
                // keeping the unrecovered electric circuit disconnected.
                if flipOriginalPowerSwitch(node) { return }
                if flipOriginalPocketLamp(node) { return }
                if flipOriginalHeatSource(node) { return }
                // The PC player cannot kick balls by tapping them after
                // starting the machine; allow this only in diagnostic mode.
                guard diagnosticTapImpulses else { return }
                // Apply the experimental impulse at the actual touched surface
                // rather than the center of mass. Off-center taps can now
                // generate torque, allowing rotational collision experiments.
                guard let body = physicalNode(for: node)?.physicsBody, body.type == .dynamic,
                      let camera = view.pointOfView,
                      let contact = hit?.worldCoordinates,
                      contact.x.isFinite, contact.y.isFinite, contact.z.isFinite else { return }
                let forward = camera.presentation.convertVector(SCNVector3(0, 0, -1), to: nil)
                let magnitude: Float = 2
                body.applyForce(SCNVector3(forward.x * magnitude,
                                           forward.y * magnitude,
                                           forward.z * magnitude),
                                at: contact, asImpulse: true)
                return
            }
            if originalBeltEditing {
                if let id = owningOriginalObjectID(for: node), hasOriginalBeltWheel(id) {
                    onOriginalBeltTap?(id)
                }
                highlightOriginalMesh(node, in: view)
                return
            }
            if originalRopeEditing {
                if let id = owningOriginalObjectID(for: node), let hit,
                   let endpoint = originalRopeEndpoint(ownerID: id, at: hit.worldCoordinates) {
                    onOriginalRopeTap?(endpoint)
                }
                highlightOriginalMesh(node, in: view)
                return
            }
            if let id = owningOriginalObjectID(for: node),
               session?.objects.contains(where: {
                   $0.id == id && $0.type == "tmo_power_plug"
               }) == true,
               let callback = onOriginalPowerPlugTap {
                callback(id)
                highlightOriginalMesh(node, in: view)
                return
            }
            highlightOriginalMesh(node, in: view)
        }

        /// Shared tap/drag selection path. One original UCM instance gets
        /// the highlight, while cached geometry used by siblings stays intact.
        private func highlightOriginalMesh(_ node: SCNNode?, in view: SCNView) {
            if let previous = highlighted, let material = previous.geometry?.firstMaterial {
                material.emission.contents = originalEmission
            }
            highlighted = nil
            originalEmission = nil
            selectedModelName = nil
            view.accessibilityValue = "No original model selected"
            guard let node, let geometry = node.geometry,
                  geometry.firstMaterial != nil else { return }
            // Avoid re-copying a selected geometry when the user taps it again.
            // The selection tint must not leak to other instances of a shared UCM.
            // Geometries are shared by repeated original UCM instances.
            // Copy the geometry and material so selecting one does not tint all.
            let unique = geometry.copy() as! SCNGeometry
            unique.materials = geometry.materials.map { $0.copy() as! SCNMaterial }
            node.geometry = unique
            guard let uniqueMaterial = unique.firstMaterial else { return }
            originalEmission = uniqueMaterial.emission.contents
            uniqueMaterial.emission.contents = UIColor.systemOrange
            highlighted = node
            // Make the original mesh identity available to VoiceOver while
            // inspecting an authentic level. This is the imported 3DO name,
            // not an invented gameplay classification.
            selectedModelName = node.name
            let objectID = (node as? CMOriginalObjectMeshNode)?.originalObjectID
            let objectType = session?.objects.first(where: { $0.id == objectID })?.type
            view.accessibilityValue = [
                "Selected original model: " + (node.name ?? "unnamed"),
                objectType.map { "Original object type: " + $0 },
                objectID.map { "Object ID: " + $0 }
            ].compactMap { $0 }.joined(separator: "; ")

        }
    }

    private func buildScene(
        originalPositions: inout [String: SCNVector3],
        originalRotations: inout [String: SCNVector3]
    ) -> SCNScene {
        let scene = SCNScene()
        var loadedMeshNodes: [SCNNode] = []
        // Resolve original file paths per scene, but reuse parsed UCM geometry
        // across neighboring Professor levels via a bounded shared cache.
        let assetIndex = CMOriginalModelResolver.AssetIndex(directory: assetDirectory)
        // Build a single case-insensitive TGA index for this entire scene.
        // Every reused original UCM/wall material sees the same decoded image
        // instead of rescanning 181 files and decompressing each TGA again.
        let textureCache = OriginalTextureCache(directory: assetDirectory)
        var resolvedModels: [String: URL] = [:]
        var missingModels = Set<String>()
        var meshCache: [String: SCNGeometry] = [:]
        // Authored UCM1 attachment tables are parsed once per resolved file;
        // no synthetic heat radius, engine force or GOAL is assigned.
        var namedAnchorCache: [URL: [CMOriginalUCMNamedAnchors.Anchor]] = [:]
        // Avoid reparsing a corrupt UCM every time it is referenced.
        var invalidMeshes = Set<URL>()
        // Physics trials must always begin at the authentic imported positions,
        // not at coordinates previously edited in the 3D inspection mode.
        var nodeOrdinal = 0
        var objectOrdinal = 0

        func parseRotation(_ raw: String?) -> SCNVector3 {
            guard let raw else { return SCNVector3Zero }
            let parts = raw.split(whereSeparator: { $0.isWhitespace || $0 == "," })
            guard parts.count == 4, parts[0].lowercased() == "xyz",
                  let x = Float(parts[1]), let y = Float(parts[2]),
                  let z = Float(parts[3]), x.isFinite, y.isFinite, z.isFinite else {
                return SCNVector3Zero
            }
            return SCNVector3(x, y, z)
        }

        // All 102 original Professor Laboratory scenes use the SCAL field:
        // 710 per-node scale values, including intentional negative scales
        // (mirrored conveyor parts) and nonuniform model/zone dimensions.
        // The previous renderer ignored it, causing incorrect puzzle sizes,
        // collision shapes, and orientation even with the correct PC UCMs.
        // Leave coordinates in the original scene's local coordinate system.
        func parseOriginalScale(_ fields: [String]) -> SCNVector3 {
            guard let field = fields.first(where: { $0.hasPrefix("SCAL ") }) else {
                return SCNVector3(1, 1, 1)
            }
            let values = field.dropFirst(5).split(separator: ",")
                .compactMap { Float($0.trimmingCharacters(in: .whitespaces)) }
            guard values.count == 3,
                  values.allSatisfy({ $0.isFinite && abs($0) <= 1_000 }) else {
                return SCNVector3(1, 1, 1)
            }
            return SCNVector3(values[0], values[1], values[2])
        }

        // Keep each original tmo object's meshes together: a multi-part model
        // must not split into independently falling rigid bodies.
        var objectRoots: [String: SCNNode] = [:]
        var objectTypes: [String: String] = [:]
        var objectMeshes: [String: [CMOriginalObjectMeshNode]] = [:]

        func walk(_ item: CMOriginalSceneDocument.Node, parent: SCNNode, ownerID: String? = nil) {
            var currentOwnerID = ownerID
            if item.name.hasPrefix("tmo_") {
                currentOwnerID = "object-\(objectOrdinal)"
                objectOrdinal += 1
            }
            let transform: SCNNode = item.name.hasPrefix("tmo_")
                ? CMOriginalPhysicsOwnerNode() : SCNNode()
            if let owner = transform as? CMOriginalPhysicsOwnerNode {
                owner.originalObjectID = currentOwnerID
                owner.isUnlockedInOriginalLevel = item.fields.contains("UNLOCKED 1")
            }
            let identifier = "original-node-\(nodeOrdinal)"
            nodeOrdinal += 1
            transform.name = identifier
            if let p = item.positionRelative ?? item.position, p.count == 3 {
                transform.position = SCNVector3(Float(p[0]), Float(p[1]), Float(p[2]))
            }
            transform.eulerAngles = parseRotation(item.rotationRelativeRaw ?? item.rotationRaw)
            transform.scale = parseOriginalScale(item.fields)
            originalPositions[identifier] = transform.position
            originalRotations[identifier] = transform.eulerAngles
            parent.addChildNode(transform)
            if item.name.hasPrefix("tmo_"), let currentOwnerID {
                objectRoots[currentOwnerID] = transform
                objectTypes[currentOwnerID] = item.name
            }

            // A 3DO entry is a model reference, not an additional object transform.
            func attachOriginalModel(_ name: String) {
                // A subset of 3DO references in 48 original PC levels are
                // additive visual effects rather than real UCM meshes.
                // Use ONLY the exact TGA mappings verified against the
                // owner's 181 original textures. Do not add these planes to
                // objectMeshes or loadedMeshNodes: they must never collide,
                // modify camera framing, or count as original UCM geometry.
                if let effect = CMOriginalEffectBillboard.specification(for: name) {
                    guard let image = textureCache.image(named: effect.textureName)
                    else {
                        missingModels.insert(name)
                        return
                    }
                    let plane = SCNPlane(
                        width: CGFloat(effect.width),
                        height: CGFloat(effect.height)
                    )
                    let material = SCNMaterial()
                    material.lightingModel = .constant
                    material.diffuse.contents = image
                    // The PC's source glow images are 24-bit RGB with dark
                    // edges. Additive blending treats those black edges as
                    // transparent instead of drawing opaque black squares.
                    material.blendMode = .add
                    material.isDoubleSided = true
                    material.writesToDepthBuffer = false
                    material.readsFromDepthBuffer = true
                    plane.materials = [material]
                    let billboard = SCNNode(geometry: plane)
                    billboard.name = "original-effect-glow-" + name.lowercased()
                    // SceneKit's initializer is parameterless; configure
                    // the free axes on the constraint after creation.
                    let facing = SCNBillboardConstraint()
                    facing.freeAxes = .all
                    billboard.constraints = [facing]
                    billboard.renderingOrder = 10
                    transform.addChildNode(billboard)
                    return
                }
                // Preserve exact spelling: distinct UCM assets can differ only
                // by case, and the resolver gives exact names precedence.
                let modelKey = name
                let modelURL: URL?
                if let cached = resolvedModels[modelKey] {
                    modelURL = cached
                } else if missingModels.contains(modelKey) {
                    modelURL = nil
                } else {
                    let resolved = assetIndex.resolve(name)
                    if let resolved {
                        resolvedModels[modelKey] = resolved
                    } else {
                        missingModels.insert(modelKey)
                    }
                    modelURL = resolved
                }
                if let url = modelURL {
                    if !invalidMeshes.contains(url) {
                        let geometry: SCNGeometry?
                        // One original UCM shape can have several PC
                        // material variants (e.g. cork and concrete walls).
                        let cacheKey = CMOriginalSharedGeometryCache.key(
                            for: url, modelReference: name)
                        let localKey = cacheKey as String
                        if let cached = meshCache[localKey] {
                            geometry = cached
                        } else if let cached = CMOriginalSharedGeometryCache
                            .geometries.object(forKey: cacheKey) {
                            // A different original level can reuse the exact
                            // UCM vertices, materials and verified TGA image.
                            // No original transforms or physics are shared.
                            meshCache[localKey] = cached
                            geometry = cached
                        } else {
                            geometry = try? Self.loadGeometry(
                                url, textureCache: textureCache,
                                originalModelReference: name
                            )
                            if let geometry {
                                meshCache[localKey] = geometry
                                CMOriginalSharedGeometryCache.geometries.setObject(
                                    geometry, forKey: cacheKey,
                                    cost: CMOriginalSharedGeometryCache.cost(for: url))
                            } else {
                                invalidMeshes.insert(url)
                            }
                        }
                        if let geometry {
                            // Geometry is cached by original UCM filename.
                            // The conveyor's belt texture must NOT share a
                            // mutable material between 57 independent belts:
                            // each conveyor has its own physical roller speed.
                            let rendered: SCNGeometry
                            if ["to_belt_conveyer_belt", "to_power_lamp_bulb"]
                                .contains(name.lowercased()),
                               let copy = geometry.copy() as? SCNGeometry {
                                copy.materials = geometry.materials.map {
                                    ($0.copy() as? SCNMaterial) ?? $0
                                }
                                rendered = copy
                            } else {
                                rendered = geometry
                            }
                            let mesh = CMOriginalObjectMeshNode(geometry: rendered)
                            mesh.name = name
                            // Only the authentic flower is a verified two-frame
                            // UCM morph. Keep the immutable base cached, but
                            // each flower has an independent SceneKit morpher.
                            if name.lowercased() == "to_light_flower",
                               url.deletingPathExtension().lastPathComponent.lowercased() == "light_flower",
                               let target = try? Self.loadGeometry(url, textureCache: textureCache,
                                   originalModelReference: name, flowerGroup: 1),
                               rendered.sources(for: .vertex).first?.vectorCount == target.sources(for: .vertex).first?.vectorCount {
                                let morpher = SCNMorpher()
                                morpher.calculationMode = .normalized
                                morpher.targets = [target]
                                morpher.setWeight(1, forTargetAt: 0)
                                mesh.morpher = morpher
                            }
                            if let currentOwnerID {
                                mesh.originalObjectID = currentOwnerID
                            }
                            // Render the original UCM geometry without adding
                            // synthetic GOAL colors. GOAL is preserved in the
                            // level inspector, not encoded as invented materials.
                            transform.addChildNode(mesh)
                            // Restore genuine original UCM attachment
                            // positions as invisible, non-colliding child
                            // frames. Only group 0 is attached here:
                            // other group transforms need separate mapping.
                            let anchors: [CMOriginalUCMNamedAnchors.Anchor]
                            if let cached = namedAnchorCache[url] {
                                anchors = cached
                            } else {
                                let parsed = (try? Data(
                                    contentsOf: url, options: [.mappedIfSafe]
                                )).flatMap {
                                    try? CMOriginalUCMNamedAnchors.decode($0)
                                } ?? []
                                namedAnchorCache[url] = parsed
                                anchors = parsed
                            }
                            for attachment in anchors where attachment.group == 0 {
                                let frame = SCNNode()
                                // Preserve the raw, case-sensitive original
                                // UCM marker name in the SceneKit node name.
                                // SCNNode has no `userData` on iOS; the
                                // telemetry decoder strictly parses the final
                                // decimal slot instead of guessing from a
                                // lowercased Heat prefix.
                                frame.name = "original-ucm-anchor-" +
                                    attachment.name + "-\(attachment.slot)"
                                // Preserve original full basis AND position.
                                // UCM stores row-major vectors with translation
                                // in its final row; SIMD uses column vectors,
                                // so original rows become SIMD columns.
                                // Engine, Direction and Explode are differently
                                // oriented in the authentic rocket UCM.
                                let a = attachment.matrixRowMajor
                                frame.simdTransform = simd_float4x4(columns: (
                                    SIMD4<Float>(a[0], a[1], a[2], a[3]),
                                    SIMD4<Float>(a[4], a[5], a[6], a[7]),
                                    SIMD4<Float>(a[8], a[9], a[10], a[11]),
                                    SIMD4<Float>(a[12], a[13], a[14], a[15])
                                ))
                                mesh.addChildNode(frame)
                                // The original PC installation includes a
                                // 32x32 rocket_effect.tga. Attach that REAL
                                // texture to its own rocket's authentic UCM
                                // Explode frame (never to a guessed center).
                                // The exact Win32 sprite animation is still
                                // unrecovered; rendering is a visual-only
                                // SceneKit approximation, initially hidden.
                                if attachment.name == "Explode",
                                   url.lastPathComponent.lowercased()
                                     == "heat_rocket_rocket.ucm",
                                   let picture = textureCache.image(
                                     named: "rocket_effect") {
                                    let plane = SCNPlane(
                                        width: 0.55, height: 0.55)
                                    let material = SCNMaterial()
                                    material.lightingModel = .constant
                                    material.diffuse.contents = picture
                                    material.blendMode = .add
                                    material.isDoubleSided = true
                                    material.writesToDepthBuffer = false
                                    plane.materials = [material]
                                    let glow = SCNNode(geometry: plane)
                                    glow.name =
                                        "original-rocket-effect-original-tga"
                                    let facing = SCNBillboardConstraint()
                                    facing.freeAxes = .all
                                    glow.constraints = [facing]
                                    glow.renderingOrder = 12
                                    glow.opacity = 0
                                    frame.addChildNode(glow)
                                }
                            }
                            // Collision bodies are attached to the owning tmo_
                            // transform below, including single-mesh objects.
                            // Keeping them off mesh children prevents a detached
                            // part from moving independently of its object.
                            if let currentOwnerID {
                                objectMeshes[currentOwnerID, default: []].append(mesh)
                            }
                            loadedMeshNodes.append(mesh)
                        }
                    }
                }
            }
            // Some valid exports store 3DO references in the models array
            // without a corresponding explicit child node. Render those too,
            // but do not duplicate references represented by 3DO children.
            if item.name.hasPrefix("3DO ") {
                attachOriginalModel(String(item.name.dropFirst(4)))
            }
            // Exported tmo_ models lists are flattened across helper nodes,
            // while the same 3DO nodes are rendered below with their actual
            // nested PC transforms. Only add model-only fallback references.
            for name in CMOriginalModelResolver.fallbackModelNames(in: item) {
                attachOriginalModel(name)
            }
            for child in item.children {
                walk(child, parent: transform, ownerID: currentOwnerID)
            }
        }
        walk(document.root, parent: scene.rootNode)

        #if DEBUG && targetEnvironment(simulator)
        if document.title == "CM synthetic CI 3D scene" {
            // This test-only background is intentionally different from
            // SCNView's UIKit charcoal fill. If it never appears, SceneKit
            // did not composite any scene frame, irrespective of camera or
            // imported UCM geometry.
            scene.background.contents = UIColor(
                red: 0.12, green: 0.20, blue: 0.55, alpha: 1)
            // An unmistakably CYAN SceneKit-native calibration sphere is
            // deliberately separate from the imported ORANGE UCM triangle.
            // Never use the reference marker to satisfy the UCM rendering
            // assertion: if cyan renders and orange does not, asset/geometry
            // rendering is broken. If neither renders, inspect the camera or
            // Metal viewport. This is only present in the copyright-free CI
            // fixture, never in authentic PC puzzles or release builds.
            let calibration = SCNNode(geometry: SCNSphere(radius: 0.22))
            calibration.name = "cm-ci-render-calibration"
            calibration.position = SCNVector3(1, 0, -0.1)
            let material = SCNMaterial()
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.cyan
            material.emission.contents = UIColor.cyan
            calibration.geometry?.materials = [material]
            scene.rootNode.addChildNode(calibration)
        }
        #endif

        // Reapply user-edited positions to original object owners BEFORE
        // creating collision shapes. The same edited arrangement must be
        // used when switching from placement mode into physics mode.
        // Never alter the original scene document or model files.
        if allowObjectPlacement {
            let key = "cm.original.positions.\(document.sceneSHA256)"
            let saved = UserDefaults.standard.dictionary(forKey: key)
                as? [String: [Double]] ?? [:]
            for (identifier, components) in saved {
                guard identifier.hasPrefix("original-node-"),
                      components.count == 3,
                      components.allSatisfy({ $0.isFinite && abs($0) <= 1_000_000 }),
                      let owner = scene.rootNode.childNode(
                          withName: identifier, recursively: true
                      ) as? CMOriginalPhysicsOwnerNode else { continue }
                owner.position = SCNVector3(
                    Float(components[0]), Float(components[1]), Float(components[2])
                )
            }
            // Angles saved in the editor are applied before any SceneKit
            // collision bodies are created. Only original tmo_ owners can
            // be rotated; the authored CML/JSON and UCM never change.
            let rotationKey = "cm.original.rotations.\(document.sceneSHA256)"
            let savedRotations = UserDefaults.standard.dictionary(forKey: rotationKey)
                as? [String: [Double]] ?? [:]
            for (identifier, angles) in savedRotations {
                guard identifier.hasPrefix("original-node-"),
                      angles.count == 3,
                      angles.allSatisfy({ $0.isFinite && abs($0) <= 100_000 }),
                      let owner = scene.rootNode.childNode(
                          withName: identifier, recursively: true
                      ) as? CMOriginalPhysicsOwnerNode else { continue }
                owner.eulerAngles = SCNVector3(
                    Float(angles[0]), Float(angles[1]), Float(angles[2])
                )
            }
        }
        if experimentalPhysics {
            // Build one owner-level convex collision body per original object.
            // Each mesh shape is transformed into its owning tmo node's space;
            // nested tmo objects are kept separate by their distinct owner IDs.
            for (id, meshes) in objectMeshes where !meshes.isEmpty {
                guard let root = objectRoots[id],
                      let kind = objectTypes[id] else { continue }
                // The user's authentic CML levels contain 102 decorative
                // backgrounds and 144 guidance arrows. They are drawn by
                // the original game but are not puzzle collision obstacles.
                // Do not manufacture invisible physics walls around them.
                // Preserve tmo_zone: it is an original contact sensor.
                if kind.hasPrefix("tmo_background_") || kind == "tmo_arrow" {
                    continue
                }
                // Original levels consistently embed these mounting fixtures
                // as child tmo_ nodes of boards, motors and other mechanisms,
                // never as independent puzzle objects. The previous solver
                // created separate static collision bodies for every mount,
                // including 12 mounts in level 1, leading to spurious impacts
                // and blocking the balls. Render their authentic UCM models
                // but omit these support-only bodies from SceneKit collisions.
                if kind == "tmo_mount_bar"
                    || kind == "tmo_mount_wood"
                    || kind == "tmo_mount_shear" {
                    continue
                }
                // The real PC bucket is hollow. Its visual UCM extends
                // above the rim into a handle, and a full convex hull seals
                // the opening. That prevented level 4's original tennis
                // ball from ever entering the GOAL-marked bucket.
                //
                // Preserve the original to_bucket UCM for rendering and use
                // three local collision panels for the floor and side walls.
                // Omit to_dummy_bounding from bucket collision; it is an
                // original helper triangle and not a solid obstacle.
                var shapes: [SCNPhysicsShape] = []
                var transforms: [NSValue] = []
                if kind == "tmo_bucket",
                   let bucketMesh = meshes.first(where: {
                       $0.name?.lowercased() == "to_bucket"
                   }) {
                    let (low, high) = bucketMesh.boundingBox
                    if let panels = CMOriginalBucketCollisionProxy.panels(
                        low: [low.x, low.y, low.z],
                        high: [high.x, high.y, high.z]
                    ) {
                        let base = bucketMesh.convertTransform(
                            SCNMatrix4Identity, to: root
                        )
                        for panel in panels {
                            let bounds = SCNBox(
                                width: CGFloat(panel.size[0]),
                                height: CGFloat(panel.size[1]),
                                length: CGFloat(panel.size[2]),
                                chamferRadius: 0
                            )
                            shapes.append(SCNPhysicsShape(
                                geometry: bounds,
                                options: [.type: SCNPhysicsShape.ShapeType.boundingBox]
                            ))
                            let offset = SCNMatrix4MakeTranslation(
                                panel.center[0], panel.center[1], panel.center[2]
                            )
                            transforms.append(NSValue(scnMatrix4:
                                SCNMatrix4Mult(base, offset)
                            ))
                        }
                    }
                }
                // The genuine tmo_rope_cage is a tapered OPEN cup with
                // a decorative handle. A single convex hull makes a roof,
                // physically preventing the imported ball from reaching
                // its native 0.1-radius Test/Catch target. Reconstruct only
                // the lower floor and two slanted sides from original
                // rope_cage.UCM vertex bounds. This remains a provisional
                // collision adapter, not the recovered Windows physics mesh.
                if shapes.isEmpty, kind == "tmo_rope_cage",
                   let cageMesh = meshes.first(where: {
                       $0.name?.lowercased() == "to_rope_cage"
                   }) {
                    let (low, high) = cageMesh.boundingBox
                    if let panels = CMOriginalCageCollisionProxy.panels(
                        low: [low.x, low.y, low.z],
                        high: [high.x, high.y, high.z]
                    ) {
                        let base = cageMesh.convertTransform(
                            SCNMatrix4Identity, to: root
                        )
                        for panel in panels {
                            let geometry = SCNBox(
                                width: CGFloat(panel.size[0]),
                                height: CGFloat(panel.size[1]),
                                length: CGFloat(panel.size[2]),
                                chamferRadius: 0
                            )
                            shapes.append(SCNPhysicsShape(
                                geometry: geometry,
                                options: [.type: SCNPhysicsShape.ShapeType.boundingBox]
                            ))
                            let offset = SCNMatrix4MakeTranslation(
                                panel.center[0], panel.center[1],
                                panel.center[2]
                            )
                            let tilt = SCNMatrix4MakeRotation(
                                panel.rotationZ, 0, 0, 1
                            )
                            transforms.append(NSValue(scnMatrix4:
                                SCNMatrix4Mult(
                                    SCNMatrix4Mult(base, offset), tilt
                                )
                            ))
                        }
                    }
                }
                if shapes.isEmpty {
                    var proxyCenters: [SCNVector3] = []
                    shapes = meshes.compactMap { mesh in
                    guard let geometry = mesh.geometry else { return nil }
                    let (low, high) = mesh.boundingBox
                    let minimum = [low.x, low.y, low.z]
                    let maximum = [high.x, high.y, high.z]
                    if kind.hasPrefix("tmo_ball_"),
                       let proxy = CMOriginalCollisionProxy.ball(
                           low: minimum, high: maximum) {
                        // Approximate round PC UCMs with smooth spheres.
                        // The original geometry remains visible; the proxy's
                        // center is applied to its collision transform below.
                        proxyCenters.append(SCNVector3(
                            proxy.center[0], proxy.center[1], proxy.center[2]))
                        return SCNPhysicsShape(
                            geometry: SCNSphere(radius: CGFloat(proxy.radius)),
                            options: [.type: SCNPhysicsShape.ShapeType.convexHull]
                        )
                    }
                    if kind == "tmo_zone",
                       let proxy = CMOriginalCollisionProxy.zone(
                           low: minimum, high: maximum) {
                        // The authentic zero-thickness XY capture plane needs
                        // an invisible contact sensor with modest Z depth.
                        // Translate that box to the original UCM bounds center;
                        // centering it at the 3DO pivot can miss the real zone.
                        proxyCenters.append(SCNVector3(
                            proxy.center[0], proxy.center[1], proxy.center[2]))
                        return SCNPhysicsShape(
                            geometry: SCNBox(
                                width: CGFloat(proxy.width),
                                height: CGFloat(proxy.height),
                                length: CGFloat(proxy.depth),
                                chamferRadius: 0
                            ),
                            options: [.type: SCNPhysicsShape.ShapeType.boundingBox]
                        )
                    }
                    // A true UCM convex hull already contains vertex offsets.
                    // Applying an extra center translation would move it twice.
                    proxyCenters.append(SCNVector3Zero)
                    return SCNPhysicsShape(geometry: geometry, options: [
                        .type: SCNPhysicsShape.ShapeType.convexHull
                    ])
                }
                    guard shapes.count == meshes.count,
                          proxyCenters.count == meshes.count else { continue }
                    transforms = zip(meshes, proxyCenters).map { mesh, center in
                        // SCNSphere and SCNBox are centered at their origin.
                        // Apply the local mesh-bounds midpoint BEFORE the
                        // original nested 3DO transform.
                        let meshTransform = mesh.convertTransform(
                            SCNMatrix4Identity, to: root)
                        let centered = SCNMatrix4Mult(meshTransform,
                            SCNMatrix4MakeTranslation(center.x, center.y, center.z))
                        return NSValue(scnMatrix4: centered)
                    }
                }
                let shape = SCNPhysicsShape(shapes: shapes, transforms: transforms)
                let body = SCNPhysicsBody(type: .dynamic, shape: shape)
                // Original puzzle coordinates lie on the XY gameplay plane;
                // their 3D meshes are visual depth, not a license to drift
                // sideways along Z or tumble around X/Y. Constrain the
                // experimental SceneKit solver to 2.5D, like the PC layout.
                // Keep authored Z positions and Z-axis rotations intact.
                body.velocityFactor = SCNVector3(1, 1, 0)
                body.angularVelocityFactor = SCNVector3(0, 0, 1)
                body.mass = 1
                // Original steel gear teeth transmit tangential motion,
                // rather than behaving like low-friction sliding discs.
                // SceneKit friction remains approximate PC physics.
                body.friction = kind == "tmo_belt_gear" ? 0.92 : 0.6
                body.angularDamping = kind == "tmo_belt_gear" ? 0.07 : 0.1
                body.restitution = 0.15
                body.continuousCollisionDetectionThreshold = 0.001
                // The original parent housing is a visual and physical
                // fixture. Its nested roller or motor rotor must not collide
                // against that same fixture: exclude housing from the axle's
                // collision mask, but preserve ball-to-conveyor contact.
                let layer = CMOriginalPhysicsLayers.category(for: kind)
                body.categoryBitMask = layer
                body.collisionBitMask = CMOriginalPhysicsLayers.collisionMask(
                    for: layer)
                body.contactTestBitMask = CMOriginalPhysicsLayers.contactMask(
                    for: layer)
                root.physicsBody = body
            }

            // Original levels 31, 58, 70, 72, 83, 88, 93, 94 contain
            // exactly two scissors blades under a common fixed owner, both
            // authored at POSREL 0,0,0. Give them the shared physical pin
            // so actual contacts change their relative angle instead of
            // allowing unrelated translation of the two imported bodies.
            for (ownerID, kind) in objectTypes where kind == "tmo_rope_scissors" {
                guard let owner = objectRoots[ownerID] else { continue }
                let blades = owner.childNodes.compactMap { child -> CMOriginalPhysicsOwnerNode? in
                    child as? CMOriginalPhysicsOwnerNode
                }
                let first = blades.filter { node in
                    guard let id = node.originalObjectID else { return false }
                    return objectTypes[id] == "tmo_rope_scissors_1"
                }
                let second = blades.filter { node in
                    guard let id = node.originalObjectID else { return false }
                    return objectTypes[id] == "tmo_rope_scissors_2"
                }
                guard first.count == 1, second.count == 1,
                      let a = first[0].physicsBody, let b = second[0].physicsBody
                else { continue }
                for body in [a, b] {
                    body.isAffectedByGravity = false
                    scene.physicsWorld.addBehavior(SCNPhysicsHingeJoint(
                        body: body, axis: SCNVector3(0, 0, 1),
                        anchor: SCNVector3Zero))
                }
            }

            // Recover the original seesaw's central pin. In PC level data,
            // tmo_rope_seesaw_lever is a child of tmo_rope_seesaw and its
            // POSREL is exactly (0, 0, 0). The authentic rope_seesaw.ucm
            // geometry is centered around this pivot. The previous code
            // froze the beam, so balls could never tip it.
            //
            // The single-body SceneKit hinge pins a body to world space.
            // Its axis and anchor are LOCAL to the lever's own node, not
            // camera-space or world-space coordinates. The parent retains
            // the original authored world position, even if an UNLOCKED
            // seesaw was rearranged before starting the experiment.
            for (id, kind) in objectTypes
                where kind == "tmo_rope_seesaw_lever"
                    || kind == "tmo_pipe_ventil_lever"
                    || kind == "tmo_wind_bellows_lever"
                    || CMOriginalAxleParts.rotatingKinds.contains(kind) {
                guard let wheel = objectRoots[id],
                      let body = wheel.physicsBody else { continue }
                if kind == "tmo_rope_seesaw_lever" || kind == "tmo_pipe_ventil_lever" || kind == "tmo_wind_bellows_lever" {
                    // Only attach levers which really belong to the PC's
                    // fixed seesaw support, not an unrelated 3DO helper.
                    guard let base = wheel.parent as? CMOriginalPhysicsOwnerNode,
                          base.originalObjectID != nil else { continue }
                }
                // Verified authentic PC UCMs place these rotor pivots
                // within a few thousandths of their XY origin. Use the
                // original per-object POS/POSREL, not a manufactured pivot:
                // gear teeth, conveyor rollers and generator rotors remain
                // centered on their original axle while collisions can
                // transfer angular motion.
                //
                // This is PASSIVE rotation, not simulated electric power:
                // original motor activation and belt drive ratios still
                // require reconstruction.
                let pin = SCNPhysicsHingeJoint(
                    body: body,
                    axis: SCNVector3(0, 0, 1),
                    anchor: SCNVector3Zero
                )
                scene.physicsWorld.addBehavior(pin)
            }
        }
        // Frame actual transformed mesh bounds, not just object origins.
        // A long board can extend far beyond its POS coordinate.
        let camera = SCNNode()
        camera.name = "original-level-camera"
        camera.camera = SCNCamera()
        camera.camera?.zNear = 0.01
        camera.camera?.zFar = 10000
        var lower = SCNVector3(Float.greatestFiniteMagnitude,
                               Float.greatestFiniteMagnitude,
                               Float.greatestFiniteMagnitude)
        var upper = SCNVector3(-Float.greatestFiniteMagnitude,
                               -Float.greatestFiniteMagnitude,
                               -Float.greatestFiniteMagnitude)
        var hasBounds = false
        // Frame the *interactive puzzle*, not the much larger original
        // background wall, arrows or tiny nested mounting ornaments.
        // On a portrait iPhone the wide PC background otherwise forces
        // the balls and draggable boards into a very small central region.
        // These original UCMs are still rendered in their exact positions;
        // only their decorative bounds are ignored for camera fitting.
        let interactiveMeshes = loadedMeshNodes.filter { mesh in
            guard let id = (mesh as? CMOriginalObjectMeshNode)?.originalObjectID,
                  let kind = objectTypes[id] else { return true }
            return !kind.hasPrefix("tmo_background_")
                && kind != "tmo_arrow"
                && !kind.hasPrefix("tmo_mount_")
        }
        let framingMeshes = interactiveMeshes.isEmpty
            ? loadedMeshNodes : interactiveMeshes
        for mesh in framingMeshes {
            let (minLocal, maxLocal) = mesh.boundingBox
            for x in [minLocal.x, maxLocal.x] {
                for y in [minLocal.y, maxLocal.y] {
                    for z in [minLocal.z, maxLocal.z] {
                        let world = mesh.convertPosition(SCNVector3(x, y, z), to: nil)
                        guard world.x.isFinite, world.y.isFinite, world.z.isFinite else { continue }
                        lower.x = min(lower.x, world.x)
                        lower.y = min(lower.y, world.y)
                        lower.z = min(lower.z, world.z)
                        upper.x = max(upper.x, world.x)
                        upper.y = max(upper.y, world.y)
                        upper.z = max(upper.z, world.z)
                        hasBounds = true
                    }
                }
            }
        }
        // Geometry supplies surface corners, while a compound body's physics
        // owner can be an ancestor rather than the visible mesh itself.
        let hingeCandidates: [(mesh: SCNNode, bodyNode: SCNNode)] = loadedMeshNodes.compactMap { mesh in
            var current: SCNNode? = mesh
            while let node = current {
                if node.physicsBody != nil { return (mesh: mesh, bodyNode: node) }
                current = node.parent
            }
            return nil
        }
        if experimentalPhysics && diagnosticHinges && hingeCandidates.count >= 2 {
            // Experimental only: find the nearest bounding-box corners
            // across all imported meshes, not just the nearest origins.
            // Offset mesh pivots can otherwise select unrelated parts.
            func corners(_ mesh: SCNNode) -> [SCNVector3] {
                let (low, high) = mesh.boundingBox
                return [low.x, high.x].flatMap { x in
                    [low.y, high.y].flatMap { y in
                        [low.z, high.z].map { z in
                            mesh.convertPosition(SCNVector3(x, y, z), to: nil)
                        }
                    }
                }
            }
            let allCorners = hingeCandidates.map { corners($0.mesh) }
            // No pair exists when every visible mesh belongs to the same
            // compound body. Keep that state explicit instead of falling
            // back to an invalid (0, 1) pair.
            var closestPair: (Int, Int)?
            var closestA = SCNVector3Zero
            var closestB = SCNVector3Zero
            var bestDistanceSquared = Float.infinity
            for i in 0..<(allCorners.count - 1) {
                for j in (i + 1)..<allCorners.count {
                    // Never hinge two visible meshes of the same rigid body.
                    if hingeCandidates[i].bodyNode === hingeCandidates[j].bodyNode { continue }
                    for a in allCorners[i] {
                        for b in allCorners[j] {
                            let dx = a.x - b.x
                            let dy = a.y - b.y
                            let dz = a.z - b.z
                            let distanceSquared = dx * dx + dy * dy + dz * dz
                            if distanceSquared.isFinite && distanceSquared < bestDistanceSquared {
                                bestDistanceSquared = distanceSquared
                                closestPair = (i, j)
                                closestA = a
                                closestB = b
                            }
                        }
                    }
                }
            }
            if let closestPair {
            let first = hingeCandidates[closestPair.0].bodyNode
            let second = hingeCandidates[closestPair.1].bodyNode
            let firstCorners = allCorners[closestPair.0]
            let secondCorners = allCorners[closestPair.1]
            let anchor = SCNVector3((closestA.x + closestB.x) / 2,
                                    (closestA.y + closestB.y) / 2,
                                    (closestA.z + closestB.z) / 2)
            // Avoid feeding non-finite positions into SceneKit physics.
            // Invalid imported geometry must not destabilize the simulation.
            let anchorIsFinite = anchor.x.isFinite && anchor.y.isFinite && anchor.z.isFinite
            // Do not pull unrelated, widely separated meshes together.
            // Use world-space corner spans so parent transforms and mesh
            // scaling are accounted for when judging proximity.
            func cornerSpan(_ points: [SCNVector3]) -> Float {
                guard let first = points.first else { return 0 }
                var minX = first.x, maxX = first.x
                var minY = first.y, maxY = first.y
                var minZ = first.z, maxZ = first.z
                for point in points {
                    minX = min(minX, point.x); maxX = max(maxX, point.x)
                    minY = min(minY, point.y); maxY = max(maxY, point.y)
                    minZ = min(minZ, point.z); maxZ = max(maxZ, point.z)
                }
                let dx = maxX - minX, dy = maxY - minY, dz = maxZ - minZ
                return sqrt(dx * dx + dy * dy + dz * dz)
            }
            let maxGap = max(0.01, 0.25 * max(cornerSpan(firstCorners), cornerSpan(secondCorners)))
            let closeEnough = bestDistanceSquared.isFinite && maxGap.isFinite
                && bestDistanceSquared <= maxGap * maxGap
            if anchorIsFinite && closeEnough {
                // SceneKit expects each axis and anchor in the corresponding
                // body's local coordinate space.
                let worldAxis = SCNVector3(0, 0, 1)
                func normalizedAxis(_ axis: SCNVector3) -> SCNVector3 {
                    let length = sqrt(axis.x * axis.x + axis.y * axis.y + axis.z * axis.z)
                    guard length.isFinite, length > 0.00001 else {
                        return SCNVector3(0, 0, 1)
                    }
                    return SCNVector3(axis.x / length, axis.y / length, axis.z / length)
                }
                let firstAxis = normalizedAxis(first.convertVector(worldAxis, from: nil))
                let secondAxis = normalizedAxis(second.convertVector(worldAxis, from: nil))
                let firstAnchor = first.convertPosition(anchor, from: nil)
                let secondAnchor = second.convertPosition(anchor, from: nil)
                let coordinates = [firstAnchor.x, firstAnchor.y, firstAnchor.z,
                                   secondAnchor.x, secondAnchor.y, secondAnchor.z]
                if coordinates.allSatisfy({ $0.isFinite }) {
                    let hinge = SCNPhysicsHingeJoint(bodyA: first.physicsBody!,
                                                     axisA: firstAxis,
                                                     anchorA: firstAnchor,
                                                     bodyB: second.physicsBody!,
                                                     axisB: secondAxis,
                                                     anchorB: secondAnchor)
                    scene.physicsWorld.addBehavior(hinge)
                    // Only show a pivot marker when a valid hinge was added.
                    let marker = SCNNode(geometry: SCNSphere(radius: 0.08))
                    marker.name = "experimental-hinge-anchor"
                    marker.geometry?.firstMaterial?.diffuse.contents = UIColor.systemYellow
                    marker.position = anchor
                    scene.rootNode.addChildNode(marker)
                }
            }
            } // A valid pair of distinct rigid bodies was found.
        }
        if hasBounds && experimentalPhysics {
            // A temporary diagnostic support surface keeps imported parts
            // from falling forever. It is NOT an original game component.
            // Position its top below the lowest imported mesh vertex.
            let extentX = max(upper.x - lower.x, 1)
            let extentZ = max(upper.z - lower.z, 1)
            let thickness = max(min(max(extentX, extentZ) * 0.02, 1), 0.01)
            let floor = SCNNode(geometry: SCNBox(width: CGFloat(extentX * 1.5),
                                                 height: CGFloat(thickness),
                                                 length: CGFloat(extentZ * 1.5),
                                                 chamferRadius: 0))
            floor.name = "experimental-support-floor"
            floor.position = SCNVector3((lower.x + upper.x) / 2,
                                        lower.y - thickness / 2 - 0.001,
                                        (lower.z + upper.z) / 2)
            // Collision safety net only: the original PC game did not
            // render this slab. Keep its physics for falling pieces, but do
            // not paint a fake platform over the original puzzle artwork.
            floor.geometry?.firstMaterial?.transparency = 0
            floor.geometry?.firstMaterial?.writesToDepthBuffer = false
            floor.physicsBody = SCNPhysicsBody.static()
            scene.rootNode.addChildNode(floor)
        }
        // This invisible transform defines the puzzle plane for accurate
        // two-finger camera panning at any original UCM geometry scale.
        let framingTarget = SCNNode()
        framingTarget.name = "original-level-framing-target"
        if hasBounds {
            let center = SCNVector3((lower.x + upper.x) / 2,
                                    (lower.y + upper.y) / 2,
                                    (lower.z + upper.z) / 2)
            framingTarget.position = center
            let span = max(upper.x - lower.x, upper.y - lower.y,
                           upper.z - lower.z, 0.1)
            // Adapt clipping planes to the actual scene size. A fixed far
            // plane clips large imported mechanisms, while an excessively
            // small near plane reduces depth-buffer precision.
            let distance = span * 2.5
            camera.camera?.zNear = max(0.001, Double(span) * 0.001)
            camera.camera?.zFar = max(10, Double(distance + span * 3))
            // Verified from the user's original PC UCM geometry:
            // wall.ucm lies at z=+0.6 and its visible normals face -Z,
            // while balls/boards are around z=0. Placing the camera at +Z
            // puts the background IN FRONT and occludes authentic puzzles.
            camera.position = SCNVector3(center.x, center.y, center.z - distance)
            // A camera looks down local -Z. From the original puzzle's
            // negative-Z side it must look toward world +Z. Because the
            // target lies EXACTLY behind the default direction, look(at:)
            // encounters an antiparallel (180 degree) case with an
            // underdetermined rotation axis. Fix an explicit yaw instead:
            // +Y stays up and the entire authentic XY puzzle stays ahead.
            camera.eulerAngles = SCNVector3(0, Float.pi, 0)
        } else {
            camera.position = SCNVector3(0, 0, -10)
            camera.eulerAngles = SCNVector3(0, Float.pi, 0)
        }
        scene.rootNode.addChildNode(framingTarget)
        scene.rootNode.addChildNode(camera)
        return scene
    }

    /// Texture names below are verified against the extracted PC model/texture audit.
/// Do not guess a texture for meshes whose original material remains unknown.
    private static let verifiedTextures: [String: String] = [
        "pipe_straight": "pipe_straight", "arrow": "arrow",
        "ball_basket": "ball_basket", "ball_beach": "ball_beach",
        "ball_steel": "env_chrom", "ball_tt": "ball_tt",
        "belt_gear": "belt_gear", "board": "board",
        // Original PC asset basenames use "conveyer" while mesh filenames
        // use "conveyor". These two RGB TGA files were verified directly
        // inside the user's recovered game pack (512x64 belt, 256x256 wheel).
        "belt_conveyor_belt": "belt_conveyer_belt",
        "belt_conveyor_wheel": "belt_conveyer",
        "belt_conveyor_roll1": "belt_conveyer",
        "belt_conveyor_roll2": "belt_conveyer",
        "boiler": "boiler", "bucket": "bucket",
        "crate": "crate", "domino": "domino",
        "element_bars_plank": "element_bars_pult",
        "element_bars_pult": "element_bars_pult",
        "hammer_body": "hammer", "heat_dynamite": "heat_dynamite",
        "h_iron": "h_iron", "magnetic_permanent": "magnetic_permanent",
        // These original support pieces occur 14 times in Professor level 1.
        // Their on-disk UCM and TGA basenames match exactly; use the
        // recovered PC texture instead of the fallback gray material.
        "mount_bar": "mount_bar", "mount_wood": "mount_wood",
        "mount_shear": "mount_shear",
        "power_lamp_base": "power_lamp",
        "power_motor_rotor": "power_motor",
        "power_plug": "power_plug", "power_solarcell": "power_solarcell",
        "power_switch_base": "power_switch",
        "power_switch_lever": "power_switch",
        "spring": "spring", "steam_body": "steam_body",
        "steam_piston": "steam_body", "steam_pleul": "steam_body",
        "steam_wheel": "steam_body", "switch_toggle": "switch_toggle",
        "trunk": "trunk", "weight": "weight",
        "wind_bellows": "wind_bellows",
        "windmill_base": "windmill", "windmill_wings": "windmill"
    ]

    /// Per-scene original TGA index and lazy decode cache. Each unique
    /// asset is opened at most once per scene even when many original UCMs
    /// share it, and exact-on-disk casing is respected on iOS.
    private final class OriginalTextureCache {
        private var imageFiles: [String: [URL]] = [:]
        private var decoded: [String: CGImage] = [:]
        private var unavailable = Set<String>()

        init(directory: URL) {
            let files = (try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            for file in files where file.pathExtension.lowercased() == "tga" {
                guard (try? file.resourceValues(
                    forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
                let key = file.deletingPathExtension().lastPathComponent.lowercased()
                imageFiles[key, default: []].append(file)
            }
        }

        func image(named name: String) -> CGImage? {
            let key = name.lowercased()
            if let cached = decoded[key] { return cached }
            if unavailable.contains(key) { return nil }
            // Duplicate case-insensitive original names cannot be resolved
            // unambiguously; do NOT choose an arbitrary game texture.
            guard let matches = imageFiles[key], matches.count == 1,
                  let bytes = try? Data(contentsOf: matches[0]),
                  let tga = try? CMTGATexture(data: bytes),
                  let provider = CGDataProvider(data: tga.rgba as CFData),
                  let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let image = CGImage(
                    width: tga.width, height: tga.height,
                    bitsPerComponent: 8, bitsPerPixel: 32,
                    bytesPerRow: tga.width * 4, space: space,
                    bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                    provider: provider, decode: nil,
                    shouldInterpolate: true, intent: .defaultIntent
                  ) else {
                unavailable.insert(key)
                return nil
            }
            decoded[key] = image
            return image
        }
    }

    private static func originalTexture(
        for modelURL: URL, cache: OriginalTextureCache,
        originalModelReference: String? = nil
    ) -> CGImage? {
        let modelName = modelURL.deletingPathExtension().lastPathComponent.lowercased()
        // Verified original PC shader names for shared ball/wall geometry.
        let sceneTextures: [String: String] = [
            "to_ball_tennis": "ball_tennis",
            "to_ball_billard": "ball_billard",
            "to_heat_cannon_ball": "heat_cannon_ball",
            "to_wall_concrete": "wall_concrete",
            "to_wall_cork": "wall_cork",
            "to_wall_bricks": "wall_bricks",
            "to_wall_metal": "wall_metal",
            "to_wall_schist": "wall_schist",
            "to_wall_paper": "wall_paper",
            "to_wall_brick": "wall_bricks",
            "to_wall_wall_paper": "wall_paper"
        ]
        guard let name = sceneTextures[originalModelReference?.lowercased() ?? ""]
                ?? verifiedTextures[modelName] else { return nil }
        return cache.image(named: name)
    }

    // Backward-compatible entry point for other original-UCM screens such
    // as the authentic startscreen. The gameplay scene uses its own shared
    // texture cache; independent previews may construct a local cache.
    static func loadGeometry(
        _ url: URL, assetDirectory: URL,
        originalModelReference: String? = nil
    ) throws -> SCNGeometry {
        try loadGeometry(
            url, textureCache: OriginalTextureCache(directory: assetDirectory),
            originalModelReference: originalModelReference
        )
    }

    private static func loadGeometry(
        _ url: URL, textureCache: OriginalTextureCache,
        originalModelReference: String? = nil,
        flowerGroup: Int? = nil
    ) throws -> SCNGeometry {
        let model = try CMUCMModel(data: Data(contentsOf: url))
        let raw: [UInt8]
        let count: Int
        if url.deletingPathExtension().lastPathComponent.lowercased() == "light_flower" {
            guard let frame = model.pairedMorphVertexData(group: flowerGroup ?? 0) else {
                throw CMUCMError.invalidGeometry
            }
            raw = [UInt8](frame)
            count = model.verticesPerGroup
        } else {
            raw = [UInt8](model.vertexData)
            count = model.vertexCount
        }
        func readFloat(_ offset: Int) -> Float {
            let bits = UInt32(raw[offset]) | (UInt32(raw[offset+1]) << 8)
                | (UInt32(raw[offset+2]) << 16) | (UInt32(raw[offset+3]) << 24)
            return Float(bitPattern: bits)
        }
        // UCM is a packed little-endian vertex stream. Decode the positions
        // explicitly rather than assuming the host's byte order.
        var positions: [SCNVector3] = []
        positions.reserveCapacity(count)
        for index in 0..<count {
            let offset = index * 32
            let x = readFloat(offset)
            let y = readFloat(offset + 4)
            let z = readFloat(offset + 8)
            // Invalid coordinates must not enter SceneKit bounds or physics:
            // NaN/Infinity can poison the camera framing and collision solver.
            guard x.isFinite, y.isFinite, z.isFinite else {
                throw NSError(domain: "CMOriginalUCMGeometry", code: 1,
                              userInfo: [NSLocalizedDescriptionKey:
                                "Non-finite position in UCM vertex \(index)"])
            }
            positions.append(SCNVector3(x, y, z))
        }
        let source = SCNGeometrySource(vertices: positions)
        // UCM vertex records: position at 0, normal at 12, UV at 24.
        // Decode all UCM attributes as little-endian, just like positions.
        // Passing packed bytes directly to SceneKit assumes host endianness
        // and allows malformed normals/UVs to reach the renderer.
        var normalVectors: [SCNVector3] = []
        var uvVectors: [CGPoint] = []
        normalVectors.reserveCapacity(count)
        uvVectors.reserveCapacity(count)
        for index in 0..<count {
            let offset = index * 32
            let nx = readFloat(offset + 12)
            let ny = readFloat(offset + 16)
            let nz = readFloat(offset + 20)
            let u = readFloat(offset + 24)
            let v = readFloat(offset + 28)
            guard nx.isFinite, ny.isFinite, nz.isFinite,
                  u.isFinite, v.isFinite else {
                throw NSError(domain: "CMOriginalUCMGeometry", code: 2,
                              userInfo: [NSLocalizedDescriptionKey:
                                "Non-finite normal or UV in UCM vertex \(index)"])
            }
            normalVectors.append(SCNVector3(nx, ny, nz))
            uvVectors.append(CGPoint(x: CGFloat(u), y: CGFloat(v)))
        }
        let normals = SCNGeometrySource(normals: normalVectors)
        let texcoords = SCNGeometrySource(textureCoordinates: uvVectors)
        // SceneKit's index buffer is explicitly little-endian, matching UCM.
        // Do not serialize native UInt16 memory directly: its byte order is
        // architecture-dependent and would invert indices on big-endian hosts.
        var indexData = Data(capacity: model.indices.count * 2)
        for index in model.indices {
            indexData.append(UInt8(truncatingIfNeeded: index))
            indexData.append(UInt8(truncatingIfNeeded: index >> 8))
        }
        let element = SCNGeometryElement(data: indexData, primitiveType: .triangles,
                                         primitiveCount: model.triangleCount,
                                         bytesPerIndex: MemoryLayout<UInt16>.size)
        let geometry = SCNGeometry(sources: [source, normals, texcoords], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = originalTexture(
            for: url, cache: textureCache,
            originalModelReference: originalModelReference
        ) ?? UIColor(white: 0.78, alpha: 1)
        material.isDoubleSided = true
        #if DEBUG && targetEnvironment(simulator)
        // The CI-only copyright-free triangle tests whether SceneKit really
        // rasterizes a UCM mesh. Constant orange illumination avoids false
        // black frames caused by imported/synthetic face normals or lighting
        // settings; this branch does not affect ANY authentic PC material.
        if url.deletingPathExtension().lastPathComponent.lowercased()
            == "cm_ci_triangle" {
            material.lightingModel = .constant
            material.diffuse.contents = UIColor.orange
            material.emission.contents = UIColor.orange
        }
        #endif
        geometry.materials = [material]
        return geometry
    }
}
