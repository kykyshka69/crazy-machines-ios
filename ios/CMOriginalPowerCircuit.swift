import Foundation

/// A safety-first electrical connection registry for imported Windows parts.
///
/// Original Professor CML preserves tmo_power_plug objects and unique VALF
/// terminal numbers, but VALF is a terminal *identity*, not a voltage and
/// NOT a link to the terminal having the same number. The original Win32
/// cable builder (0x42FCB0) receives two physical ends and constructs a
/// separate `power_cable`; that cable topology is not in the CML VALF field.
///
/// Only explicit player/editor paired ends are edges. No same-type, same-id,
/// proximity, GOAL or generic collision pairing. `reachableDevices` is an
/// experimental *connectivity* tracer, not proof of current, voltage, or a
/// reconstructed Windows motor activation. The game must not award goals
/// or turn a motor solely because a device is reachable.
public struct CMOriginalPowerCircuit {
    public struct Terminal: Hashable {
        public let plugID: String
        public let number: Int?
        public let deviceID: String
        public let deviceType: String
    }

    public struct Cable: Hashable {
        public let firstPlugID: String
        public let secondPlugID: String
        public init(_ first: String, _ second: String) {
            if first < second {
                firstPlugID = first
                secondPlugID = second
            } else {
                firstPlugID = second
                secondPlugID = first
            }
        }
    }

    public enum ConnectResult: Equatable {
        case connected
        case disconnected
        case rejected
    }

    public let levelIndex: Int
    public let sceneSHA256: String
    public let terminals: [Terminal]
    public private(set) var cables: Set<Cable> = []

    private let byPlugID: [String: Terminal]
    private let sourceDeviceIDs: Set<String>
    private let conditionalSourceDeviceIDs: Set<String>
    private let passthroughDeviceIDs: Set<String>
    private let switchDeviceIDs: Set<String>

    public init?(session: CMOriginalGameplaySession) {
        guard (1...102).contains(session.levelIndex) else { return nil }
        var all: [Terminal] = []
        var known = Set<String>()
        for plug in session.originalPowerTerminals {
            guard let deviceID = plug.deviceObjectID,
                  let deviceType = plug.deviceType,
                  known.insert(plug.plugObjectID).inserted else { continue }
            all.append(Terminal(plugID: plug.plugObjectID,
                                number: plug.originalTerminalNumber,
                                deviceID: deviceID, deviceType: deviceType))
        }
        // Preserve authentic CML ownership; no user-authored synthetic
        // terminal numbers or guessed nearest-device assignments.
        levelIndex = session.levelIndex
        sceneSHA256 = session.sceneSHA256
        terminals = all
        byPlugID = Dictionary(uniqueKeysWithValues: all.map { ($0.plugID, $0) })
        sourceDeviceIDs = Set(all.filter {
            $0.deviceType == "tmo_power_battery"
        }.map(\.deviceID))
        conditionalSourceDeviceIDs = Set(all.filter {
            $0.deviceType == "tmo_power_generator"
                || $0.deviceType == "tmo_power_solarcell"
        }.map(\.deviceID))
        passthroughDeviceIDs = Set(all.filter {
            $0.deviceType == "tmo_power_distributor"
        }.map(\.deviceID))
        switchDeviceIDs = Set(all.filter {
            $0.deviceType == "tmo_power_switch"
        }.map(\.deviceID))
    }

    public var cableCount: Int { cables.count }
    public var unwiredTerminalCount: Int {
        let used = Set(cables.flatMap { [$0.firstPlugID, $0.secondPlugID] })
        return terminals.filter { !used.contains($0.plugID) }.count
    }

    /// Two clicks on DIFFERENT original plugs create/remove one cable. One
    /// original terminal cannot silently become connected to many wires.
    /// A same-device short is rejected until original cable rules are known.
    @discardableResult
    public mutating func toggleCable(between left: String, and right: String) -> ConnectResult {
        guard left != right,
              let a = byPlugID[left], let b = byPlugID[right],
              a.deviceID != b.deviceID else { return .rejected }
        let cable = Cable(left, right)
        if cables.remove(cable) != nil { return .disconnected }
        guard !cables.contains(where: {
            $0.firstPlugID == left || $0.secondPlugID == left
                || $0.firstPlugID == right || $0.secondPlugID == right
        }), cables.count < 512 else { return .rejected }
        cables.insert(cable)
        return .connected
    }

    /// Trace reachability ONLY across explicit cables. Batteries are the
    /// only established local source *category*. Moving generators and solar
    /// panels require separate, real mechanical/light observations before
    /// adding them as sources. Closed switches pass through; open ones stop.
    /// Non-conducting loads are endpoints, never accidental bridges.
    public func reachableDevices(
        closedSwitchIDs: Set<String> = [],
        externallyActiveSourceIDs: Set<String> = []
    ) -> Set<String> {
        let activeSourceIDs = sourceDeviceIDs.union(
            externallyActiveSourceIDs.intersection(conditionalSourceDeviceIDs))
        var edges: [String: Set<String>] = [:]
        for cable in cables {
            guard let a = byPlugID[cable.firstPlugID],
                  let b = byPlugID[cable.secondPlugID] else { continue }
            edges[a.deviceID, default: []].insert(b.deviceID)
            edges[b.deviceID, default: []].insert(a.deviceID)
        }
        var visited = activeSourceIDs
        var queue = Array(activeSourceIDs)
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            let transmits = activeSourceIDs.contains(current)
                || passthroughDeviceIDs.contains(current)
                || (switchDeviceIDs.contains(current)
                    && closedSwitchIDs.contains(current))
            guard transmits else { continue }
            for neighbor in edges[current] ?? [] where visited.insert(neighbor).inserted {
                queue.append(neighbor)
            }
        }
        return visited
    }

    /// Explicit, opt-in iOS *prototype* for propagating the battery's real
    /// Win32 +0x40 source value (10.0f) across manually paired plug endpoints.
    /// Win32 also copies electrical state along cable paths at 0x44C8F2.
    /// Only a closed switch or original distributor can pass it onward.
    /// Does NOT reconstruct current, polarity, resistor loss or a closed loop.
    public func experimentalBatterySignals(
        closedSwitchIDs: Set<String> = []
    ) -> [String: Float] {
        guard !sourceDeviceIDs.isEmpty else { return [:] }
        let reachable = reachableDevices(closedSwitchIDs: closedSwitchIDs)
        return Dictionary(uniqueKeysWithValues: reachable.map {
            ($0, CMOriginalWindowsPowerScalar.batterySource)
        })
    }

    public mutating func reset() { cables.removeAll(keepingCapacity: true) }
}