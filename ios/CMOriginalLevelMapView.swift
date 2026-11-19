import SwiftUI

/// Spatial inspection of user-imported original scene coordinates.
/// This is an orthographic X/Y plot, NOT the game's camera or physics.
struct CMOriginalLevelMapView: View {
    let document: CMOriginalSceneDocument

    private struct Marker: Identifiable {
        let id: Int
        let name: String
        let x: Double
        let y: Double
        let goal: Bool
    }

    private var markers: [Marker] {
        var result: [Marker] = []
        // Follow the original nested scene transforms rather than plotting
        // local POS coordinates as though they were world coordinates.
        // Rotation uses the same XYZ Euler convention as the SceneKit view.
        struct Transform {
            let x: Double
            let y: Double
            let angle: Double
        }
        func visit(_ node: CMOriginalSceneDocument.Node, parent: Transform) {
            let position = node.positionRelative ?? node.position ?? [0, 0, 0]
            let rawRotation = node.rotationRelativeRaw ?? node.rotationRaw
            let parts = rawRotation?.split(whereSeparator: { $0 == " " || $0 == "," }) ?? []
            let angle: Double
            if parts.count == 4, parts[0].lowercased() == "xyz",
               let value = Double(parts[3]), value.isFinite {
                angle = value
            } else {
                angle = 0
            }
            let c = cos(parent.angle)
            let s = sin(parent.angle)
            let world = Transform(
                x: parent.x + position[0] * c - position[1] * s,
                y: parent.y + position[0] * s + position[1] * c,
                angle: parent.angle + angle
            )
            if node.name.hasPrefix("tmo_") &&
               (node.position != nil || node.positionRelative != nil) {
                result.append(Marker(id: result.count, name: node.name,
                                     x: world.x, y: world.y,
                                     goal: node.goalRaw == "1"))
            }
            for child in node.children { visit(child, parent: world) }
        }
        visit(document.root, parent: Transform(x: 0, y: 0, angle: 0))
        return result
    }

    var body: some View {
        GeometryReader { geometry in
            let items = markers
            let xs = items.map(\.x)
            let ys = items.map(\.y)
            let minX = xs.min() ?? 0
            let maxX = xs.max() ?? 1
            let minY = ys.min() ?? 0
            let maxY = ys.max() ?? 1
            let spanX = max(maxX - minX, 0.001)
            let spanY = max(maxY - minY, 0.001)
            let inset = 26.0
            let width = max(geometry.size.width - 2 * inset, 1)
            let height = max(geometry.size.height - 2 * inset, 1)
            let scale = min(width / spanX, height / spanY)
            let offsetX = (geometry.size.width - spanX * scale) / 2
            let offsetY = (geometry.size.height - spanY * scale) / 2

            ZStack {
                Rectangle().fill(.black.opacity(0.05))
                ForEach(items) { item in
                    Circle()
                        .fill(item.goal ? Color.orange : Color.blue)
                        .frame(width: item.goal ? 11 : 7, height: item.goal ? 11 : 7)
                        .position(
                            x: offsetX + (item.x - minX) * scale,
                            y: geometry.size.height - offsetY - (item.y - minY) * scale
                        )
                        .accessibilityLabel("\(item.name), X \(item.x), Y \(item.y)\(item.goal ? ", goal" : "")")
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .frame(height: 280)
        .accessibilityElement(children: .contain)
    }
}
