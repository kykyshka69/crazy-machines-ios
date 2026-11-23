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
    private let generatorDeviceIDs: Set<String>
    private let solarDeviceIDs: Set<String>
    private let conditionalSourceDeviceIDs: Set<String>
    private let passthroughDeviceIDs: Set<String>
    private let multiTerminalLoadDeviceIDs: Set<String>
    private let switchDeviceIDs: Set<String>
    private let disrupterDeviceIDs: Set<String>

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
        generatorDeviceIDs = Set(all.filter {
            $0.deviceType == "tmo_power_generator"
        }.map(\.deviceID))
        solarDeviceIDs = Set(all.filter {
            $0.deviceType == "tmo_power_solarcell"
        }.map(\.deviceID))
        conditionalSourceDeviceIDs = Set(all.filter {
            $0.deviceType == "tmo_power_generator"
                || $0.deviceType == "tmo_power_solarcell"
        }.map(\.deviceID))
        passthroughDeviceIDs = Set(all.filter {
            $0.deviceType == "tmo_power_distributor"
        }.map(\.deviceID))
        // The original Win32 0x44C950–0x44CC37 forwards a physically
        // connected signal through remaining connector slots (+0xFE),
        // excluding its incoming slot; it stops before recursively entering
        // an original tmo_power_battery. A load with two or more genuine
        // tmo_power_plug children can therefore be an explicit wired path.
        // Keep unobserved generator/solar back-feed and actual switch or
        // disrupter physics behind their separate conservative gates.
        let byDevice = Dictionary(grouping: all, by: \.deviceID)
        multiTerminalLoadDeviceIDs = Set(byDevice.compactMap { entry in
            guard entry.value.count >= 2,
                  let kind = entry.value.first?.deviceType,
                  kind != "tmo_power_battery",
                  kind != "tmo_power_generator",
                  kind != "tmo_power_solarcell",
                  kind != "tmo_power_switch",
                  kind != "tmo_power_disrupter"
            else { return nil }
            return entry.key
        })
        switchDeviceIDs = Set(all.filter {
            $0.deviceType == "tmo_power_switch"
        }.map(\.deviceID))
        disrupterDeviceIDs = Set(all.filter {
            $0.deviceType == "tmo_power_disrupter"
        }.map(\.deviceID))
    }

    /// The iPhone user's *explicitly paired* wires, not original Windows
    /// cables inferred from terminal numbers. Scope storage to the exact
    /// imported PC scene hash, never merely to its display-level number.
    public var snapshotStorageKey: String {
        "cm.original.power-cables.\(sceneSHA256)"
    }

    private struct SavedCable: Codable {
        let firstPlugID: String
        let secondPlugID: String
    }

    private struct Snapshot: Codable {
        let version: Int
        let levelIndex: Int
        let sceneSHA256: String
        let cables: [SavedCable]
    }

    public func snapshotData() throws -> Data {
        let pairs = cables.sorted {
            $0.firstPlugID == $1.firstPlugID
                ? $0.secondPlugID < $1.secondPlugID
                : $0.firstPlugID < $1.firstPlugID
        }.map { SavedCable(firstPlugID: $0.firstPlugID,
                           secondPlugID: $0.secondPlugID) }
        return try JSONEncoder().encode(Snapshot(
            version: 1, levelIndex: levelIndex,
            sceneSHA256: sceneSHA256, cables: pairs))
    }

    /// Restore only authentic known plug identities and valid disjoint pairs.
    /// A malformed, cross-level or incompatible snapshot cannot partially
    /// replace the currently selected cables or fabricate a power source.
    @discardableResult
    public mutating func restoreSnapshot(_ data: Data) -> Bool {
        guard data.count <= 128 * 1024,
              let saved = try? JSONDecoder().decode(Snapshot.self, from: data),
              saved.version == 1,
              saved.levelIndex == levelIndex,
              saved.sceneSHA256 == sceneSHA256,
              saved.cables.count <= min(512, terminals.count / 2) else {
            return false
        }
        var candidate = self
        candidate.cables.removeAll(keepingCapacity: true)
        for cable in saved.cables {
            guard candidate.toggleCable(
                between: cable.firstPlugID, and: cable.secondPlugID
            ) == .connected else { return false }
        }
        cables = candidate.cables
        return true
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
    /// A single-terminal load is an endpoint. Multi-terminal loads only
    /// forward through actual paired cables, consistent with the original
    /// Win32 per-connector recursion; this remains a scalar prototype.
    public func reachableDevices(
        closedSwitchIDs: Set<String> = [],
        externallyActiveSourceIDs: Set<String> = [],
        disrupterRotorAnglesByDeviceID: [String: Float] = [:],
        switchContactsByDeviceID: [String: CMOriginalWindowsSwitchContactGate.ContactPair] = [:]
    ) -> Set<String> {
        let sources = sourceDeviceIDs.union(
            externallyActiveSourceIDs.intersection(conditionalSourceDeviceIDs))
        return devicesReachable(
            from: sources, closedSwitchIDs: closedSwitchIDs,
            disrupterRotorAnglesByDeviceID: disrupterRotorAnglesByDeviceID,
            switchContactsByDeviceID: switchContactsByDeviceID)
    }

    /// Strict reachability through explicitly authored cable pairs, using
    /// the authentic original plug owner IDs. Loads do not transmit, and
    /// open original switches cut off downstream devices; batteries never
    /// become unintended reverse feed-through nodes.
    private func devicesReachable(
        from sources: Set<String>, closedSwitchIDs: Set<String>,
        disrupterRotorAnglesByDeviceID: [String: Float],
        switchContactsByDeviceID: [String: CMOriginalWindowsSwitchContactGate.ContactPair]
    ) -> Set<String> {
        var edges: [String: Set<String>] = [:]
        for cable in cables {
            guard let a = byPlugID[cable.firstPlugID],
                  let b = byPlugID[cable.secondPlugID] else { continue }
            edges[a.deviceID, default: []].insert(b.deviceID)
            edges[b.deviceID, default: []].insert(a.deviceID)
        }
        var visited = sources
        var queue = Array(sources)
        var head = 0
        while head < queue.count {
            let current = queue[head]
            head += 1
            let transmits = sources.contains(current)
                || passthroughDeviceIDs.contains(current)
                || multiTerminalLoadDeviceIDs.contains(current)
                || (switchDeviceIDs.contains(current)
                    && (switchContactsByDeviceID[current].map {
                        CMOriginalWindowsSwitchContactGate.preservesPower($0) == true
                    } ?? closedSwitchIDs.contains(current)))
                || (disrupterDeviceIDs.contains(current)
                    && disrupterRotorAnglesByDeviceID[current].map {
                        CMOriginalWindowsPowerDisrupter.conducts(rotorAngle: $0)
                    } == true)
            guard transmits else { continue }
            for neighbor in edges[current] ?? [] {
                // Win32 0x44CA24 clears power on a switch whose contact
                // +0xEC and +0xC8 mismatch at an exact ±1 position.
                // Only independently observed contact pairs override the
                // legacy prototype toggle; never manufacture those fields.
                if switchDeviceIDs.contains(neighbor),
                   let contacts = switchContactsByDeviceID[neighbor],
                   CMOriginalWindowsSwitchContactGate.preservesPower(contacts) != true {
                    continue
                }
                // Win32 0x44CAA3/0x44CAC2 clears +0x40 on the actual
                // disrupter target when its wheel phase blocks current.
                // Do not expose even a phantom powered disrupter node.
                if disrupterDeviceIDs.contains(neighbor) {
                    guard let phase = disrupterRotorAnglesByDeviceID[neighbor],
                          CMOriginalWindowsPowerDisrupter.conducts(rotorAngle: phase)
                    else { continue }
                }
                if visited.insert(neighbor).inserted { queue.append(neighbor) }
            }
        }
        return visited
    }

    /// An explicitly labeled iOS experiment, not the full Win32 circuit
    /// solver. Battery: actual Win32 source value 10. Generator: actual
    /// Win32 source operation abs(rotor command +0xE8). Sources travel only
    /// via selected cables/switches/distributors, never via nearest objects.
    /// A receiving device reached by two different source signals is
    /// AMBIGUOUS: fail closed rather than inventing addition/polarity rules.
    public func experimentalNetworkSignals(
        closedSwitchIDs: Set<String> = [],
        generatorRotorCommandsByDeviceID: [String: Float] = [:],
        // Only independently measured ORIGINAL light ray intersections;
        // never turn on every solar cell just because it exists in the CML.
        solarRayContributionsByDeviceID: [String: [Float]] = [:],
        disrupterRotorAnglesByDeviceID: [String: Float] = [:],
        switchContactsByDeviceID: [String: CMOriginalWindowsSwitchContactGate.ContactPair] = [:]
    ) -> [String: Float] {
        var sources: [(String, Float)] = sourceDeviceIDs.sorted().map {
            ($0, CMOriginalWindowsPowerScalar.batterySource)
        }
        for (deviceID, speed) in generatorRotorCommandsByDeviceID.sorted(
            by: { $0.key < $1.key }) {
            guard generatorDeviceIDs.contains(deviceID),
                  let output = CMOriginalWindowsPowerScalar
                    .generatorSignal(fromRotorCommand: speed),
                  output > 0 else { continue }
            sources.append((deviceID, output))
        }
        for (deviceID, rays) in solarRayContributionsByDeviceID.sorted(
            by: { $0.key < $1.key }) {
            guard solarDeviceIDs.contains(deviceID),
                  let output = CMOriginalWindowsSolarSignal
                    .collectedPower(rayContributions: rays),
                  output > 0 else { continue }
            sources.append((deviceID, output))
        }
        var power: [String: Float] = [:]
        var ambiguous = Set<String>()
        for (sourceID, signal) in sources {
            for id in devicesReachable(
                from: [sourceID], closedSwitchIDs: closedSwitchIDs,
                disrupterRotorAnglesByDeviceID: disrupterRotorAnglesByDeviceID,
                switchContactsByDeviceID: switchContactsByDeviceID
            ) {
                if let previous = power[id], previous != signal {
                    ambiguous.insert(id)
                } else {
                    power[id] = signal
                }
            }
        }
        for id in ambiguous { power.removeValue(forKey: id) }
        return power
    }

    /// Compatibility for purely battery-driven puzzles: a single source
    /// returns the recovered 10.0 Win32 scalar, not a made-up VALF voltage.
    public func experimentalBatterySignals(
        closedSwitchIDs: Set<String> = [],
        disrupterRotorAnglesByDeviceID: [String: Float] = [:],
        switchContactsByDeviceID: [String: CMOriginalWindowsSwitchContactGate.ContactPair] = [:]
    ) -> [String: Float] {
        experimentalNetworkSignals(
            closedSwitchIDs: closedSwitchIDs,
            disrupterRotorAnglesByDeviceID: disrupterRotorAnglesByDeviceID,
            switchContactsByDeviceID: switchContactsByDeviceID)
    }

    public mutating func reset() { cables.removeAll(keepingCapacity: true) }
}