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

struct CMOriginalAssembledSceneView: UIViewRepresentable {
    let document: CMOriginalSceneDocument
    let assetDirectory: URL
    var experimentalPhysics = false
    var physicsPaused = false
    var diagnosticHinges = false
    var configuredPhysicsRoles: [String: CMOriginalGameplaySession.PhysicsRole] = [:]
    var configuredReactions: [CMOriginalGameplaySession.ReactionRule] = []
    var switchPressCount = 0

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
            ? "Double tap two different parts to add a hinge. Tap with three fingers to cancel a pending endpoint or undo the last manual hinge. Long press a part to pin or unpin it."
            : "Inspect the original imported parts using the camera controls."
        view.accessibilityValue = physicsAccessibilityStatus
        view.allowsCameraControl = true
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
        // Double-tap two different physical meshes to connect them while
        // the simulation is running; single-tap retains impulse behavior.
        if experimentalPhysics {
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
        drag.isEnabled = false // Never rewrite authentic original level placement.
        view.addGestureRecognizer(drag)
        let reset = UILongPressGestureRecognizer(target: context.coordinator,
                                                  action: #selector(Coordinator.resetSelected(_:)))
        reset.minimumPressDuration = 0.8
        // In inspection mode, long press resets a saved position; in physics
        // mode, it toggles a mesh between movable and fixed for diagnostics.
        reset.isEnabled = experimentalPhysics
        view.addGestureRecognizer(reset)
        context.coordinator.storageKey = "cm.original.positions.\(document.sceneSHA256)"
        context.coordinator.physicsEnabled = experimentalPhysics
        context.coordinator.session = CMOriginalGameplaySession(document: document)
        if experimentalPhysics {
            context.coordinator.session?.start()
            if physicsPaused { context.coordinator.session?.pause() }
        }
        var originalPositions: [String: SCNVector3] = [:]
        let scene = buildScene(originalPositions: &originalPositions)
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
        view.pointOfView = scene.rootNode.childNode(withName: "original-level-camera", recursively: false)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // SwiftUI updates pause state without reconstructing imported meshes
        // or losing the current simulated positions.
        uiView.isPlaying = experimentalPhysics && !physicsPaused
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

        func registerPhysicsNodes(in scene: SCNScene) {
            physicsNodesByObjectID.removeAll()
            appliedPhysicsRoles.removeAll()
            scene.rootNode.enumerateChildNodes { node, _ in
                guard node.physicsBody != nil,
                      let id = (node as? CMOriginalObjectMeshNode)?.originalObjectID else { return }
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
                  let a = (contact.nodeA as? CMOriginalObjectMeshNode)?.originalObjectID,
                  let b = (contact.nodeB as? CMOriginalObjectMeshNode)?.originalObjectID else { return }
            sessionLock.lock()
            session?.recordContact(a, b, impulse: Double(contact.collisionImpulse))
            sessionLock.unlock()
        }
        private var originalEmission: Any?
        private weak var dragging: SCNNode?
        private var dragInitialPosition: SCNVector3?
        private var lastDragPoint: CGPoint?
        private var dragWasActive = false
        var storageKey = ""
        var physicsEnabled = false
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

        @objc func resetSelected(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let view = gesture.view as? SCNView else { return }
            if physicsEnabled {
                guard let node = view.hitTest(gesture.location(in: view),
                                              options: [.firstFoundOnly: true]).first?.node,
                      let body = node.physicsBody else { return }
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
                    node.transform = node.presentation.transform
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
                node.opacity = makeStatic ? 0.55 : 1.0
                return
            }
            guard
                  let selected = highlighted,
                  view.hitTest(gesture.location(in: view), options: [.firstFoundOnly: true]).first?.node === selected,
                  let owner = selected.parent?.parent,
                  let identifier = owner.name,
                  let original = originalPositions[identifier] else { return }
            owner.position = original
            var positions = UserDefaults.standard.dictionary(forKey: storageKey) as? [String: [Double]] ?? [:]
            positions.removeValue(forKey: identifier)
            UserDefaults.standard.set(positions, forKey: storageKey)
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer is UIPanGestureRecognizer else { return true }
            guard let view = gestureRecognizer.view as? SCNView,
                  let selected = highlighted else { return false }
            let point = gestureRecognizer.location(in: view)
            // Do not steal camera gestures unless the finger begins directly
            // on the selected mesh.
            return view.hitTest(point, options: [.firstFoundOnly: true]).first?.node === selected
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            false
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
                guard let owner = selected.parent?.parent else { return }
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
                  let body = node.physicsBody else { return }
            guard let first = pendingHingeEndpoint, first !== node,
                  let firstBody = first.physicsBody else {
                clearPendingHingeEndpoint()
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
            clearPendingHingeEndpoint()
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
            let anchorA = first.presentation.convertPosition(anchor, from: nil)
            let anchorB = node.presentation.convertPosition(anchor, from: nil)
            func unit(_ vector: SCNVector3) -> SCNVector3 {
                let length = sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
                guard length.isFinite, length > 0.00001 else { return SCNVector3(0, 0, 1) }
                return SCNVector3(vector.x / length, vector.y / length, vector.z / length)
            }
            let axisA = unit(first.presentation.convertVector(axis, from: nil))
            let axisB = unit(node.presentation.convertVector(axis, from: nil))
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
            view.isPlaying = wasPlaying
            let marker = SCNNode(geometry: SCNSphere(radius: 0.08))
            marker.name = "manual-hinge-anchor"
            marker.geometry?.firstMaterial?.diffuse.contents = UIColor.systemGreen
            marker.position = anchor
            scene.rootNode.addChildNode(marker)
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
                // Apply the experimental impulse at the actual touched surface
                // rather than the center of mass. Off-center taps can now
                // generate torque, allowing rotational collision experiments.
                guard let body = node?.physicsBody, body.type == .dynamic,
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

    private func buildScene(originalPositions: inout [String: SCNVector3]) -> SCNScene {
        let scene = SCNScene()
        var loadedMeshNodes: [SCNNode] = []
        var meshCache: [URL: SCNGeometry] = [:]
        // Avoid reparsing a corrupt UCM every time it is referenced.
        var invalidMeshes = Set<URL>()
        // Physics trials must always begin at the authentic imported positions,
        // not at coordinates previously edited in the 3D inspection mode.
        var nodeOrdinal = 0
        var objectOrdinal = 0

        func parseRotation(_ raw: String?) -> SCNVector3 {
            guard let raw else { return SCNVector3Zero }
            let parts = raw.split(whereSeparator: { $0 == " " || $0 == "," })
            guard parts.count == 4, parts[0].lowercased() == "xyz",
                  let x = Float(parts[1]), let y = Float(parts[2]),
                  let z = Float(parts[3]), x.isFinite, y.isFinite, z.isFinite else {
                return SCNVector3Zero
            }
            return SCNVector3(x, y, z)
        }

        func walk(_ item: CMOriginalSceneDocument.Node, parent: SCNNode, goalAncestor: Bool = false, ownerID: String? = nil) {
            var currentOwnerID = ownerID
            if item.name.hasPrefix("tmo_") {
                currentOwnerID = "object-\(objectOrdinal)"
                objectOrdinal += 1
            }
            // A nested tmo_* is a separate original object. GOAL 1 on its
            // parent does not establish that the child is also a goal.
            // Only propagate a goal through non-object transform/3DO nodes.
            let isGoal = item.name.hasPrefix("tmo_")
                ? item.goalRaw == "1"
                : (goalAncestor || item.goalRaw == "1")
            let transform = SCNNode()
            let identifier = "original-node-\(nodeOrdinal)"
            nodeOrdinal += 1
            transform.name = identifier
            if let p = item.positionRelative ?? item.position, p.count == 3 {
                transform.position = SCNVector3(Float(p[0]), Float(p[1]), Float(p[2]))
            }
            transform.eulerAngles = parseRotation(item.rotationRelativeRaw ?? item.rotationRaw)
            originalPositions[identifier] = transform.position
            parent.addChildNode(transform)

            // A 3DO entry is a model reference, not an additional object transform.
            if item.name.hasPrefix("3DO ") {
                let name = String(item.name.dropFirst(4))
                if let url = CMOriginalModelResolver.resolve(name, in: assetDirectory) {
                    if !invalidMeshes.contains(url) {
                        let geometry: SCNGeometry?
                        if let cached = meshCache[url] {
                            geometry = cached
                        } else {
                            geometry = try? Self.loadGeometry(url)
                            if let geometry {
                                meshCache[url] = geometry
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
                            // Highlight only authentic imported geometry belonging to
                            // an original GOAL 1 node; never invent a goal marker.
                            if isGoal {
                                let goalGeometry = geometry.copy() as! SCNGeometry
                                goalGeometry.materials = geometry.materials.map {
                                    let material = $0.copy() as! SCNMaterial
                                    material.emission.contents = UIColor.systemGreen.withAlphaComponent(0.45)
                                    return material
                                }
                                mesh.geometry = goalGeometry
                            }
                            transform.addChildNode(mesh)
                            if experimentalPhysics {
                                // Approximate collision volumes only; original CML
                                // physical properties have not yet been decoded.
                                // A shape attached to a mesh child must use
                                // geometry-local coordinates. Building a shape
                                // from the node can bake its parent transforms
                                // into collision geometry a second time.
                                let shape = SCNPhysicsShape(geometry: geometry, options: [
                                    .type: SCNPhysicsShape.ShapeType.boundingBox
                                ])
                                let body = SCNPhysicsBody(type: .dynamic,
                                                          shape: shape)
                                // GOAL is a puzzle objective, not a static-body flag.
                                body.mass = 1
                                body.friction = 0.6
                                body.restitution = 0.15
                                // Fast-moving small parts need continuous
                                // collision detection to reduce tunneling
                                // through thin approximate collision boxes.
                                body.continuousCollisionDetectionThreshold = 0.001
                                body.categoryBitMask = 1
                                body.collisionBitMask = 1
                                body.contactTestBitMask = 1
                                mesh.physicsBody = body
                                // SceneKit's physics solver advances only when
                                // the scene is playing, even if it is visible.
                            }
                            loadedMeshNodes.append(mesh)
                        }
                    }
                }
            }
            for child in item.children {
                walk(child, parent: transform, goalAncestor: isGoal, ownerID: currentOwnerID)
            }
        }
        walk(document.root, parent: scene.rootNode)
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
        // Only meshes with a physics body can be hinge endpoints.
        let hingeCandidates = loadedMeshNodes.filter { $0.physicsBody != nil }
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
            let allCorners = hingeCandidates.map { corners($0) }
            var closestPair = (0, 1)
            var closestA = SCNVector3Zero
            var closestB = SCNVector3Zero
            var bestDistanceSquared = Float.infinity
            for i in 0..<(allCorners.count - 1) {
                for j in (i + 1)..<allCorners.count {
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
            let first = hingeCandidates[closestPair.0]
            let second = hingeCandidates[closestPair.1]
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
            floor.geometry?.firstMaterial?.diffuse.contents = UIColor.darkGray
            floor.geometry?.firstMaterial?.transparency = 0.35
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
            camera.position = SCNVector3(center.x, center.y, center.z + distance)
            camera.look(at: center)
        } else {
            camera.position = SCNVector3(0, 0, 10)
        }
        scene.rootNode.addChildNode(camera)
        return scene
    }

    private static func loadGeometry(_ url: URL) throws -> SCNGeometry {
        let model = try CMUCMModel(data: Data(contentsOf: url))
        let raw = [UInt8](model.vertexData)
        func readFloat(_ offset: Int) -> Float {
            let bits = UInt32(raw[offset]) | (UInt32(raw[offset+1]) << 8)
                | (UInt32(raw[offset+2]) << 16) | (UInt32(raw[offset+3]) << 24)
            return Float(bitPattern: bits)
        }
        var positions: [SCNVector3] = []
        positions.reserveCapacity(model.vertexCount)
        for index in 0..<model.vertexCount {
            let offset = index * 32
            positions.append(SCNVector3(readFloat(offset), readFloat(offset + 4),
                                        readFloat(offset + 8)))
        }
        let source = SCNGeometrySource(vertices: positions)
        // UCM vertex records: position at 0, normal at 12, UV at 24.
        let normals = SCNGeometrySource(
            data: model.vertexData, semantic: .normal,
            vectorCount: model.vertexCount, usesFloatComponents: true,
            componentsPerVector: 3, bytesPerComponent: 4,
            dataOffset: 12, dataStride: 32)
        let texcoords = SCNGeometrySource(
            data: model.vertexData, semantic: .texcoord,
            vectorCount: model.vertexCount, usesFloatComponents: true,
            componentsPerVector: 2, bytesPerComponent: 4,
            dataOffset: 24, dataStride: 32)
        let indexData = model.indices.withUnsafeBytes { Data($0) }
        let element = SCNGeometryElement(data: indexData, primitiveType: .triangles,
                                         primitiveCount: model.triangleCount,
                                         bytesPerIndex: MemoryLayout<UInt16>.size)
        let geometry = SCNGeometry(sources: [source, normals, texcoords], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(white: 0.78, alpha: 1)
        material.isDoubleSided = true
        geometry.materials = [material]
        return geometry
    }
}
