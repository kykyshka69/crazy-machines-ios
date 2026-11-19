import SwiftUI

@main
struct CrazyMachinesApp: App {
 var body: some Scene {
  WindowGroup {
   TabView {
    CMOriginalResourcesView()
     .tabItem { Label("Original files",systemImage:"archivebox") }
    CMOriginalLevelBrowserView()
     .tabItem { Label("Original levels",systemImage:"list.bullet.rectangle") }
    CMPlaygroundView()
     .tabItem { Label("Playground",systemImage:"circle.hexagongrid") }
    CMSceneView()
     .ignoresSafeArea()
     .tabItem { Label("3D Preview",systemImage:"cube") }
   }
  }
 }
}
