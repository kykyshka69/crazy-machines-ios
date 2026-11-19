import SwiftUI
import SceneKit

/// Read-only assembly of the user's authentic UCM meshes at scene POS coordinates.
/// Missing meshes are omitted and reported, never replaced with invented shapes.
struct CMOriginalAssembledSceneView: UIViewRepresentable {
    let document: CMOriginalSceneDocument
    let assetDirectory: URL

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = UIColor(white: 0.09, alpha: 1)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        view.defaultCameraController.interactionMode = .orbitTurntable
        view.defaultCameraController.inertiaEnabled = true
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.selectObject(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        let drag = UIPanGestureRecognizer(target: context.coordinator,
                                          action: #selector(Coordinator.dragSelected(_:)))
        drag.minimumNumberOfTouches = 1
        drag.maximumNumberOfTouches = 1
        drag.delegate = context.coordinator
        view.addGestureRecognizer(drag)
        let scene = buildScene()
        view.scene = scene
        view.pointOfView = scene.rootNode.childNode(withName: "original-level-camera", recursively: false)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var highlighted: SCNNode?
        private var originalEmission: Any?
        private weak var dragging: SCNNode?
        private var lastDragPoint: CGPoint?

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
                lastDragPoint = point
            case .changed:
                guard let target = dragging, let previous = lastDragPoint,
                      view.pointOfView != nil else { return }
                // Move in the camera-facing plane, preserving the object's
                // depth and original parent coordinate system.
                let world = target.presentation.worldPosition
                let projected = view.projectPoint(world)
                let from = view.unprojectPoint(SCNVector3(Float(previous.x), Float(previous.y), projected.z))
                let to = view.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), projected.z))
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
                dragging = nil
                lastDragPoint = nil
            }
        }

        @objc func selectObject(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view as? SCNView else { return }
            let point = gesture.location(in: view)
            let node = view.hitTest(point, options: [.firstFoundOnly: true]).first?.node
            if let previous = highlighted, let material = previous.geometry?.firstMaterial {
                material.emission.contents = originalEmission
            }
            highlighted = nil
            originalEmission = nil
            guard let node, let geometry = node.geometry,
                  let material = geometry.firstMaterial else { return }
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

    private func buildScene() -> SCNScene {
        let scene = SCNScene()
        var loadedMeshNodes: [SCNNode] = []
        var meshCache: [URL: SCNGeometry] = [:]
        // Avoid reparsing a corrupt UCM every time it is referenced.
        var invalidMeshes = Set<URL>()

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

        func walk(_ item: CMOriginalSceneDocument.Node, parent: SCNNode) {
            let transform = SCNNode()
            transform.name = item.name
            if let p = item.positionRelative ?? item.position, p.count == 3 {
                transform.position = SCNVector3(Float(p[0]), Float(p[1]), Float(p[2]))
            }
            transform.eulerAngles = parseRotation(item.rotationRelativeRaw ?? item.rotationRaw)
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
                            transform.addChildNode(mesh)
                            loadedMeshNodes.append(mesh)
                        }
                    }
                }
            }
            for child in item.children { walk(child, parent: transform) }
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
