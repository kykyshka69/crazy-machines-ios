import SwiftUI

@main
struct CrazyMachinesApp: App {
 var body: some Scene {
  WindowGroup {
   TabView {
    CMPlaygroundView()
     .tabItem { Label("Playground",systemImage:"circle.hexagongrid") }
    CMSceneView()
     .ignoresSafeArea()
     .tabItem { Label("3D Preview",systemImage:"cube") }
   }
  }
 }
}
