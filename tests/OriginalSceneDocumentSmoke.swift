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
        print("Original scene document decoding: OK")
    }
}
