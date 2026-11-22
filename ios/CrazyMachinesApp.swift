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
        // Filenames alone are not proof of usable original geometry.
        // Parse each referenced UCM before offering Quick Play so a damaged
        // original asset pack cannot open a blank first puzzle.
        let modelNames = CMOriginalModelResolver.allModelNames(in: document.root)
        let readiness = CMOriginalAssetAudit.inspect(
            modelNames: modelNames, directory: assetDirectory
        )
        guard readiness.allReady else { return false }
        quickPlaySelection = OriginalQuickPlaySelection(document: document)
        return true
    }

    @State private var openingOriginalLevel = false
    @State private var showLevels = false
    @State private var quickPlaySelection: OriginalQuickPlaySelection?
    @State private var showResources = false
    @State private var originalBackdrop: UIImage?
    @State private var originalStartButton: UIImage?
    @State private var hasOriginalStartscreenMeshes = false
    @State private var importedOriginalAssetCount = 0
    @State private var bundledOriginalAssetsChecked = false
    // Start disabled on the very first rendered frame when a private game
    // pack is bundled; otherwise XCTest can tap Play before onAppear starts
    // the asynchronous verification and reproduce a blank first puzzle.
    @State private var installingBundledOriginalAssets =
        Bundle.main.url(forResource: "CrazyMachines_Original_102Levels",
                        withExtension: "cmassets") != nil
    @State private var bundledAssetError: String?

    /// Play should not synchronously parse every original UCM on the
    /// SwiftUI thread. Genuine imported level 1 can reference dozens of
    /// files, and its full integrity audit is intentionally strict.
    private func openOriginalLevelFromPlay() {
        guard !openingOriginalLevel, !installingBundledOriginalAssets else { return }
        openingOriginalLevel = true
        let sceneURL = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OriginalScenes/level-001.json")
        let models = assetDirectory
        Task { @MainActor in
            // Pass only sendable bytes back to the UI. Validate the real
            // document and every referenced model off-main, then decode
            // the small JSON once more to present the verified level.
            let approved = await Task.detached(priority: .userInitiated) { () -> Data? in
                guard let data = try? Data(contentsOf: sceneURL),
                      let document = try? CMOriginalSceneDocument.read(data) else { return nil }
                let names = CMOriginalModelResolver.allModelNames(in: document.root)
                guard CMOriginalAssetAudit.inspect(
                    modelNames: names, directory: models
                ).allReady else { return nil }
                return data
            }.value
            openingOriginalLevel = false
            if let approved,
               let document = try? CMOriginalSceneDocument.read(approved) {
                quickPlaySelection = OriginalQuickPlaySelection(document: document)
            } else {
                // Missing or invalid private assets still route to the
                // original-level browser; never synthesize an imitation.
                showLevels = true
            }
        }
    }

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

    /// The private original game pack can contain hundreds of UCM/TGA files.
    /// Install and validate it off the main thread so the first iPhone frame
    /// appears immediately even when the user's pack is tens of megabytes.
    private func installBundledAssetsIfNeeded() {
        guard !bundledOriginalAssetsChecked else { return }
        bundledOriginalAssetsChecked = true
        guard let pack = Bundle.main.url(
            forResource: "CrazyMachines_Original_102Levels",
            withExtension: "cmassets"
        ) else { return }

        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let modelDirectory = support.appendingPathComponent(
            "OriginalGame", isDirectory: true)
        let firstScene = support.appendingPathComponent(
            "OriginalScenes/level-001.json")
        installingBundledOriginalAssets = true
        bundledAssetError = nil
        Task { @MainActor in
            do {
                try await Task.detached(priority: .userInitiated) {
                    // A scene JSON alone does not prove the actual meshes
                    // were installed. Parse all referenced genuine UCMs.
                    if let saved = try? Data(contentsOf: firstScene),
                       let document = try? CMOriginalSceneDocument.read(saved) {
                        let names = CMOriginalModelResolver.allModelNames(in: document.root)
                        if CMOriginalAssetAudit.inspect(
                            modelNames: names, directory: modelDirectory
                        ).allReady {
                            return
                        }
                    }
                    let data = try Data(contentsOf: pack, options: .mappedIfSafe)
                    _ = try CMOriginalAssetPackImporter.install(data)
                }.value
                loadOriginalMenuArt()
            } catch {
                bundledAssetError = "Bundled original resources could not be installed: \(error.localizedDescription)"
            }
            installingBundledOriginalAssets = false
            recordPrivateSimulatorCaptureIfRequested()
        }
    }

    /// Private Simulator capture launches must inspect the COMPLETED import,
    /// not report a false failure while the background install is running.
    private func recordPrivateSimulatorCaptureIfRequested() {
        #if DEBUG && targetEnvironment(simulator)
        guard ProcessInfo.processInfo.arguments.contains(
            CMPrivateSimulatorCapture.launchArgument
        ) else { return }
        if Bundle.main.url(
            forResource: "CrazyMachines_Original_102Levels",
            withExtension: "cmassets"
        ) == nil {
            CMPrivateSimulatorCapture.record(
                state: "missing-private-pack",
                message: "The real .cmassets was not bundled into the simulator app.")
        } else if !launchOriginalLevelIfReady() {
            CMPrivateSimulatorCapture.record(
                state: "cannot-open-original-level-1",
                message: bundledAssetError ??
                    "The imported level-001.json or its original UCM models could not be loaded.")
        }
        #endif
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
                        openOriginalLevelFromPlay()
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
                    .disabled(installingBundledOriginalAssets || openingOriginalLevel)

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
                    .disabled(installingBundledOriginalAssets || openingOriginalLevel)
                    Spacer()
                    if openingOriginalLevel {
                        ProgressView("Checking original 3D models…")
                            .tint(.white)
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("cm.original.level-checking")
                    }
                    if installingBundledOriginalAssets {
                        ProgressView("Installing original PC models and levels…")
                            .tint(.white)
                            .foregroundStyle(.white)
                            .accessibilityIdentifier("cm.original.pack-installing")
                    }
                    if let bundledAssetError {
                        Text(bundledAssetError)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
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
            .onAppear {
                #if DEBUG && targetEnvironment(simulator)
                do {
                    try CMOriginalCISimulatorFixture.handleLaunchArguments()
                } catch {
                    bundledAssetError = "CI synthetic scene import failed: \(error.localizedDescription)"
                }
                #endif
                installBundledAssetsIfNeeded()
                loadOriginalMenuArt()
                if Bundle.main.url(
                    forResource: "CrazyMachines_Original_102Levels",
                    withExtension: "cmassets"
                ) == nil {
                    recordPrivateSimulatorCaptureIfRequested()
                }
            }
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
