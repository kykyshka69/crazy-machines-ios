import SwiftUI

/// The iOS application opens the user's original PC game resources and levels.
/// Synthetic playgrounds and rendering smoke tests are developer-only code,
/// never presented as the Crazy Machines game.
@main
struct CrazyMachinesApp: App {
    @State private var selectedTab = 1

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                CMOriginalResourcesView()
                    .tabItem { Label("Original files", systemImage: "archivebox") }
                    .tag(0)
                CMOriginalLevelBrowserView()
                    .tabItem { Label("Original levels", systemImage: "list.bullet.rectangle") }
                    .tag(1)
            }
        }
    }
}
