import SwiftUI

@main
struct CrazyMachinesApp: App {
 @State private var selectedTab = 2

 var body: some Scene {
  WindowGroup {
   TabView(selection: $selectedTab) {
    CMOriginalResourcesView()
     .tabItem { Label("Original files",systemImage:"archivebox") }
     .tag(0)
    CMOriginalLevelBrowserView()
     .tabItem { Label("Original levels",systemImage:"list.bullet.rectangle") }
     .tag(1)
    CMPlaygroundView()
     .tabItem { Label("Playground",systemImage:"circle.hexagongrid") }
     .tag(2)
    CMSceneView()
     .ignoresSafeArea()
     .tabItem { Label("3D Preview",systemImage:"cube") }
     .tag(3)
   }
  }
 }
}
