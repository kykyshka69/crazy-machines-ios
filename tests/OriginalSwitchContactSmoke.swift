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
        // The imported level can place a lever UNDER another CML mount.
        // Touch selection and physics must resolve the SAME switch owner.
        precondition(mapper.originalSwitchID(forLeverID: "lever-A") == "switch-A")
        precondition(mapper.originalSwitchID(forLeverID: "lever-B") == "switch-B")
        precondition(mapper.originalSwitchID(forLeverID: "mount-A") == nil)
        precondition(mapper.originalSwitchID(forLeverID: "base-A") == nil)
        precondition(mapper.originalSwitchID(forLeverID: "missing") == nil)
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
        precondition(first.map {
            CMOriginalSwitchContactMapper.qualifiesForExperimentalImpact($0)
        } == true)
        // Zero impulse contacts remain useful diagnostic evidence, but
        // must NOT activate the experimental switch.
        precondition(CMOriginalSwitchContactMapper
            .qualifiesForExperimentalImpact(.init(
                switchID: "switch-A", leverID: "lever-A",
                strikingObjectID: "ball", strikingObjectType: "tmo_ball_iron",
                impulse: 0)) == false)
        precondition(CMOriginalSwitchContactMapper
            .qualifiesForExperimentalImpact(.init(
                switchID: "switch-A", leverID: "lever-A",
                strikingObjectID: "ball", strikingObjectType: "tmo_ball_iron",
                impulse: -.infinity)) == false)
        precondition(mapper.consumeImpact("ball", "lever-A", impulse: 0.35,
                                         aIsMovable: true, bIsMovable: false) != nil)
        precondition(mapper.consumeImpact("lever-A", "ball", impulse: 2,
                                         aIsMovable: false, bIsMovable: true) == nil)
        precondition(mapper.beginContact("lever-A", "ball", impulse: 2,
                                         aIsMovable: false, bIsMovable: true) == nil)
        mapper.endContact("lever-A", "ball")
        precondition(mapper.beginContact("lever-A", "ball", impulse: 1,
                                         aIsMovable: false, bIsMovable: true) != nil)
        precondition(mapper.consumeImpact("lever-A", "ball", impulse: 1,
                                         aIsMovable: false, bIsMovable: true) != nil)
        precondition(mapper.consumeImpact("lever-A", "ball", impulse: 1,
                                         aIsMovable: false, bIsMovable: true) == nil)
        precondition(mapper.beginContact("lever-A", "ball", impulse: .nan,
                                         aIsMovable: false, bIsMovable: true) == nil)
        precondition(mapper.beginContact("lever-A", "missing", impulse: 1,
                                         aIsMovable: false, bIsMovable: true) == nil)
        mapper.reset()
        let next = mapper.beginContact("lever-B", "ball", impulse: 0,
                                       aIsMovable: false, bIsMovable: true)
        precondition(next?.switchID == "switch-B")
        precondition(next.map {
            CMOriginalSwitchContactMapper.qualifiesForExperimentalImpact($0)
        } == false)
        // FIRST didBegin frame is a zero impulse; a later didUpdate
        // positive impulse must still toggle the real original switch.
        precondition(mapper.consumeImpact("ball", "lever-B", impulse: 0,
                                         aIsMovable: true, bIsMovable: false) == nil)
        precondition(mapper.consumeImpact("ball", "lever-B", impulse: .nan,
                                         aIsMovable: true, bIsMovable: false) == nil)
        precondition(mapper.consumeImpact("ball", "lever-B", impulse: 0.42,
                                         aIsMovable: true, bIsMovable: false)?.switchID
                     == "switch-B")
        precondition(mapper.consumeImpact("lever-B", "ball", impulse: 2.0,
                                         aIsMovable: false, bIsMovable: true) == nil)
        mapper.endContact("ball", "lever-B")
        precondition(mapper.beginContact("lever-B", "ball", impulse: 0,
                                         aIsMovable: false, bIsMovable: true) != nil)
        precondition(mapper.consumeImpact("lever-B", "ball", impulse: 0.3,
                                         aIsMovable: false, bIsMovable: true) != nil)
        // SceneKit can deliver didUpdate before didBegin, or an invalid
        // didBegin; a genuine later positive impact must still work once.
        var updateFirst = CMOriginalSwitchContactMapper(objects: objects)
        precondition(updateFirst.consumeImpact("ball", "lever-A", impulse: 0,
            aIsMovable: true, bIsMovable: false) == nil)
        precondition(updateFirst.consumeImpact("ball", "lever-A", impulse: .nan,
            aIsMovable: true, bIsMovable: false) == nil)
        precondition(updateFirst.consumeImpact("ball", "lever-A", impulse: 0.8,
            aIsMovable: true, bIsMovable: false)?.switchID == "switch-A")
        precondition(updateFirst.consumeImpact("lever-A", "ball", impulse: 1.1,
            aIsMovable: false, bIsMovable: true) == nil)
        precondition(updateFirst.beginContact("lever-A", "ball", impulse: 1.1,
            aIsMovable: false, bIsMovable: true) == nil)
        // The recovery path may not infer a switch from a housing hit,
        // non-movable striker or a switch's own nested original parts.
        precondition(updateFirst.consumeImpact("base-A", "ball", impulse: 1,
            aIsMovable: false, bIsMovable: true) == nil)
        precondition(updateFirst.consumeImpact("lever-B", "board", impulse: 1,
            aIsMovable: false, bIsMovable: false) == nil)
        precondition(updateFirst.consumeImpact("lever-A", "mount-A", impulse: 1,
            aIsMovable: false, bIsMovable: true) == nil)
        updateFirst.endContact("lever-A", "ball")
        precondition(updateFirst.consumeImpact("ball", "lever-A", impulse: 0.5,
            aIsMovable: true, bIsMovable: false) != nil)
        // Neither parent-less leaves nor a nearby switch base may act as lever.
        var noLever = CMOriginalSwitchContactMapper(objects: [
            .init(id: "switch", type: "tmo_power_switch", parentID: nil),
            .init(id: "lever", type: "tmo_power_switch_lever", parentID: nil),
            .init(id: "ball", type: "tmo_ball_iron", parentID: nil)
        ])
        precondition(noLever.beginContact("lever", "ball", impulse: 1,
                                          aIsMovable: false, bIsMovable: true) == nil)
        precondition(noLever.originalSwitchID(forLeverID: "lever") == nil)
        print("Original CML nested switch lever touch/impact mapping: OK")
    }
}
