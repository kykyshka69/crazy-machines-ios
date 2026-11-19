import SwiftUI

@main
struct CrazyMachinesApp: App {
 var body: some Scene {
  WindowGroup {
   TabView {
    CMOriginalResourcesView()
     .tabItem { Label("Original files",systemImage:"archivebox") }
    CMPlaygroundView()
     .tabItem { Label("Playground",systemImage:"circle.hexagongrid") }
    CMSceneView()
     .ignoresSafeArea()
     .tabItem { Label("3D Preview",systemImage:"cube") }
   }
  }
 }
}
