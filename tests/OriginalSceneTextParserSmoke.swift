import Foundation

@main
struct OriginalSceneTextParserSmoke {
    static func main() throws {
        let text = """
        level
        {
          level_elements
          {
            tmo_board
            {
              POS -1.41905, -1.08718, 0.03751
              ROT xyz 0, 0, -1.57080
              UNLOCKED 1
              transform
              {
                3DO to_board
                {
                }
              }
              tmo_mount_bar
              {
                3DO to_mount
                {
                }
              }
            }
            tmo_zone
            {
              POSREL 1, 2, 3
              GOAL 1
              3DO to_zone
              {
              }
            }
          }
        }
        """
        let hash = String(repeating: "a", count: 64)
        let output = try CMOriginalSceneTextParser.export(
            text, index: 1, title: "Оригінальний рівень", sceneSHA256: hash)
        let parsed = try CMOriginalSceneDocument.read(output)
        precondition(parsed.root.objectCount == 3)
        precondition(parsed.root.goalCount == 1)
        let board = parsed.root.children[0].children[0]
        precondition(board.name == "tmo_board" && board.models == ["to_board"])
        precondition(board.position == [-1.41905, -1.08718, 0.03751])
        precondition(parsed.root.children[0].children[1].models == ["to_zone"])
        precondition(parsed.root.children[0].children[1].positionRelative == [1, 2, 3])
        for malformed in ["level\n{\n tmo_bad\n{\n}\n", "level\n{\n}\nother\n{\n}\n",
                          "level\n{\nPOS not,a,vector\n}\n", "other\n{\n}\n"] {
            do {
                _ = try CMOriginalSceneTextParser.export(
                    malformed, index: 1, title: "Level", sceneSHA256: hash)
                preconditionFailure("Accepted malformed original scene text")
            } catch {}
        }
        print("Original decrypted scene graph to validated iOS JSON: OK")
    }
}
