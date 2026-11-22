import Foundation

@main
struct OriginalElementsPortableSmoke {
    static func main() throws {
        // This is small, copyright-free test syntax. Real original script
        // validation separately runs against the owner's private 72 KB FSC.
        let fixture = """
        //#FAKT_SCRIPT#
        TEMPLATES
        {
        tmo_ball_steel
        {
        BITS 1001000
        VALF 0.125
        3DO to_ball_test
        }
        tmo_bucket
        {
        BITS 1000
        VALF 0.25
        3DO to_bucket_test
        }
        tmo_zone
        {
        BITS 0
        }
        }
        """
        let catalogue = try CMOriginalElementsTemplateCatalog.parse(
            decodedBytes: Data(fixture.utf8))
        precondition(catalogue.count == 3)
        precondition(catalogue["tmo_ball_steel"]?.defaultBits == 72)
        precondition(catalogue["tmo_bucket"]?.defaultFloat == 0.25)
        let inherited = CMOriginalWindowsElementRules(
            type: "tmo_ball_steel", sceneFields: [], catalogue: catalogue)!
        precondition(inherited.effectiveBits == 72 && inherited.cameFromTemplateBits)
        let override = CMOriginalWindowsElementRules(
            type: "tmo_bucket", sceneFields: ["VALB 64", "GOAL 1"],
            catalogue: catalogue)!
        precondition(override.effectiveBits == 64 && override.hasOriginalFlagOverride)
        precondition(override.goalMarker == "1")
        let raw: [String: Any] = [
            "schema": "crazy-machines-original-scene-v1",
            "index": 4, "title": "Test script flag overrides",
            "scene_sha256": String(repeating: "a", count: 64),
            "root": ["name": "level", "fields": [], "children": [
                ["name": "level_elements", "fields": [], "children": [
                    ["name": "tmo_ball_steel", "fields": ["CONNECTED_TO 1"], "children": []],
                    ["name": "tmo_bucket", "fields": ["GOAL 1", "VALB 64"], "children": []],
                    ["name": "tmo_zone", "fields": [], "children": []]
                ]]
            ]]
        ]
        let document = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: raw))
        let session = CMOriginalGameplaySession(document: document)
        let fallback = CMOriginalPhysicsRolePlanner.roles(for: session)
        let actual = CMOriginalPhysicsRolePlanner.roles(
            for: session, originalTemplates: catalogue)
        precondition(session.objects.count == 3)
        precondition(fallback[session.objects[0].id] == .fixed)
        precondition(actual[session.objects[0].id] == .movable)
        precondition(actual[session.objects[1].id] == .fixed)
        precondition(actual[session.objects[2].id] == .sensor)
        guard var ledger = CMOriginalObjectiveEvidenceLedger(session: session) else {
            preconditionFailure("Need original GOAL and CONNECTED_TO metadata")
        }
        precondition(ledger.goalMarkers.count == 1)
        precondition(ledger.authoredConnections.count == 1)
        precondition(!ledger.allMarkersObserved)
        let ball = session.objects[0].id
        let bucket = session.objects[1].id
        precondition(ledger.recordPhysicalContact(ball, bucket,
                                                   isSimulationRunning: false).isEmpty)
        precondition(ledger.recordPhysicalContact(bucket, ball,
                                                   isSimulationRunning: true).count == 1)
        precondition(ledger.recordGoalStateChanged(bucket, isSimulationRunning: true))
        precondition(ledger.allMarkersObserved)
        ledger.reset()
        precondition(!ledger.allMarkersObserved)
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent(
            "cm-script-absent-\(UUID().uuidString)")
        precondition(CMOriginalWindowsScriptLibrary.load(directory: temp) == nil)
        do {
            _ = try CMOriginalElementsScriptDecoder.decode(Data("invalid".utf8))
            preconditionFailure("Invalid Windows script accepted")
        } catch CMOriginalElementsScriptDecoder.Error.invalidLength {}
        print("Original Windows template role merge and evidence ledger passed")
    }
}