import Foundation

@main
enum OriginalSceneDocumentSmoke {
    static func main() throws {
        let json = """
        {
          "schema":"crazy-machines-original-scene-v1",
          "index":1,
          "title":"Original level",
          "scene_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "root":{
            "name":"level","fields":["POSREL 0, 0, 0"],
            "position_relative":[0,0,0],
            "children":[{
              "name":"tmo_board",
              "fields":["POS 1, 2, 3","POSREL 0.25, -0.5, 0","ROT xyz 0, 0, 1"],
              "position":[1,2,3],
              "position_relative":[0.25,-0.5,0],
              "rotation_raw":"xyz 0, 0, 1",
              "models":["to_board"],
              "children":[{"name":"3DO to_board","fields":[],"children":[]}]
            }]
          }
        }
        """
        let doc = try CMOriginalSceneDocument.read(Data(json.utf8))
        precondition(doc.root.positionRelative == [0, 0, 0])
        let board = doc.root.children[0]
        precondition(board.position == [1, 2, 3])
        precondition(board.positionRelative == [0.25, -0.5, 0])
        precondition(board.rotationRaw == "xyz 0, 0, 1")
        precondition(board.models == ["to_board"])
        precondition(board.originalFieldValues["POS"] == ["1, 2, 3"])
        precondition(board.originalFieldValues["POSREL"] == ["0.25, -0.5, 0"])
        precondition(board.originalFieldValues["ROT"] == ["xyz 0, 0, 1"])
        precondition(doc.root.objectCount == 1)
        precondition(doc.root.positionedObjectCount == 1)
        precondition(doc.gameplayInventory.objectTypes["tmo_board"] == 1)
        precondition(doc.gameplayInventory.goalObjectTypes.isEmpty)
        precondition(doc.gameplayInventory.objectsWithoutModels.isEmpty)
        precondition(doc.gameplayInventory.objectsWithoutPosition.isEmpty)
        var session = CMOriginalGameplaySession(document: doc)
        precondition(session.objects.count == 1)
        precondition(session.objects[0].id == "object-0")
        precondition(session.objects[0].type == "tmo_board")
        precondition(session.objects[0].models == ["to_board"])
        precondition(session.objects[0].position == [0.25, -0.5, 0])
        precondition(session.objects[0].parentID == nil)
        precondition(session.annotatedGoalObjects.isEmpty)
        precondition(session.phase == .ready)
        session.advance(by: 10)
        precondition(session.elapsedSimulationTime == 0)
        session.start()
        session.advance(by: 0.5)
        session.pause()
        session.advance(by: 10)
        precondition(session.elapsedSimulationTime == 0.5)
        session.resume()
        session.advance(by: 0.25)
        precondition(session.elapsedSimulationTime == 0.75)
        // A one-object scene cannot register self-collisions.
        session.recordContact("object-0", "object-0", impulse: 2)
        session.recordContact("object-0", "missing", impulse: 2)
        precondition(session.recentContacts.isEmpty)
        session.stop()
        session.reset()
        precondition(session.phase == .ready && session.elapsedSimulationTime == 0)
        // Two distinct imported objects generate two activation transitions
        // on first contact, but repeated contacts do not re-activate them.
        var raw = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        var root = raw["root"] as! [String: Any]
        var children = root["children"] as! [[String: Any]]
        children.append([
            "name": "tmo_target",
            "fields": ["GOAL 1", "POS 4, 5, 6"],
            "position": [4, 5, 6],
            "goal_raw": "1",
            "models": ["to_target"],
            "children": []
        ])
        root["children"] = children
        raw["root"] = root
        let twoObjectDoc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: raw))
        var contactSession = CMOriginalGameplaySession(document: twoObjectDoc)
        precondition(contactSession.objects.count == 2)
        precondition(contactSession.annotatedGoalObjects.map(\.id) == ["object-1"])
        contactSession.configureReactions([
            .init(objectID: "object-0", trigger: .firstContact,
                  action: .impulse(x: 1, y: 0, z: 0)),
            .init(objectID: "object-1", trigger: .everyContact,
                  action: .impulse(x: 0, y: 2, z: 0)),
            .init(objectID: "missing", trigger: .everyContact,
                  action: .impulse(x: 0, y: 1, z: 0)),
            .init(objectID: "object-0", trigger: .everyContact,
                  action: .impulse(x: .infinity, y: 0, z: 0))
        ])
        precondition(contactSession.reactionRules.count == 2)
        contactSession.start()
        contactSession.recordContact("object-1", "object-0", impulse: 3)
        precondition(contactSession.recentContacts.count == 1)
        precondition(contactSession.activations.count == 2)
        precondition(contactSession.contactedGoalObjectIDs == Set(["object-1"]))
        contactSession.recordContact("object-0", "object-1", impulse: 2)
        precondition(contactSession.contactCounts["object-0|object-1"] == 2)
        precondition(contactSession.drainActions().count == 1)
        precondition(contactSession.activations.count == 2)
        // Explicit activation links can drive a second object's impulse.
        contactSession.reset()
        contactSession.configureReactions([
            .init(objectID: "object-0", trigger: .firstContact,
                  action: .activate("object-1")),
            .init(objectID: "object-1", trigger: .firstContact,
                  action: .impulse(x: 0, y: 3, z: 0)),
            .init(objectID: "object-1", trigger: .firstContact,
                  action: .activate("object-0"))
        ])
        contactSession.start()
        // A real contact activates object-0; the configured link activates
        // object-1, and the reverse link must not form an infinite cycle.
        // Both endpoints normally activate on contact, so first prove that
        // explicit activation chains can be resolved without contact.
        contactSession.recordContact("object-0", "object-1", impulse: 1)
        let resolved = contactSession.resolveActions()
        precondition(resolved.count == 1)
        precondition(resolved[0].sourceID == "object-1")
        precondition(contactSession.resolveActions().isEmpty)
        contactSession.reset()
        precondition(contactSession.activations.isEmpty)
        precondition(contactSession.contactedGoalObjectIDs.isEmpty)
        print("Original scene document decoding: OK")
    }
}
