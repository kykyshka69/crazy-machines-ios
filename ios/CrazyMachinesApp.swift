import SwiftUI
import CoreGraphics

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
    // SwiftUI's navigationDestination(item:) requires a Hashable item.
    // Original scene documents themselves are intentionally not Hashable.
    private struct OriginalQuickPlaySelection: Identifiable, Hashable {
        let id = UUID()
        let document: CMOriginalSceneDocument

        static func == (lhs: Self, rhs: Self) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    /// The first original laboratory level exists only after importing the
    /// user's private scene pack; do not fabricate a synthetic fallback.
    private func launchOriginalLevelIfReady() -> Bool {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let sceneURL = support.appendingPathComponent("OriginalScenes/level-001.json")
        guard let data = try? Data(contentsOf: sceneURL),
              let document = try? CMOriginalSceneDocument.read(data) else { return false }
        let index = CMOriginalModelResolver.AssetIndex(directory: assetDirectory)
        let resolved = CMOriginalModelResolver.allModelNames(in: document.root)
            .contains { index.resolve($0) != nil }
        guard resolved else { return false }
        quickPlaySelection = OriginalQuickPlaySelection(document: document)
        return true
    }

    @State private var showLevels = false
    @State private var quickPlaySelection: OriginalQuickPlaySelection?
    @State private var showResources = false
    @State private var originalBackdrop: UIImage?
    @State private var originalStartButton: UIImage?
    @State private var hasOriginalStartscreenMeshes = false
    @State private var importedOriginalAssetCount = 0

    private var assetDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OriginalGame", isDirectory: true)
    }

    /// These filenames are from the audited original PC texture inventory.
    /// The PC startscreen is a 3D scene, so these are genuine menu surfaces,
    /// not a fabricated full-screen image of the original scene.
    private func loadOriginalMenuArt() {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: assetDirectory, includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        func image(_ name: String) -> UIImage? {
            let matches = files.filter {
                $0.pathExtension.lowercased() == "tga"
                    && $0.deletingPathExtension().lastPathComponent.lowercased() == name
            }
            guard matches.count == 1,
                  let data = try? Data(contentsOf: matches[0]),
                  let tga = try? CMTGATexture(data: data),
                  let provider = CGDataProvider(data: tga.rgba as CFData),
                  let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let cgImage = CGImage(width: tga.width, height: tga.height,
                      bitsPerComponent: 8, bitsPerPixel: 32,
                      bytesPerRow: tga.width * 4, space: space,
                      bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                      provider: provider, decode: nil,
                      shouldInterpolate: true, intent: .defaultIntent) else { return nil }
            return UIImage(cgImage: cgImage)
        }
        importedOriginalAssetCount = files.filter { ["ucm", "tga"].contains($0.pathExtension.lowercased()) }.count
        let index = CMOriginalModelResolver.AssetIndex(directory: assetDirectory)
        hasOriginalStartscreenMeshes = index.resolve("startscreen_chalkboard_board") != nil
            || index.resolve("startscreen_chalkboard_frame") != nil
        originalBackdrop = image("startscreen_chalk")
        originalStartButton = image("startscreen_note_start")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.06, green: 0.10, blue: 0.17),
                             Color(red: 0.15, green: 0.20, blue: 0.29)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if hasOriginalStartscreenMeshes {
                    CMOriginalStartscreen3D(assetDirectory: assetDirectory)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                } else if let originalBackdrop {
                    Image(uiImage: originalBackdrop)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .overlay(Color.black.opacity(0.45))
                        .accessibilityHidden(true)
                }

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
                        if !launchOriginalLevelIfReady() { showLevels = true }
                    } label: {
                        if let originalStartButton {
                            Image(uiImage: originalStartButton)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 320, maxHeight: 100)
                                .frame(maxWidth: .infinity)
                                .accessibilityLabel("Play")
                        } else {
                            Label("Play", systemImage: "play.fill")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
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
                    Text(importedOriginalAssetCount == 0
                         ? "Original PC resources are not installed in this iPhone app. Open Game files and import the extracted game folder."
                         : "Imported original assets: \(importedOriginalAssetCount). Original startscreen composition is still being reconstructed.")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(28)
                .frame(maxWidth: 520)
            }
            .onAppear(perform: loadOriginalMenuArt)
            .onChange(of: showResources) { _, presented in
                if !presented { loadOriginalMenuArt() }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showLevels) {
                CMOriginalLevelBrowserView()
            }
            .navigationDestination(isPresented: $showResources) {
                CMOriginalResourcesView()
            }
            .navigationDestination(item: $quickPlaySelection) { selection in
                CMOriginalQuickPlayView(
                    document: selection.document,
                    assetDirectory: assetDirectory
                )
            }
        }
    }
}
