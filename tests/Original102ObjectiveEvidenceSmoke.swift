import Foundation

private struct ExportedManifest: Decodable {
    struct Level: Decodable {
        struct Goal: Decodable { let id: String; let type: String }
        struct Link: Decodable {
            let sourceID: String
            let targetID: String
            let sourceType: String
            let targetType: String
        }
        let level: Int
        let scene_sha256: String
        let goal_markers: [Goal]
        let contact_links: [Link]
    }
    let levels: [Level]
}

@main
struct Original102ObjectiveEvidenceSmoke {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            fatalError("Pass private original-102-objective-manifest.json")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let manifest = try JSONDecoder().decode(ExportedManifest.self, from: data)
        precondition(manifest.levels.count == 102)
        var totalGoals = 0
        var totalLinks = 0
        for (index, level) in manifest.levels.enumerated() {
            precondition(level.level == index + 1)
            guard var ledger = CMOriginalObjectiveEvidenceLedger(
                levelIndex: level.level,
                sceneSHA256: level.scene_sha256,
                goalMarkers: level.goal_markers.map {
                    .init(objectID: $0.id, type: $0.type)
                },
                connections: level.contact_links.map {
                    .init(sourceID: $0.sourceID, targetID: $0.targetID,
                          sourceType: $0.sourceType, targetType: $0.targetType)
                }
            ) else { fatalError("Could not index PC level \(level.level)") }
            precondition(ledger.totalMarkerCount > 0)
            precondition(!ledger.allMarkersObserved)
            precondition(!ledger.recordGoalStateChanged(
                "not-original-object", isSimulationRunning: true))
            precondition(ledger.recordPhysicalContact(
                "not-original-object", "also-unknown", isSimulationRunning: true).isEmpty)
            for link in level.contact_links {
                precondition(ledger.recordPhysicalContact(
                    link.sourceID, link.targetID,
                    isSimulationRunning: false).isEmpty)
                precondition(ledger.recordPhysicalContact(
                    link.targetID, link.sourceID,
                    isSimulationRunning: true).count == 1)
                precondition(ledger.recordPhysicalContact(
                    link.sourceID, link.targetID,
                    isSimulationRunning: true).isEmpty)
                totalLinks += 1
            }
            for goal in level.goal_markers {
                precondition(!ledger.recordGoalStateChanged(
                    goal.id, isSimulationRunning: false))
                precondition(ledger.recordGoalStateChanged(
                    goal.id, isSimulationRunning: true))
                precondition(!ledger.recordGoalStateChanged(
                    goal.id, isSimulationRunning: true))
                totalGoals += 1
            }
            precondition(ledger.allMarkersObserved)
            ledger.reset()
            precondition(!ledger.allMarkersObserved)
        }
        precondition(totalGoals == 86 && totalLinks == 80)
        print("PASS: all 102 REAL original PC level metadata plans indexed")
        print("PASS: 86 GOAL and 80 CONNECTED_TO evidence events")
        print("NOTE: synthetic event injection is NOT 102 gameplay victories")
    }
}