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
        view.scene = buildScene()
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    private func buildScene() -> SCNScene {
        let scene = SCNScene()
        var points: [SCNVector3] = []
        var meshCache: [URL: SCNGeometry] = [:]

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
            if let p = item.position, p.count == 3 {
                transform.position = SCNVector3(Float(p[0]), Float(p[1]), Float(p[2]))
            }
            transform.eulerAngles = parseRotation(item.rotationRelativeRaw ?? item.rotationRaw)
            parent.addChildNode(transform)

            // A 3DO entry is a model reference, not an additional object transform.
            if item.name.hasPrefix("3DO ") {
                let name = String(item.name.dropFirst(4))
                if let url = CMOriginalModelResolver.resolve(name, in: assetDirectory) {
                    if let geometry = meshCache[url] ?? (try? Self.loadGeometry(url)) {
                        meshCache[url] = geometry
                        let mesh = SCNNode(geometry: geometry)
                        mesh.name = name
                        transform.addChildNode(mesh)
                        points.append(transform.worldPosition)
                    }
                }
            }
            for child in item.children { walk(child, parent: transform) }
        }
        walk(document.root, parent: scene.rootNode)
        // Force world transforms to be evaluated before framing nested meshes.
        scene.rootNode.enumerateChildNodes { _, _ in }

        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zNear = 0.01
        camera.camera?.zFar = 10000
        if !points.isEmpty {
            let xs = points.map { $0.x }, ys = points.map { $0.y }, zs = points.map { $0.z }
            let center = SCNVector3((xs.min()! + xs.max()!) / 2,
                                    (ys.min()! + ys.max()!) / 2,
                                    (zs.min()! + zs.max()!) / 2)
            let span = max(xs.max()! - xs.min()!, ys.max()! - ys.min()!,
                           zs.max()! - zs.min()!, 1)
            camera.position = SCNVector3(center.x, center.y, center.z + span * 2.5)
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
        let indexData = model.indices.withUnsafeBufferPointer {
            Data(buffer: $0)
        }
        let element = SCNGeometryElement(data: indexData, primitiveType: .triangles,
                                         primitiveCount: model.triangleCount,
                                         bytesPerIndex: MemoryLayout<UInt16>.size)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = UIColor(white: 0.78, alpha: 1)
        material.isDoubleSided = true
        geometry.materials = [material]
        return geometry
    }
}
