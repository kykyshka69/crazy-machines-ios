import Foundation

#if DEBUG && targetEnvironment(simulator)
/// An opt-in LOCAL screenshot path for the owner's private, copyrighted
/// Crazy Machines resources. No data, screenshots or private pack is ever
/// uploaded to public GitHub Actions. The runner reads this status file
/// directly from its local iPhone Simulator sandbox.
enum CMPrivateSimulatorCapture {
    static let launchArgument = "--cm-private-capture-level-1"
    static let statusFilename = "cm-private-original-level-capture.json"

    static func record(
        state: String,
        message: String,
        level: Int? = nil,
        title: String? = nil,
        originalMeshCount: Int? = nil,
        referencedModelCount: Int? = nil,
        cameraReady: Bool? = nil
    ) {
        guard ProcessInfo.processInfo.arguments.contains(launchArgument) else { return }
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask)[0]
        guard (try? FileManager.default.createDirectory(
            at: support, withIntermediateDirectories: true)) != nil else { return }
        let file = support.appendingPathComponent(statusFilename)
        var details: [String: Any] = [
            "state": state, "message": message,
            "source": "real private CMASSET1 pack; no synthetic CI fixture",
            "generatedBy": "iOS SceneKit app inside the simulator"
        ]
        if let level { details["level"] = level }
        if let title { details["title"] = title }
        if let originalMeshCount { details["originalMeshCount"] = originalMeshCount }
        if let referencedModelCount {
            details["referencedModelCount"] = referencedModelCount
        }
        if let cameraReady { details["cameraReady"] = cameraReady }
        if let data = try? JSONSerialization.data(
            withJSONObject: details, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: file, options: .atomic)
        }
    }
}
#endif
