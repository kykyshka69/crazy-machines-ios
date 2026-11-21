import SwiftUI
import SceneKit

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

struct CMOriginalAssembledSceneView: UIViewRepresentable {
    let document: CMOriginalSceneDocument
    let assetDirectory: URL
    var experimentalPhysics = false
    var physicsPaused = false
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
    // Reports a user-operated original PC power switch. This changes its
    // actual lever mesh, NOT the unrecovered electrical connectivity.
    var onOriginalSwitchToggle: ((String, Bool) -> Void)? = nil

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
        var diagnosticMarkers = 0
        scene.rootNode.enumerateChildNodes { node, _ in
            guard node.geometry != nil else { return }
            meshes += 1
            if node is CMOriginalObjectMeshNode { originalMeshes += 1 }
            if node.name == "cm-ci-render-calibration" {
                diagnosticMarkers += 1
            }
        }
        let camera = scene.rootNode.childNode(
            withName: "original-level-camera", recursively: false)
        let position = camera?.position ?? SCNVector3Zero
        return "; sceneMeshes=\(meshes); originalUCM=\(originalMeshes)" +
            "; calibration=\(diagnosticMarkers); camera=" +
            "\(position.x),\(position.y),\(position.z)"
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
               ? "Only UNLOCKED parts from the original PC puzzle can be moved or rotated. Tap to select; drag, twist, or pinch to zoom."
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
        context.coordinator.storageKey = "cm.original.positions.\(document.sceneSHA256)"
        context.coordinator.rotationStorageKey = "cm.original.rotations.\(document.sceneSHA256)"
        context.coordinator.physicsEnabled = experimentalPhysics
        context.coordinator.diagnosticTapImpulses = diagnosticTapImpulses
        context.coordinator.setExperimentalMotorDrive(experimentalMotorDrive)
        context.coordinator.session = CMOriginalGameplaySession(document: document)
        context.coordinator.onOriginalZoneContact = onOriginalZoneContact
        context.coordinator.onLinkedZoneContact = onLinkedZoneContact
        context.coordinator.onOriginalConnectionContact = onOriginalConnectionContact
        context.coordinator.onOriginalSwitchToggle = onOriginalSwitchToggle
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
        #if DEBUG && targetEnvironment(simulator)
        view.accessibilityValue = physicsAccessibilityStatus +
            sceneDebugStatus(scene)
        #endif
        context.coordinator.initializeSwitchPressCount(switchPressCount)
        if experimentalPhysics {
            context.coordinator.registerPhysicsNodes(in: scene)
            context.coordinator.configurePhysicsRoles(configuredPhysicsRoles)
            context.coordinator.configureExperimentalReactions(configuredReactions)
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
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // SwiftUI updates pause state without reconstructing imported meshes
        // or losing the current simulated positions.
        context.coordinator.onOriginalZoneContact = onOriginalZoneContact
        context.coordinator.onLinkedZoneContact = onLinkedZoneContact
        context.coordinator.onOriginalConnectionContact = onOriginalConnectionContact
        context.coordinator.onOriginalSwitchToggle = onOriginalSwitchToggle
        context.coordinator.diagnosticTapImpulses = diagnosticTapImpulses
        context.coordinator.setExperimentalMotorDrive(experimentalMotorDrive)
        // A paused experiment must still display its current 3D frame.
        // Freezing SceneKit's renderer would also prevent camera updates.
        uiView.isPlaying = true
        uiView.scene?.physicsWorld.speed =
            experimentalPhysics && !physicsPaused ? 1 : 0
        uiView.allowsCameraControl = !allowObjectPlacement || experimentalPhysics
        if experimentalPhysics {
            context.coordinator.setSessionPaused(physicsPaused)
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
        private var motorRotorObjectIDs = Set<String>()
        private var axleObjectIDs = Set<String>()
        // Authentic PC conveyor children are linked through their scene-graph
        // parentID, not through a guessed nearest wheel or motor.
        private var originalTypesByID: [String: String] = [:]
        private var conveyorWheelNodes: [String: SCNNode] = [:]
        // The exact original UCM belt surface is offset from its housing.
        private var conveyorBeltNodes: [String: SCNNode] = [:]
        private var conveyorBeltMaterials: [String: SCNMaterial] = [:]
        private var conveyorTextureOffsets: [String: Float] = [:]
        private var switchLeverNodes: [String: SCNNode] = [:]
        private var switchLeverRestAngles: [String: SCNVector3] = [:]
        private var flippedSwitchIDs = Set<String>()
        var onOriginalSwitchToggle: ((String, Bool) -> Void)?

        func setExperimentalMotorDrive(_ enabled: Bool) {
            sessionLock.lock()
            experimentalMotorDriveEnabled = enabled
            sessionLock.unlock()
        }

        var onOriginalZoneContact: ((String) -> Void)?
        var onLinkedZoneContact: ((String, String) -> Void)?
        var onOriginalConnectionContact: ((String, String) -> Void)?
        private var reportedZoneContacts = Set<String>()
        private var reportedOriginalConnections = Set<String>()
        private var physicsNodesByObjectID: [String: [SCNNode]] = [:]
        // All 46 original balloon objects are identified by their PC tmo_
        // type. Only the 45 with VALB's movable bit will actually float;
        // the fixed balloon is kept static by configuredPhysicsRoles.
        private var buoyantObjectIDs = Set<String>()
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

        private func physicalNode(for node: SCNNode?) -> SCNNode? {
            var current = node
            while let candidate = current {
                if candidate.physicsBody != nil { return candidate }
                current = candidate.parent
            }
            return nil
        }

        func registerPhysicsNodes(in scene: SCNScene) {
            physicsNodesByObjectID.removeAll()
            appliedPhysicsRoles.removeAll()
            conveyorWheelNodes.removeAll()
            conveyorBeltNodes.removeAll()
            conveyorBeltMaterials.removeAll()
            conveyorTextureOffsets.removeAll()
            switchLeverNodes.removeAll()
            switchLeverRestAngles.removeAll()
            flippedSwitchIDs.removeAll()
            let originalObjects = session?.objects ?? []
            originalTypesByID = Dictionary(
                uniqueKeysWithValues: originalObjects.map { ($0.id, $0.type) }
            )
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
            axleObjectIDs = Set(
                (session?.objects ?? [])
                    .filter {
                        CMOriginalAxleParts.rotatingKinds.contains($0.type)
                            || $0.type == "tmo_rope_seesaw_lever"
                    }
                    .map(\.id)
            )
            let switchByLeverID = Dictionary(uniqueKeysWithValues:
                originalObjects.compactMap { part -> (String, String)? in
                    guard part.type == "tmo_power_switch_lever",
                          let parent = part.parentID,
                          originalTypesByID[parent] == "tmo_power_switch"
                    else { return nil }
                    return (part.id, parent)
                }
            )
            scene.rootNode.enumerateChildNodes { node, _ in
                if let owner = node as? CMOriginalPhysicsOwnerNode,
                   let leverID = owner.originalObjectID,
                   let switchID = switchByLeverID[leverID] {
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

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
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
            if experimentalMotorDriveEnabled {
                // Ramp the physically simulated rotor toward a limited
                // angular speed around its original Z axle. The driven
                // authentic UCM teeth can then interact with other physics
                // bodies, without a manually animated visual-only rotation.
                //
                // IMPORTANT: 3 rad/s is an EXPLICIT prototype setting,
                // not a speed recovered from the Windows game. Electrical
                // activation, torque curves and belt drive ratios remain
                // unknown and must not be silently inferred from VALF 0.125.
                let targetSpeed: Float = 3.0
                let maxStep = Float(delta) * 9.0
                for id in motorRotorObjectIDs {
                    for node in physicsNodesByObjectID[id] ?? [] {
                        guard let body = node.physicsBody,
                              body.type == .dynamic else { continue }
                        let rotation = body.angularVelocity
                        let signedSpeed = rotation.z >= 0 ? rotation.w : -rotation.w
                        let step = min(maxStep, max(-maxStep, targetSpeed - signedSpeed))
                        let next = signedSpeed + step
                        guard next.isFinite else { continue }
                        body.angularVelocity = SCNVector4(0, 0, 1, next)
                    }
                }
            }
            session?.advance(by: delta)
        }

        func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
            guard physicsEnabled else { return }
            applyPendingActions()
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

        func physicsWorld(_ world: SCNPhysicsWorld, didUpdate contact: SCNPhysicsContact) {
            guard physicsEnabled else { return }
            sessionLock.lock()
            let running = session?.phase == .running
            sessionLock.unlock()
            if running { transferConveyorMotion(contact) }
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
            guard let physicalA = physicalNode(for: contact.nodeA),
                  let physicalB = physicalNode(for: contact.nodeB),
                  physicalA !== physicalB,
                  let a = owningOriginalObjectID(for: physicalA),
                  let b = owningOriginalObjectID(for: physicalB),
                  a != b else { return }
            // SceneKit can report a child mesh rather than the owning compound
            // physics node. Resolve both owners before attributing contacts.
            sessionLock.lock()
            session?.recordContact(a, b, impulse: Double(contact.collisionImpulse))
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
                    let key = link.sourceID + "|" + link.targetID
                    if reportedOriginalConnections.insert(key).inserted {
                        newlyObservedConnections.append((link.sourceID, link.targetID))
                    }
                }
            }
            // Original PC 'tmo_zone' nodes are collection areas. Notify the
            // UI of ACTUAL SceneKit contacts, not of inferred puzzle victory.
            // Report each object only once for this simulation run.
            let types = Dictionary(
                uniqueKeysWithValues: (session?.objects ?? []).map { ($0.id, $0.type) }
            )
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
            // Each source-zone pair counts once. Original puzzles may have
            // multiple zones, and a random zone must not count as the
            // CONNECTED_TO target encoded by the Windows scene.
            if let candidate, let zoneID,
               session?.phase == .running,
               session?.physicsRole(for: candidate) == .movable,
               reportedZoneContacts.insert(candidate + "|" + zoneID).inserted {
                contactType = types[candidate]
                contactIDs = (candidate, zoneID)
            } else {
                contactType = nil
                contactIDs = nil
            }
            sessionLock.unlock()
            // Never mutate SwiftUI state from the SceneKit renderer thread.
            if contactType != nil || !newlyObservedConnections.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    if let contactType, let contactIDs {
                        self?.onOriginalZoneContact?(contactType)
                        self?.onLinkedZoneContact?(contactIDs.0, contactIDs.1)
                    }
                    for (sourceID, targetID) in newlyObservedConnections {
                        self?.onOriginalConnectionContact?(sourceID, targetID)
                    }
                }
            }
        }
        private var originalEmission: Any?
        private weak var dragging: SCNNode?
        private var dragInitialPosition: SCNVector3?
        private var lastDragPoint: CGPoint?
        private var dragWasActive = false
        private var rotationStartZ: Float?
        private var pinchStartFieldOfView: CGFloat?
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
                guard let node = view.hitTest(gesture.location(in: view),
                                              options: [.firstFoundOnly: true]).first?.node,
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
                  view.hitTest(gesture.location(in: view), options: [.firstFoundOnly: true]).first?.node === selected,
                  let owner = originalOwner(for: selected),
                  let identifier = owner.name,
                  let original = originalPositions[identifier] else { return }
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
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer is UIRotationGestureRecognizer {
                return !physicsEnabled
                    && originalOwner(for: highlighted)?.isUnlockedInOriginalLevel == true
            }
            if gestureRecognizer is UIPinchGestureRecognizer {
                return !physicsEnabled
            }
            guard gestureRecognizer is UIPanGestureRecognizer else { return true }
            guard let view = gestureRecognizer.view as? SCNView,
                  let selected = highlighted,
                  originalOwner(for: selected)?.isUnlockedInOriginalLevel == true
            else { return false }
            let point = gestureRecognizer.location(in: view)
            // Do not steal camera gestures unless the finger begins directly
            // on the selected mesh.
            return view.hitTest(point, options: [.firstFoundOnly: true]).first?.node === selected
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            false
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
            case .changed:
                guard let initial = rotationStartZ else { return }
                let next = initial + Float(gesture.rotation)
                if next.isFinite && abs(next) <= 100_000 {
                    owner.eulerAngles.z = next
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
                rotationStartZ = nil
            case .cancelled, .failed:
                if let original = rotationStartZ { owner.eulerAngles.z = original }
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
                guard let selected = highlighted,
                      let hit = view.hitTest(point, options: [.firstFoundOnly: true]).first,
                      hit.node === selected else { return }
                // Move the owning original object transform, not the 3DO
                // reference wrapper. Keep nested model offsets intact.
                guard let owner = originalOwner(for: selected),
                      owner.isUnlockedInOriginalLevel else { return }
                dragging = owner
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
                }
                dragging = nil
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
                  let node = view.hitTest(gesture.location(in: view),
                                          options: [.firstFoundOnly: true]).first?.node,
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
            let hits = view.hitTest(gesture.location(in: view),
                                    options: [.firstFoundOnly: true])
            let anchor = hits.first?.worldCoordinates ?? SCNVector3(
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

        /// Flip the REAL imported PC tmo_power_switch_lever model on tap.
        /// The switch's electrical consequences are intentionally NOT
        /// inferred: original wire connections are not yet decoded.
        private func flipOriginalPowerSwitch(_ hitNode: SCNNode?) -> Bool {
            guard let objectID = owningOriginalObjectID(for: hitNode) else {
                return false
            }
            let switchID: String
            if originalTypesByID[objectID] == "tmo_power_switch" {
                switchID = objectID
            } else if originalTypesByID[objectID] == "tmo_power_switch_lever",
                      let parent = session?.objects.first(
                          where: { $0.id == objectID }
                      )?.parentID,
                      originalTypesByID[parent] == "tmo_power_switch" {
                switchID = parent
            } else {
                return false
            }
            guard let lever = switchLeverNodes[switchID],
                  let original = switchLeverRestAngles[switchID] else { return false }
            // The session is the source of truth for genuine switch
            // positions. Reject taps while paused, rather than visually
            // flipping a lever when the simulation cannot accept the input.
            sessionLock.lock()
            let nextState = session?.toggleOriginalSwitch(switchID)
            sessionLock.unlock()
            guard let isOn = nextState else { return false }
            if isOn {
                flippedSwitchIDs.insert(switchID)
            } else {
                flippedSwitchIDs.remove(switchID)
            }
            // The recovered lever has a real PC ROT x=1. We preserve the
            // original rest angle and provide only a modest prototype tilt
            // for the alternate state, rather than invent an engine limit.
            lever.removeAction(forKey: "original-switch")
            let targetX = original.x + (isOn ? -0.6 : 0)
            lever.runAction(
                SCNAction.rotateTo(
                    x: CGFloat(targetX), y: CGFloat(original.y),
                    z: CGFloat(original.z), duration: 0.16,
                    usesShortestUnitArc: true
                ),
                forKey: "original-switch"
            )
            onOriginalSwitchToggle?(switchID, isOn)
            return true
        }

        @objc func selectObject(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView,
                  gesture.state == .ended, !dragWasActive else { return }
            let point = gesture.location(in: view)
            let hit = view.hitTest(point, options: [.firstFoundOnly: true]).first
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
        // Resolve each original 3DO reference once per scene; levels reuse meshes.
        let assetIndex = CMOriginalModelResolver.AssetIndex(directory: assetDirectory)
        var resolvedModels: [String: URL] = [:]
        var missingModels = Set<String>()
        var meshCache: [String: SCNGeometry] = [:]
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
                        let cacheKey = url.path + "|" + name.lowercased()
                        if let cached = meshCache[cacheKey] {
                            geometry = cached
                        } else {
                            geometry = try? Self.loadGeometry(
                                url, assetDirectory: assetDirectory,
                                originalModelReference: name
                            )
                            if let geometry {
                                meshCache[cacheKey] = geometry
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
                            if name.lowercased() == "to_belt_conveyer_belt",
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
                            if let currentOwnerID {
                                mesh.originalObjectID = currentOwnerID
                            }
                            // Render the original UCM geometry without adding
                            // synthetic GOAL colors. GOAL is preserved in the
                            // level inspector, not encoded as invented materials.
                            transform.addChildNode(mesh)
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
                var proxyCenters: [SCNVector3] = []
                let shapes: [SCNPhysicsShape] = meshes.compactMap { mesh in
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
                let transforms = zip(meshes, proxyCenters).map { mesh, center in
                    // SCNSphere and SCNBox are centered at their own origin.
                    // Apply the local mesh-bounds center BEFORE the nested
                    // original 3DO POSREL/ROTREL/SCAL transform to the tmo_.
                    let meshTransform = mesh.convertTransform(
                        SCNMatrix4Identity, to: root)
                    let centered = SCNMatrix4Mult(meshTransform,
                        SCNMatrix4MakeTranslation(center.x, center.y, center.z))
                    return NSValue(scnMatrix4: centered)
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
                    || CMOriginalAxleParts.rotatingKinds.contains(kind) {
                guard let wheel = objectRoots[id],
                      let body = wheel.physicsBody else { continue }
                if kind == "tmo_rope_seesaw_lever" {
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
        for mesh in loadedMeshNodes {
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
        if hasBounds {
            let center = SCNVector3((lower.x + upper.x) / 2,
                                    (lower.y + upper.y) / 2,
                                    (lower.z + upper.z) / 2)
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
            camera.look(at: center)
        } else {
            camera.position = SCNVector3(0, 0, -10)
            // SceneKit cameras look along LOCAL -Z by default. Without an
            // explicit look(at:), a fallback camera at world -Z points AWAY
            // from scene objects at Z=0, guaranteeing a blank preview.
            camera.look(at: SCNVector3Zero)
        }
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

    private static func originalTexture(
        for modelURL: URL, in directory: URL,
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
        let textureName = sceneTextures[originalModelReference?.lowercased() ?? ""]
            ?? verifiedTextures[modelName]
        guard let textureName else { return nil }
        // Original Windows asset paths are case-insensitive; the iPhone
        // sandbox is not. Resolve the real imported filename rather than
        // assuming its spelling matches the shader's lowercase name.
        let candidates = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let matches = candidates.filter {
            $0.pathExtension.lowercased() == "tga"
                && $0.deletingPathExtension().lastPathComponent.lowercased() == textureName
                && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
        }
        // A duplicate basename is ambiguous: never select an arbitrary texture.
        guard matches.count == 1 else { return nil }
        let textureURL = matches[0]
        guard let bytes = try? Data(contentsOf: textureURL),
              let decoded = try? CMTGATexture(data: bytes),
              let provider = CGDataProvider(data: decoded.rgba as CFData),
              let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: decoded.width, height: decoded.height,
                       bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: decoded.width * 4, space: colorSpace,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                       provider: provider, decode: nil,
                       shouldInterpolate: true, intent: .defaultIntent)
    }

    static func loadGeometry(
        _ url: URL, assetDirectory: URL,
        originalModelReference: String? = nil
    ) throws -> SCNGeometry {
        let model = try CMUCMModel(data: Data(contentsOf: url))
        let raw = [UInt8](model.vertexData)
        func readFloat(_ offset: Int) -> Float {
            let bits = UInt32(raw[offset]) | (UInt32(raw[offset+1]) << 8)
                | (UInt32(raw[offset+2]) << 16) | (UInt32(raw[offset+3]) << 24)
            return Float(bitPattern: bits)
        }
        // UCM is a packed little-endian vertex stream. Decode the positions
        // explicitly rather than assuming the host's byte order.
        var positions: [SCNVector3] = []
        positions.reserveCapacity(model.vertexCount)
        for index in 0..<model.vertexCount {
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
        normalVectors.reserveCapacity(model.vertexCount)
        uvVectors.reserveCapacity(model.vertexCount)
        for index in 0..<model.vertexCount {
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
            for: url, in: assetDirectory,
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
