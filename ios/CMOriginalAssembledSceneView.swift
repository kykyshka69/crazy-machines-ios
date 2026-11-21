import SwiftUI
import SceneKit

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
    var configuredPhysicsRoles: [String: CMOriginalGameplaySession.PhysicsRole] = [:]
    var configuredReactions: [CMOriginalGameplaySession.ReactionRule] = []
    var switchPressCount = 0
    // SceneKit collision telemetry for authentic PC capture zones.
    // This does NOT assert that the Windows level completion condition is met.
    var onOriginalZoneContact: ((String) -> Void)? = nil

    private var physicsAccessibilityStatus: String {
        let state = experimentalPhysics ? (physicsPaused ? "paused" : "running") : "off"
        return "\(document.root.goalCount) original goal markers; physics \(state)"
    }

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
        view.rendersContinuously = experimentalPhysics
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
        context.coordinator.session = CMOriginalGameplaySession(document: document)
        context.coordinator.onOriginalZoneContact = onOriginalZoneContact
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
        view.isPlaying = experimentalPhysics && !physicsPaused
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
        context.coordinator.diagnosticTapImpulses = diagnosticTapImpulses
        uiView.isPlaying = experimentalPhysics && !physicsPaused
        uiView.allowsCameraControl = !allowObjectPlacement || experimentalPhysics
        if experimentalPhysics {
            context.coordinator.setSessionPaused(physicsPaused)
            context.coordinator.configurePhysicsRoles(configuredPhysicsRoles)
            context.coordinator.pressConfiguredSwitchIfNeeded(switchPressCount)
        }
        uiView.accessibilityValue = context.coordinator.selectedModelName.map {
            physicsAccessibilityStatus + "; selected original model: " + $0
        } ?? physicsAccessibilityStatus
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate, SCNPhysicsContactDelegate, SCNSceneRendererDelegate {
        private weak var highlighted: SCNNode?
        var selectedModelName: String?
        var session: CMOriginalGameplaySession?
        private let sessionLock = NSLock()
        private var lastRendererTime: TimeInterval?
        var onOriginalZoneContact: ((String) -> Void)?
        private var reportedZoneContacts = Set<String>()
        private var physicsNodesByObjectID: [String: [SCNNode]] = [:]
        private var appliedPhysicsRoles: [String: CMOriginalGameplaySession.PhysicsRole] = [:]
        private var appliedReactionRules: [CMOriginalGameplaySession.ReactionRule] = []

        private var lastSwitchPressCount = 0

        func initializeSwitchPressCount(_ count: Int) {
            lastSwitchPressCount = count
        }

        func pressConfiguredSwitchIfNeeded(_ count: Int) {
            guard count > lastSwitchPressCount else { return }
            lastSwitchPressCount = count
            sessionLock.lock()
            if let source = session?.reactionRules.first?.objectID {
                _ = session?.pressObject(source)
            }
            sessionLock.unlock()
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
                        body.collisionBitMask = 1
                        body.contactTestBitMask = 1
                    case .movable:
                        body.type = .dynamic
                        body.collisionBitMask = 1
                        body.contactTestBitMask = 1
                    case .sensor:
                        body.type = .kinematic
                        body.collisionBitMask = 0
                        body.contactTestBitMask = 1
                    }
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
            scene.rootNode.enumerateChildNodes { node, _ in
                guard node.physicsBody != nil,
                      let id = self.physicsObjectID(for: node) else { return }
                self.physicsNodesByObjectID[id, default: []].append(node)
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
            session?.advance(by: delta)
        }

        func renderer(_ renderer: SCNSceneRenderer, didSimulatePhysicsAtTime time: TimeInterval) {
            guard physicsEnabled else { return }
            applyPendingActions()
        }

        func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
            guard physicsEnabled,
                  let physicalA = physicalNode(for: contact.nodeA),
                  let physicalB = physicalNode(for: contact.nodeB),
                  physicalA !== physicalB,
                  let a = owningOriginalObjectID(for: physicalA),
                  let b = owningOriginalObjectID(for: physicalB),
                  a != b else { return }
            // SceneKit can report a child mesh rather than the owning compound
            // physics node. Resolve both owners before attributing contacts.
            sessionLock.lock()
            session?.recordContact(a, b, impulse: Double(contact.collisionImpulse))
            // Original PC 'tmo_zone' nodes are collection areas. Notify the
            // UI of ACTUAL SceneKit contacts, not of inferred puzzle victory.
            // Report each object only once for this simulation run.
            let types = Dictionary(
                uniqueKeysWithValues: (session?.objects ?? []).map { ($0.id, $0.type) }
            )
            let candidate: String?
            if types[a] == "tmo_zone" && types[b] != "tmo_zone" {
                candidate = b
            } else if types[b] == "tmo_zone" && types[a] != "tmo_zone" {
                candidate = a
            } else {
                candidate = nil
            }
            let contactType: String?
            // Only moving original objects should count as entering the
            // collection zone. Fixed boards, decorative mounts and initial
            // static overlaps are not completed gameplay interactions.
            if let candidate,
               session?.phase == .running,
               session?.physicsRole(for: candidate) == .movable,
               reportedZoneContacts.insert(candidate).inserted {
                contactType = types[candidate]
            } else {
                contactType = nil
            }
            sessionLock.unlock()
            if let contactType {
                // SCNPhysicsContactDelegate is not guaranteed to execute on
                // the main thread. SwiftUI state may only change on main.
                DispatchQueue.main.async { [weak self] in
                    self?.onOriginalZoneContact?(contactType)
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
                            let mesh = CMOriginalObjectMeshNode(geometry: geometry)
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
            let explicitChildren = Set(item.children.compactMap { child -> String? in
                guard child.name.hasPrefix("3DO ") else { return nil }
                return String(child.name.dropFirst(4)).lowercased()
            })
            if let models = item.models {
                var seen = Set<String>()
                for name in models {
                    let key = name.lowercased()
                    guard !explicitChildren.contains(key), seen.insert(key).inserted else { continue }
                    attachOriginalModel(name)
                }
            }
            for child in item.children {
                walk(child, parent: transform, ownerID: currentOwnerID)
            }
        }
        walk(document.root, parent: scene.rootNode)

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
                let shapes: [SCNPhysicsShape] = meshes.compactMap { mesh in
                    guard let geometry = mesh.geometry else { return nil }
                    if kind.hasPrefix("tmo_ball_") {
                        // First-level original tennis, beach and basketball
                        // UCMs all have spherical extents around the origin.
                        // A SceneKit sphere is smoother and more stable than
                        // a faceted convex hull of their low-poly visual UCMs.
                        // Radius comes from the original mesh bounds; this
                        // is still an approximate solver, not Windows physics.
                        let (low, high) = mesh.boundingBox
                        let dx = high.x - low.x
                        let dy = high.y - low.y
                        let dz = high.z - low.z
                        let diameter = max(dx, dy, dz)
                        let smallest = min(dx, dy, dz)
                        if diameter.isFinite, diameter > 0,
                           smallest > diameter * 0.85 {
                            let sphere = SCNSphere(
                                radius: CGFloat(diameter * 0.5)
                            )
                            return SCNPhysicsShape(geometry: sphere, options: [
                                .type: SCNPhysicsShape.ShapeType.convexHull
                            ])
                        }
                    }
                    if kind == "tmo_zone" {
                        // The authentic PC zone.ucm is a four-vertex plane
                        // with ZERO Z thickness. A 3D convex hull of that
                        // plane is degenerate and may never report ball/crate
                        // contacts. Give the original XY capture area an
                        // invisible sensor depth so 2.5D objects can overlap
                        // it regardless of their original visible Z offset.
                        // The original UCM stays untouched and remains the
                        // only visible zone mesh.
                        let (low, high) = mesh.boundingBox
                        let width = CGFloat(max(0.001, high.x - low.x))
                        let height = CGFloat(max(0.001, high.y - low.y))
                        let depth: CGFloat = 0.6
                        let sensor = SCNBox(
                            width: width, height: height, length: depth,
                            chamferRadius: 0
                        )
                        return SCNPhysicsShape(geometry: sensor, options: [
                            .type: SCNPhysicsShape.ShapeType.boundingBox
                        ])
                    }
                    return SCNPhysicsShape(geometry: geometry, options: [
                        .type: SCNPhysicsShape.ShapeType.convexHull
                    ])
                }
                guard shapes.count == meshes.count else { continue }
                let transforms = meshes.map { mesh in
                    NSValue(scnMatrix4: mesh.convertTransform(SCNMatrix4Identity, to: root))
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
                body.friction = 0.6
                body.restitution = 0.15
                body.continuousCollisionDetectionThreshold = 0.001
                body.categoryBitMask = 1
                body.collisionBitMask = 1
                body.contactTestBitMask = 1
                root.physicsBody = body
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
        geometry.materials = [material]
        return geometry
    }
}
