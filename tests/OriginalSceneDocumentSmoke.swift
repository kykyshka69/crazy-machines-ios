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
        // Original PC scenes may position an object exclusively via POSREL.
        var relativeOnlyRaw = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        var relativeRoot = relativeOnlyRaw["root"] as! [String: Any]
        var relativeChildren = relativeRoot["children"] as! [[String: Any]]
        relativeChildren[0].removeValue(forKey: "position")
        relativeChildren[0]["fields"] = ["POSREL 0.25, -0.5, 0"]
        relativeRoot["children"] = relativeChildren
        relativeOnlyRaw["root"] = relativeRoot
        let relativeOnlyDoc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: relativeOnlyRaw))
        precondition(relativeOnlyDoc.root.positionedObjectCount == 1)
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
        contactSession.configurePhysicsRoles([
            "object-0": .fixed,
            "object-1": .sensor,
            "missing": .fixed
        ])
        precondition(contactSession.physicsRole(for: "object-0") == .fixed)
        precondition(contactSession.physicsRole(for: "object-1") == .sensor)
        precondition(contactSession.physicsRole(for: "missing") == .movable)
        precondition(contactSession.physicsRoles.count == 2)
        contactSession.configurePhysicsRoles(["object-0": .movable])
        precondition(contactSession.physicsRole(for: "object-0") == .movable)
        precondition(contactSession.physicsRole(for: "object-1") == .movable)
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
        // One first-contact reaction plus two every-contact reactions.
        precondition(contactSession.drainActions().count == 3)
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
        precondition(contactSession.schedule(.impulse(x: 0, y: 5, z: 0),
                                             from: "object-0", after: 1.5))
        precondition(!contactSession.schedule(.activate("unknown"),
                                              from: "object-0", after: 1))
        contactSession.advance(by: 1)
        precondition(contactSession.resolveActions().isEmpty)
        contactSession.pause()
        contactSession.advance(by: 10)
        precondition(contactSession.resolveActions().isEmpty)
        contactSession.resume()
        contactSession.advance(by: 0.5)
        let delayed = contactSession.resolveActions()
        precondition(delayed.count == 1)
        precondition(delayed[0].sourceID == "object-0")
        precondition(contactSession.scheduledActions.isEmpty)
        precondition(contactSession.resolveActions().isEmpty)
        // One-way manual input activates a chain without an initial collision.
        contactSession.reset()
        contactSession.configureReactions([
            .init(objectID: "object-0", trigger: .firstContact,
                  action: .activate("object-1")),
            .init(objectID: "object-1", trigger: .firstContact,
                  action: .impulse(x: 0, y: 6, z: 0))
        ])
        precondition(!contactSession.triggerObject("object-0")) // not running
        contactSession.start()
        precondition(contactSession.triggerObject("object-0"))
        precondition(!contactSession.triggerObject("object-0")) // once per run
        precondition(!contactSession.triggerObject("missing"))
        let chain = contactSession.resolveActions()
        precondition(chain.count == 1 && chain[0].sourceID == "object-1")
        precondition(contactSession.activatedObjectIDs == Set(["object-0", "object-1"]))
        precondition(contactSession.recentContacts.isEmpty)
        contactSession.pause()
        precondition(!contactSession.triggerObject("object-0"))
        contactSession.reset()
        precondition(contactSession.activatedObjectIDs.isEmpty)
        // Batch regression: 50 repeated physics interactions must preserve
        // every configured every-contact reaction without duplicate activation.
        contactSession.reset()
        contactSession.configureReactions([
            .init(objectID: "object-0", trigger: .everyContact,
                  action: .impulse(x: 1, y: 0, z: 0))
        ])
        contactSession.start()
        for index in 0..<50 {
            contactSession.recordContact("object-0", "object-1",
                                         impulse: Double(index + 1))
        }
        precondition(contactSession.recentContacts.count == 50)
        precondition(contactSession.contactCounts["object-0|object-1"] == 50)
        precondition(contactSession.activations.count == 2)
        let fiftyActions = contactSession.resolveActions()
        precondition(fiftyActions.count == 50)
        precondition(fiftyActions.allSatisfy { $0.sourceID == "object-0" })
        precondition(contactSession.resolveActions().isEmpty)
        // Directed cross-object impulse: ten independent behavior checks.
        contactSession.reset()
        contactSession.configureReactions([
            .init(objectID: "object-0", trigger: .firstContact,
                  action: .impulseTarget(id: "object-1", x: 2, y: 3, z: 4)),
            .init(objectID: "object-0", trigger: .firstContact,
                  action: .impulseTarget(id: "unknown", x: 1, y: 0, z: 0)),
            .init(objectID: "object-0", trigger: .firstContact,
                  action: .impulseTarget(id: "object-1", x: .infinity, y: 0, z: 0)),
            .init(objectID: "object-0", trigger: .firstContact,
                  action: .impulseTarget(id: "object-1", x: 1001, y: 0, z: 0))
        ])
        precondition(contactSession.reactionRules.count == 1) // invalid targets/vectors rejected
        precondition(!contactSession.schedule(.impulseTarget(id: "object-1", x: 1, y: 0, z: 0),
                                              from: "object-0", after: 0)) // not running
        contactSession.start()
        precondition(!contactSession.schedule(.impulseTarget(id: "unknown", x: 1, y: 0, z: 0),
                                              from: "object-0", after: 0))
        precondition(!contactSession.schedule(.impulseTarget(id: "object-1", x: .nan, y: 0, z: 0),
                                              from: "object-0", after: 0))
        precondition(!contactSession.schedule(.impulseTarget(id: "object-1", x: 1001, y: 0, z: 0),
                                              from: "object-0", after: 0))
        precondition(contactSession.triggerObject("object-0"))
        let directed = contactSession.resolveActions()
        precondition(directed.count == 1 && directed[0].sourceID == "object-0")
        precondition(directed[0].action == .impulseTarget(id: "object-1", x: 2, y: 3, z: 4))
        precondition(contactSession.activatedObjectIDs == Set(["object-0"]))
        precondition(contactSession.resolveActions().isEmpty)
        precondition(contactSession.schedule(.impulseTarget(id: "object-1", x: 0, y: 8, z: 0),
                                             from: "object-0", after: 0.25))
        contactSession.advance(by: 0.25)
        precondition(contactSession.resolveActions().map(\.action) ==
                     [.impulseTarget(id: "object-1", x: 0, y: 8, z: 0)])
        contactSession.reset()
        precondition(contactSession.scheduledActions.isEmpty)
        // Player-operated switch can be pressed repeatedly after collisions.
        contactSession.reset()
        contactSession.configureReactions([
            .init(objectID: "object-0", trigger: .firstContact,
                  action: .impulseTarget(id: "object-1", x: 0, y: 8, z: 0))
        ])
        precondition(!contactSession.pressObject("object-0")) // stopped
        contactSession.start()
        precondition(!contactSession.pressObject("unknown"))
        precondition(!contactSession.pressObject("object-1")) // no configured switch
        contactSession.recordContact("object-0", "object-1", impulse: 1)
        _ = contactSession.resolveActions()
        precondition(contactSession.pressObject("object-0"))
        precondition(contactSession.pressObject("object-0"))
        precondition(contactSession.resolveActions().count == 2)
        precondition(contactSession.activations.count == 2) // no duplicate activation
        contactSession.pause()
        precondition(!contactSession.pressObject("object-0"))
        contactSession.resume()
        precondition(contactSession.pressObject("object-0"))
        precondition(contactSession.resolveActions().count == 1)
        // Contact-triggered delayed rules now run end-to-end without manual
        // calls to schedule(). They must respect pause and simulation time.
        contactSession.reset()
        contactSession.configureReactions([
            .init(objectID: "object-0", trigger: .firstContact,
                  action: .impulse(x: 4, y: 0, z: 0), delay: 0.75),
            .init(objectID: "object-1", trigger: .firstContact,
                  action: .activate("object-0"), delay: .infinity)
        ])
        precondition(contactSession.reactionRules.count == 1)
        contactSession.start()
        contactSession.recordContact("object-0", "object-1", impulse: 1)
        precondition(contactSession.scheduledActions.count == 1)
        precondition(contactSession.resolveActions().isEmpty)
        contactSession.advance(by: 0.5)
        precondition(contactSession.resolveActions().isEmpty)
        contactSession.pause()
        contactSession.advance(by: 10)
        contactSession.resume()
        contactSession.advance(by: 0.25)
        let contactTriggered = contactSession.resolveActions()
        precondition(contactTriggered.count == 1)
        precondition(contactTriggered[0].sourceID == "object-0")
        precondition(contactSession.scheduledActions.isEmpty)
        contactSession.reset()
        precondition(contactSession.activations.isEmpty)
        precondition(contactSession.scheduledActions.isEmpty)
        precondition(contactSession.contactedGoalObjectIDs.isEmpty)
        print("Original scene document decoding: OK")
    }
}
