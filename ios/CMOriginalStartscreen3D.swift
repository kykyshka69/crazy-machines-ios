import SwiftUI
import SceneKit

/// Displays genuine imported startscreen UCM meshes. The original Windows
/// camera, animation and scripting are not yet decoded; framing is adaptive.
struct CMOriginalStartscreen3D: UIViewRepresentable {
    let assetDirectory: URL

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        view.backgroundColor = UIColor.clear
        view.autoenablesDefaultLighting = true
        view.antialiasingMode = .multisampling4X
        let scene = SCNScene()
        let index = CMOriginalModelResolver.AssetIndex(directory: assetDirectory)
        let modelNames = [
            "startscreen_chalkboard_board", "startscreen_chalkboard_frame",
            "startscreen_lamp", "startscreen_lamp_inside",
            "startscreen_lamp_shine", "startscreen_sponge",
            "startscreen_note", "startscreen_magnet"
        ]
        var meshes: [SCNNode] = []
        for name in modelNames {
            guard let url = index.resolve(name),
                  let geometry = try? CMOriginalAssembledSceneView.loadGeometry(
                    url, assetDirectory: assetDirectory
                  ) else { continue }
            let node = SCNNode(geometry: geometry)
            node.name = name
            scene.rootNode.addChildNode(node)
            meshes.append(node)
        }
        guard !meshes.isEmpty else {
            view.scene = scene
            return view
        }
        var low = SCNVector3(Float.infinity, Float.infinity, Float.infinity)
        var high = SCNVector3(-Float.infinity, -Float.infinity, -Float.infinity)
        for mesh in meshes {
            let (a, z) = mesh.boundingBox
            for x in [a.x, z.x] {
                for y in [a.y, z.y] {
                    for depth in [a.z, z.z] {
                        let p = mesh.convertPosition(SCNVector3(x, y, depth), to: nil)
                        guard p.x.isFinite, p.y.isFinite, p.z.isFinite else { continue }
                        low.x = min(low.x, p.x); low.y = min(low.y, p.y)
                        low.z = min(low.z, p.z)
                        high.x = max(high.x, p.x); high.y = max(high.y, p.y)
                        high.z = max(high.z, p.z)
                    }
                }
            }
        }
        guard low.x.isFinite, high.x.isFinite else {
            view.scene = scene
            return view
        }
        let center = SCNVector3((low.x + high.x) / 2,
                                (low.y + high.y) / 2,
                                (low.z + high.z) / 2)
        let span = max(high.x - low.x, high.y - low.y, high.z - low.z, 1)
        let camera = SCNNode()
        camera.camera = SCNCamera()
        camera.camera?.zNear = 0.01
        camera.camera?.zFar = Double(max(span * 30, 1000))
        camera.position = SCNVector3(center.x, center.y, center.z + span * 2.4)
        camera.look(at: center)
        scene.rootNode.addChildNode(camera)
        view.pointOfView = camera
        view.scene = scene
        view.isPlaying = true
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {}
}
