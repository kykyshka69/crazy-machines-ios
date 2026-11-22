import Foundation

@main
struct OriginalSwitchContactSmoke {
    static func main() {
        let objects: [CMOriginalSwitchContactMapper.Item] = [
            .init(id: "switch-A", type: "tmo_power_switch", parentID: nil),
            .init(id: "mount-A", type: "tmo_mount_wood", parentID: "switch-A"),
            .init(id: "lever-A", type: "tmo_power_switch_lever", parentID: "mount-A"),
            .init(id: "base-A", type: "tmo_power_switch_base", parentID: "switch-A"),
            .init(id: "ball", type: "tmo_ball_iron", parentID: nil),
            .init(id: "board", type: "tmo_board", parentID: nil),
            .init(id: "switch-B", type: "tmo_power_switch", parentID: nil),
            .init(id: "lever-B", type: "tmo_power_switch_lever", parentID: "switch-B")
        ]
        var mapper = CMOriginalSwitchContactMapper(objects: objects)
        // The base can be struck, but that is not an authentic lever contact.
        precondition(mapper.beginContact("base-A", "ball", impulse: 1,
                                         aIsMovable: false, bIsMovable: true) == nil)
        precondition(mapper.beginContact("lever-A", "board", impulse: 1,
                                         aIsMovable: false, bIsMovable: false) == nil)
        precondition(mapper.beginContact("lever-A", "mount-A", impulse: 1,
                                         aIsMovable: false, bIsMovable: true) == nil)
        precondition(mapper.beginContact("lever-A", "base-A", impulse: 1,
                                         aIsMovable: false, bIsMovable: true) == nil)
        let first = mapper.beginContact("ball", "lever-A", impulse: 0.35,
                                        aIsMovable: true, bIsMovable: false)
        precondition(first == .init(switchID: "switch-A", leverID: "lever-A",
                                    strikingObjectID: "ball", strikingObjectType: "tmo_ball_iron",
                                    impulse: 0.35))
        precondition(mapper.beginContact("lever-A", "ball", impulse: 2,
                                         aIsMovable: false, bIsMovable: true) == nil)
        mapper.endContact("lever-A", "ball")
        precondition(mapper.beginContact("lever-A", "ball", impulse: 1,
                                         aIsMovable: false, bIsMovable: true) != nil)
        precondition(mapper.beginContact("lever-A", "ball", impulse: .nan,
                                         aIsMovable: false, bIsMovable: true) == nil)
        precondition(mapper.beginContact("lever-A", "missing", impulse: 1,
                                         aIsMovable: false, bIsMovable: true) == nil)
        mapper.reset()
        let next = mapper.beginContact("lever-B", "ball", impulse: 0,
                                       aIsMovable: false, bIsMovable: true)
        precondition(next?.switchID == "switch-B")
        // Neither parent-less leaves nor a nearby switch base may act as lever.
        var noLever = CMOriginalSwitchContactMapper(objects: [
            .init(id: "switch", type: "tmo_power_switch", parentID: nil),
            .init(id: "lever", type: "tmo_power_switch_lever", parentID: nil),
            .init(id: "ball", type: "tmo_ball_iron", parentID: nil)
        ])
        precondition(noLever.beginContact("lever", "ball", impulse: 1,
                                          aIsMovable: false, bIsMovable: true) == nil)
        print("Original PC switch lever-to-striker contact mapping: OK")
    }
}
