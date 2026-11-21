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
        // Imported PC metadata must be bounded before the renderer traverses it.
        // Exercise malformed references without requiring proprietary game assets.
        for (key, value) in [
            ("models", [String(repeating: "x", count: 513)] as Any),
            ("models", Array(repeating: "model", count: 257) as Any),
            ("models", ["to_board\nmalformed"] as Any),
            ("rotation_raw", String(repeating: "r", count: 4097) as Any),
            ("goal_raw", String(repeating: "g", count: 257) as Any)
        ] {
            var malformed = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
            var malformedRoot = malformed["root"] as! [String: Any]
            var malformedChildren = malformedRoot["children"] as! [[String: Any]]
            malformedChildren[0][key] = value
            malformedRoot["children"] = malformedChildren
            malformed["root"] = malformedRoot
            let bytes = try JSONSerialization.data(withJSONObject: malformed)
            do {
                _ = try CMOriginalSceneDocument.read(bytes)
                preconditionFailure("Oversized original scene metadata was accepted: \(key)")
            } catch CMOriginalSceneDocument.SceneError.invalid {
                // Expected: reject malformed original scene metadata.
            }
        }
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
        // The original 3DO may sit below a helper transform rather than
        // directly under its tmo_ owner. Do not report its mesh as missing.
        var nestedRaw = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        var nestedRoot = nestedRaw["root"] as! [String: Any]
        var nestedChildren = nestedRoot["children"] as! [[String: Any]]
        nestedChildren[0]["models"] = [String]()
        nestedChildren[0]["children"] = [[
            "name": "transform", "fields": [],
            "children": [["name": "3DO to_board", "fields": [], "children": []]]
        ]]
        nestedRoot["children"] = nestedChildren
        nestedRaw["root"] = nestedRoot
        let nestedDoc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: nestedRaw))
        precondition(nestedDoc.gameplayInventory.objectsWithoutModels.isEmpty)
        let nestedSession = CMOriginalGameplaySession(document: nestedDoc)
        precondition(nestedSession.objects.count == 1)
        precondition(nestedSession.objects[0].models == ["to_board"])
        // The same PC mesh may appear with different filename casing in
        // metadata and in the 3DO tree; register it only once.
        nestedChildren[0]["models"] = ["TO_BOARD", "to_board"]
        nestedRoot["children"] = nestedChildren
        nestedRaw["root"] = nestedRoot
        let mixedCaseDoc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: nestedRaw))
        let mixedCaseSession = CMOriginalGameplaySession(document: mixedCaseDoc)
        precondition(mixedCaseSession.objects[0].models == ["TO_BOARD"])
        // A model inside a separate nested tmo_ cannot be attributed to
        // the parent object.
        // Remove the earlier metadata-only model references: this fixture
        // tests ownership when the parent has no models of its own.
        nestedChildren[0]["models"] = [String]()
        nestedChildren[0]["children"] = [[
            "name": "tmo_child", "fields": [],
            "children": [["name": "3DO to_board", "fields": [], "children": []]]
        ]]
        nestedRoot["children"] = nestedChildren
        nestedRaw["root"] = nestedRoot
        let nestedObjectDoc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: nestedRaw))
        precondition(nestedObjectDoc.gameplayInventory.objectsWithoutModels["tmo_board"] == 1)
        precondition(nestedObjectDoc.gameplayInventory.objectsWithoutModels["tmo_child"] == nil)
        let separateSession = CMOriginalGameplaySession(document: nestedObjectDoc)
        precondition(separateSession.objects.count == 2)
        precondition(separateSession.objects[0].models.isEmpty)
        precondition(separateSession.objects[1].models == ["to_board"])
        precondition(separateSession.objects[1].parentID == "object-0")
        precondition(CMOriginalModelResolver.modelNames(in: nestedObjectDoc.root.children[0]).isEmpty)
        precondition(CMOriginalModelResolver.modelNames(in: nestedObjectDoc.root.children[0].children[0]) == ["to_board"])
        precondition(CMOriginalModelResolver.allModelNames(in: nestedObjectDoc.root) == ["to_board"])
        precondition(CMOriginalModelResolver.allModelNames(in: mixedCaseDoc.root) == ["TO_BOARD"])
        // The level-wide inventory must include sibling objects and root
        // references, while the per-object inventory stays owner-scoped.
        var siblingsRaw = try JSONSerialization.jsonObject(with: Data(json.utf8)) as! [String: Any]
        var siblingsRoot = siblingsRaw["root"] as! [String: Any]
        var siblingsChildren = siblingsRoot["children"] as! [[String: Any]]
        siblingsRoot["models"] = ["level_mesh"]
        siblingsChildren.append([
            "name": "tmo_wheel", "fields": [],
            "children": [["name": "3DO to_wheel", "fields": [], "children": []]]
        ])
        siblingsRoot["children"] = siblingsChildren
        siblingsRaw["root"] = siblingsRoot
        let siblingsDoc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: siblingsRaw))
        precondition(CMOriginalModelResolver.allModelNames(in: siblingsDoc.root) ==
                     ["level_mesh", "to_board", "to_wheel"])
        precondition(CMOriginalModelResolver.modelNames(in: siblingsDoc.root.children[0]) ==
                     ["to_board"])


        // Verify the actual PC scene names resolve to the shared wall/ball
        // meshes and case-insensitive original filenames. Fixtures are empty
        // files because AssetIndex tests path resolution, not UCM decoding.
        let assetDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("cm-resolver-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: assetDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: assetDir) }
        for name in ["wall.ucm", "ball.ucm", "crate.UCM", "zone.UCM",
                     "belt_conveyor_roll2.ucm"] {
            try Data("UCM1".utf8).write(to: assetDir.appendingPathComponent(name))
        }
        let originalMeshes = CMOriginalModelResolver.AssetIndex(directory: assetDir)
        for original in ["to_wall_concrete", "to_wall_cork",
                         "to_wall_bricks", "to_wall_metal",
                         "to_wall_schist", "to_wall_paper"] {
            precondition(originalMeshes.resolve(original)?.lastPathComponent == "wall.ucm")
        }
        for original in ["to_ball_tennis", "to_ball_billard"] {
            precondition(originalMeshes.resolve(original)?.lastPathComponent == "ball.ucm")
        }
        precondition(originalMeshes.resolve("to_crate")?.lastPathComponent == "crate.UCM")
        precondition(originalMeshes.resolve("to_zone")?.lastPathComponent == "zone.UCM")
        precondition(originalMeshes.resolve("to_belt_conveyer_roll_small")?.lastPathComponent
                     == "belt_conveyor_roll2.ucm")
        precondition(originalMeshes.resolve("to_wall_brick")?.lastPathComponent == "wall.ucm")
        precondition(originalMeshes.resolve("to_wall_wall_paper")?.lastPathComponent == "wall.ucm")
        precondition(originalMeshes.resolve("to_wall_nonexistent") == nil)
        precondition(originalMeshes.resolve("../wall.ucm") == nil)

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
        // Authentic electrical switches are distinct original objects.
        // Their lever positions are gameplay state, not an assertion that
        // the original circuit is wired or the motor has electric power.
        var switchRaw = try JSONSerialization.jsonObject(
            with: Data(json.utf8)) as! [String: Any]
        var switchRoot = switchRaw["root"] as! [String: Any]
        switchRoot["children"] = [
            ["name": "tmo_power_switch", "fields": [],
             "children": [["name": "tmo_power_switch_lever",
                           "fields": [], "children": []]]],
            ["name": "tmo_power_switch", "fields": [], "children": []],
            ["name": "tmo_board", "fields": [], "children": []]
        ] as [[String: Any]]
        switchRaw["root"] = switchRoot
        let switchDoc = try CMOriginalSceneDocument.read(
            JSONSerialization.data(withJSONObject: switchRaw))
        var switches = CMOriginalGameplaySession(document: switchDoc)
        precondition(switches.objects.map(\.type) == [
            "tmo_power_switch", "tmo_power_switch_lever",
            "tmo_power_switch", "tmo_board"
        ])
        precondition(switches.toggleOriginalSwitch("object-0") == nil)
        switches.start()
        precondition(switches.toggleOriginalSwitch("object-0") == true)
        precondition(switches.originalSwitchStates == ["object-0": true])
        precondition(switches.toggleOriginalSwitch("object-2") == true)
        precondition(switches.originalSwitchStates.count == 2)
        precondition(switches.toggleOriginalSwitch("object-0") == false)
        precondition(switches.originalSwitchStates == ["object-2": true])
        precondition(switches.toggleOriginalSwitch("object-1") == nil)
        precondition(switches.toggleOriginalSwitch("object-3") == nil)
        precondition(switches.toggleOriginalSwitch("not-an-object") == nil)
        switches.pause()
        precondition(switches.toggleOriginalSwitch("object-2") == nil)
        precondition(switches.originalSwitchStates == ["object-2": true])
        switches.resume()
        precondition(switches.toggleOriginalSwitch("object-2") == false)
        precondition(switches.originalSwitchStates.isEmpty)
        precondition(switches.toggleOriginalSwitch("object-2") == true)
        switches.stop()
        precondition(switches.toggleOriginalSwitch("object-2") == nil)
        switches.start()
        precondition(switches.originalSwitchStates.isEmpty)
        precondition(switches.toggleOriginalSwitch("object-0") == true)
        switches.reset()
        precondition(switches.originalSwitchStates.isEmpty)

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
