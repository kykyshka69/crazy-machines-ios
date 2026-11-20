import SwiftUI
import SceneKit

/// Interactive assembly of authentic UCM meshes at original scene POS coordinates.
/// Missing meshes are omitted and reported, never replaced with invented shapes.
struct CMOriginalAssembledSceneView: UIViewRepresentable {
    let document: CMOriginalSceneDocument
    let assetDirectory: URL
    var experimentalPhysics = false
    var physicsPaused = false
    var diagnosticHinges = false

    private var physicsAccessibilityStatus: String {
        let state = experimentalPhysics ? (physicsPaused ? "paused" : "running") : "off"
        return "\(document.root.goalCount) original goal markers; physics \(state)"
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = UIColor(white: 0.09, alpha: 1)
        view.accessibilityIdentifier = "cm.original.assembled-scene"
        view.accessibilityLabel = "Original level 3D scene"
        view.accessibilityValue = physicsAccessibilityStatus
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        // SceneKit defaults to a paused scene in some configurations; make
        // frame scheduling explicit for deterministic experiment startup.
        view.rendersContinuously = experimentalPhysics
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.selectObject(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        let drag = UIPanGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.dragSelected(_:)))
        drag.minimumNumberOfTouches = 1
        drag.maximumNumberOfTouches = 1
        drag.delegate = context.coordinator
        drag.isEnabled = !experimentalPhysics
        view.addGestureRecognizer(drag)
        let reset = UILongPressGestureRecognizer(target: context.coordinator,
                                                  action: #selector(Coordinator.resetSelected(_:)))
        reset.minimumPressDuration = 0.8
        // In inspection mode, long press resets a saved position; in physics
        // mode, it toggles a mesh between movable and fixed for diagnostics.
        reset.isEnabled = true
        view.addGestureRecognizer(reset)
        context.coordinator.storageKey = "cm.original.positions.\(document.sceneSHA256)"
        context.coordinator.physicsEnabled = experimentalPhysics
        var originalPositions: [String: SCNVector3] = [:]
        let scene = buildScene(originalPositions: &originalPositions)
        if experimentalPhysics {
            scene.physicsWorld.gravity = SCNVector3(0, -9.8, 0)
        }
        view.scene = scene
        // Assign a fixed simulation step to reduce device-dependent solver
        // behavior and tunneling through thin imported mechanisms.
        if experimentalPhysics {
            scene.physicsWorld.timeStep = 1.0 / 120.0
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
        uiView.accessibilityValue = physicsAccessibilityStatus
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var highlighted: SCNNode?
        private var originalEmission: Any?
        private weak var dragging: SCNNode?
        private var dragInitialPosition: SCNVector3?
        private var lastDragPoint: CGPoint?
        private var dragWasActive = false
        var storageKey = ""
        var physicsEnabled = false
        var originalPositions: [String: SCNVector3] = [:]

        @objc func resetSelected(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began,
                  let view = gesture.view as? SCNView else { return }
            if physicsEnabled {
                guard let node = view.hitTest(gesture.location(in: view),
                                              options: [.firstFoundOnly: true]).first?.node,
                      let body = node.physicsBody else { return }
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

        @objc func selectObject(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView,
                  gesture.state == .ended, !dragWasActive else { return }
            let point = gesture.location(in: view)
            let node = view.hitTest(point, options: [.firstFoundOnly: true]).first?.node
            if physicsEnabled {
                // SceneKit hit-tests return a mesh node with a physics body.
                // Apply a small impulse along the camera's viewing direction
                // to provide a repeatable, visible interaction test.
                guard let body = node?.physicsBody, body.type == .dynamic,
                      let camera = view.pointOfView else { return }
                let forward = camera.presentation.convertVector(SCNVector3(0, 0, -1), to: nil)
                let magnitude: Float = 2
                body.applyForce(SCNVector3(forward.x * magnitude,
                                           forward.y * magnitude,
                                           forward.z * magnitude), asImpulse: true)
                return
            }
            if let previous = highlighted, let material = previous.geometry?.firstMaterial {
                material.emission.contents = originalEmission
            }
            highlighted = nil
            originalEmission = nil
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
        let savedPositions: [String: [Double]] = experimentalPhysics ? [:] :
            (UserDefaults.standard.dictionary(forKey: "cm.original.positions.\(document.sceneSHA256)") as? [String: [Double]] ?? [:])
        var nodeOrdinal = 0

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

        func walk(_ item: CMOriginalSceneDocument.Node, parent: SCNNode, goalAncestor: Bool = false) {
            let isGoal = goalAncestor || item.goalRaw == "1"
            let transform = SCNNode()
            let identifier = "original-node-\(nodeOrdinal)"
            nodeOrdinal += 1
            transform.name = identifier
            if let p = item.positionRelative ?? item.position, p.count == 3 {
                transform.position = SCNVector3(Float(p[0]), Float(p[1]), Float(p[2]))
            }
            transform.eulerAngles = parseRotation(item.rotationRelativeRaw ?? item.rotationRaw)
            originalPositions[identifier] = transform.position
            if let saved = savedPositions[identifier], saved.count == 3,
               saved.allSatisfy({ $0.isFinite && abs($0) <= Double(Float.greatestFiniteMagnitude) }) {
                transform.position = SCNVector3(Float(saved[0]), Float(saved[1]), Float(saved[2]))
            }
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
                            let mesh = SCNNode(geometry: geometry)
                            mesh.name = name
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
                                mesh.physicsBody = body
                                // SceneKit's physics solver advances only when
                                // the scene is playing, even if it is visible.
                            }
                            loadedMeshNodes.append(mesh)
                        }
                    }
                }
            }
            for child in item.children { walk(child, parent: transform, goalAncestor: isGoal) }
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
        if experimentalPhysics && diagnosticHinges && loadedMeshNodes.count >= 2 {
            // Experimental proof of a SceneKit hinge, not decoded CML linkage.
            // Join the first two imported meshes at their midpoint. The
            // physics bodies already exist on the mesh nodes.
            let first = loadedMeshNodes[0]
            let second = loadedMeshNodes[1]
            let a = first.convertPosition(SCNVector3Zero, to: nil)
            let b = second.convertPosition(SCNVector3Zero, to: nil)
            let anchor = SCNVector3((a.x + b.x) / 2,
                                    (a.y + b.y) / 2,
                                    (a.z + b.z) / 2)
            let hinge = SCNPhysicsHingeJoint(bodyA: first.physicsBody!,
                                             axisA: SCNVector3(0, 0, 1),
                                             anchorA: first.convertPosition(anchor, from: nil),
                                             bodyB: second.physicsBody!,
                                             axisB: SCNVector3(0, 0, 1),
                                             anchorB: second.convertPosition(anchor, from: nil))
            scene.physicsWorld.addBehavior(hinge)
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
