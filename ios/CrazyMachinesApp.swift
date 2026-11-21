import SwiftUI

/// Player-facing entry point. Original PC menu artwork has not yet been
/// integrated; this is a functional iPhone navigation screen, not a claim
/// that the Windows splash or original menu has been reproduced.
@main
struct CrazyMachinesApp: App {
    var body: some Scene {
        WindowGroup {
            CMGameHomeView()
        }
    }
}

private struct CMGameHomeView: View {
    @State private var showLevels = false
    @State private var showResources = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.10, blue: 0.17),
                             Color(red: 0.15, green: 0.20, blue: 0.29)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()
                    Image(systemName: "gearshape.2.fill")
                        .font(.system(size: 74, weight: .light))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Text("CRAZY MACHINES")
                        .font(.system(size: 35, weight: .heavy, design: .rounded))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .foregroundStyle(.white)
                    Text("iPhone edition — in development")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Button {
                        showLevels = true
                    } label: {
                        Label("Play", systemImage: "play.fill")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .accessibilityIdentifier("cm.menu.play")

                    Button {
                        showResources = true
                    } label: {
                        Label("Game files", systemImage: "archivebox")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .accessibilityIdentifier("cm.menu.files")
                    Spacer()
                    Text("Original PC artwork and gameplay are not yet fully integrated.")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(28)
                .frame(maxWidth: 520)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showLevels) {
                CMOriginalLevelBrowserView()
            }
            .navigationDestination(isPresented: $showResources) {
                CMOriginalResourcesView()
            }
        }
    }
}
