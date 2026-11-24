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

    public struct NetworkObservation {
        public let deviceSignals: [String: Float]
        public let cableSignals: [Cable: Float]
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

    // Run-local native scissors interruption. Keep the authored arrangement
    // for replay; never persist a physical cut as a player editing action.
    public private(set) var cutPlugIDs: Set<String> = []

    public var activeCables: Set<Cable> {
        cables.filter { !cutPlugIDs.contains($0.firstPlugID)
            && !cutPlugIDs.contains($0.secondPlugID) }
    }

    /// Win32 0x457312/0x45731F marks both real endpoints +0x50=1,
    /// clears +0x40, then propagates the interruption in both directions.
    /// Only an independently observed cut of an existing exact wire may
    /// invoke this transition. The native blade test is a separate path.
    @discardableResult
    public mutating func applyObservedCableCut(_ cable: Cable) -> Bool {
        guard activeCables.contains(cable) else { return false }
        cutPlugIDs.insert(cable.firstPlugID)
        cutPlugIDs.insert(cable.secondPlugID)
        return true
    }

    public mutating func clearRuntimeCuts() {
        cutPlugIDs.removeAll(keepingCapacity: true)
    }

    private let byPlugID: [String: Terminal]
    public let recoveredNativeSlotOrder: [String: [String]]?
    public let recoveredNativeOwnerOrder: [String]?
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
        recoveredNativeSlotOrder = session.recoveredNativeElectricalSlotOrder
        recoveredNativeOwnerOrder = session.recoveredNativeElectricalOwnerOrder
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
        let encoder = JSONEncoder()
        // Canonical bytes make a repeated save idempotent and independently
        // verifiable even when Swift's dictionary key ordering changes.
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(Snapshot(
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
        candidate.clearRuntimeCuts()
        for cable in saved.cables {
            guard candidate.toggleCable(
                between: cable.firstPlugID, and: cable.secondPlugID
            ) == .connected else { return false }
        }
        cables = candidate.cables
        clearRuntimeCuts()
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
        if cables.remove(cable) != nil {
            cutPlugIDs.remove(left)
            cutPlugIDs.remove(right)
            return .disconnected
        }
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
            switchContactsByDeviceID: switchContactsByDeviceID).devices
    }

    /// Strict reachability through explicitly authored cable pairs, using
    /// the authentic original plug owner IDs. Loads do not transmit, and
    /// open original switches cut off downstream devices; batteries never
    /// become unintended reverse feed-through nodes.
    private func devicesReachable(
        from sources: Set<String>, closedSwitchIDs: Set<String>,
        disrupterRotorAnglesByDeviceID: [String: Float],
        switchContactsByDeviceID: [String: CMOriginalWindowsSwitchContactGate.ContactPair]
    ) -> (devices: Set<String>, cables: Set<Cable>) {
        var edges: [String: [(neighbor: String, cable: Cable)]] = [:]
        var traversed = Set<Cable>()
        for cable in activeCables {
            guard let a = byPlugID[cable.firstPlugID],
                  let b = byPlugID[cable.secondPlugID] else { continue }
            edges[a.deviceID, default: []].append((b.deviceID, cable))
            edges[b.deviceID, default: []].append((a.deviceID, cable))
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
            for edge in edges[current] ?? [] {
                let neighbor = edge.neighbor
                // Win32 0x44CC0F–0x44CC37 explicitly compares the NEXT
                // attached object type with "tmo_power_battery" and SKIPS
                // its recursive power propagation. A battery's native
                // +0x40 source must not be overwritten by an attached
                // generator or a second battery: each battery is seeded
                // independently at the start of this experiment.
                // Previous code erroneously walked into another battery
                // and could mark its known 10.0 output "ambiguous".
                guard !sourceDeviceIDs.contains(neighbor) else { continue }
                // Incoming plug receives source before outgoing gate.
                traversed.insert(edge.cable)
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
        return (visited, traversed)
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
        experimentalNetworkObservation(closedSwitchIDs: closedSwitchIDs,
            generatorRotorCommandsByDeviceID: generatorRotorCommandsByDeviceID,
            solarRayContributionsByDeviceID: solarRayContributionsByDeviceID,
            disrupterRotorAnglesByDeviceID: disrupterRotorAnglesByDeviceID,
            switchContactsByDeviceID: switchContactsByDeviceID).deviceSignals
    }

    /// One source-aware pass records actual traversed plug pairs.
    public func experimentalNetworkObservation(
        closedSwitchIDs: Set<String> = [],
        generatorRotorCommandsByDeviceID: [String: Float] = [:],
        solarRayContributionsByDeviceID: [String: [Float]] = [:],
        disrupterRotorAnglesByDeviceID: [String: Float] = [:],
        switchContactsByDeviceID: [String: CMOriginalWindowsSwitchContactGate.ContactPair] = [:]
    ) -> NetworkObservation {
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
        var wirePower: [Cable: Float] = [:]
        var ambiguousWires = Set<Cable>()
        for (sourceID, signal) in sources {
            let trace = devicesReachable(
                from: [sourceID], closedSwitchIDs: closedSwitchIDs,
                disrupterRotorAnglesByDeviceID: disrupterRotorAnglesByDeviceID,
                switchContactsByDeviceID: switchContactsByDeviceID
            )
            for wire in trace.cables {
                if wirePower[wire] != nil { ambiguousWires.insert(wire) }
                else { wirePower[wire] = signal }
            }
            for id in trace.devices {
                // Two distinct *physical* sources are ambiguous even if
                // both happen to output the SAME numeric scalar (e.g. two
                // native 10.0 batteries). Equality does not prove that
                // Windows permits paralleling them, nor can it establish
                // current direction or reverse-feed safety. Fail closed.
                // Ambiguity remains sticky for this observation pass.
                if power[id] != nil {
                    ambiguous.insert(id)
                } else {
                    power[id] = signal
                }
            }
        }
        for id in ambiguous { power.removeValue(forKey: id) }
        for wire in ambiguousWires { wirePower.removeValue(forKey: wire) }
        wirePower = wirePower.filter { wire, _ in
            guard let a = byPlugID[wire.firstPlugID], let b = byPlugID[wire.secondPlugID] else { return false }
            return !ambiguous.contains(a.deviceID) && !ambiguous.contains(b.deviceID)
        }
        return NetworkObservation(deviceSignals: power, cableSignals: wirePower)
    }

    /// Visually mark only exact user-paired original wires with a finite,
    /// nonzero and IDENTICAL provisional signal at both CML device owners.
    /// This never computes native current, polarity, resistance or GOAL.
    public func experimentalCablePowerSignals(
        powerByDeviceID: [String: Float]
    ) -> [Cable: Float] {
        var known: [Cable: Float] = [:]
        for wire in activeCables {
            guard let left = byPlugID[wire.firstPlugID],
                  let right = byPlugID[wire.secondPlugID],
                  // Native traversal explicitly skips entering another battery.
                  // Two independent 10.0 battery seeds do not energize the
                  // cable between them merely because their values match.
                  !(sourceDeviceIDs.contains(left.deviceID)
                    && sourceDeviceIDs.contains(right.deviceID)),
                  let a = powerByDeviceID[left.deviceID],
                  let b = powerByDeviceID[right.deviceID],
                  a.isFinite, b.isFinite, a != 0, a == b else { continue }
            known[wire] = a
        }
        return known
    }

    /// Reference state for the confirmed ordered Win32 plug walker.
    /// Sparse values mean not yet observed, not an implicit powered device.
    public struct NativePortState: Equatable {
        public var signals: [String: Float]
        public var visitedOwners: Set<String>
        public fileprivate(set) var consumerReads: [String: NativeConsumerRead] = [:]
        // Source GOAL reads occur before a cut can zero the outgoing plug.
        public fileprivate(set) var sourceReads: [String: Float] = [:]
        public init(signals: [String: Float] = [:], visitedOwners: Set<String> = []) {
            self.signals = signals
            self.visitedOwners = visitedOwners
        }
    }

    /// Observed values at the actual consumer update, not end-of-frame values.
    /// Missing slot state remains unknown; an unwritten slot is not assumed zero.
    public struct NativeConsumerRead: Equatable {
        public let first: Float?
        public let second: Float?
    }

    public enum NativePortEvent {
        case resetVisited
        case sampleConsumer(ownerID: String)
        case source(plugID: String, value: Float)
        case cutTransfer(Cable)
    }

    /// Native slot lookup (0x420360 -> 0x4204A0) walks component records
    /// in their runtime order. A terminal's VALF is never its slot index.
    /// An explicit observed order must be a complete per-owner permutation.
    private func nativeSlots(
        observedOrder: [String: [String]]?
    ) -> [String: [Terminal]]? {
        let grouped = Dictionary(grouping: terminals, by: \.deviceID)
        guard let observedOrder = observedOrder ?? recoveredNativeSlotOrder else { return grouped }
        guard Set(observedOrder.keys) == Set(grouped.keys) else { return nil }
        var result: [String: [Terminal]] = [:]
        for (owner, slots) in grouped {
            guard let order = observedOrder[owner], order.count == slots.count,
                  Set(order) == Set(slots.map(\.plugID)) else { return nil }
            result[owner] = order.compactMap { byPlugID[$0] }
        }
        return result
    }

    /// 0x44C8A0: visit owner before copying incoming +0x40, then walk
    /// remaining slots depth-first, even when a gate writes zero.
    /// 0x44D070 resets the visit markers, NOT the stored plug values.
    /// The caller supplies observed source event order and physical gates;
    /// native frame scheduling and runtime slot order are not yet proven
    /// equivalent to CML order. Kept separate from the playable solver.
    public func nativePortPass(
        previous: NativePortState = .init(),
        events: [NativePortEvent],
        conductingByDeviceID: [String: Bool],
        observedSlotOrder: [String: [String]]? = nil
    ) -> NativePortState? {
        guard let groups = nativeSlots(observedOrder: observedSlotOrder),
              events.count <= 2048,
              previous.signals.allSatisfy({ byPlugID[$0.key] != nil && $0.value.isFinite }),
              previous.visitedOwners.allSatisfy({ groups[$0] != nil })
        else { return nil }
        var state = previous
        state.consumerReads.removeAll(keepingCapacity: true)
        state.sourceReads.removeAll(keepingCapacity: true)
        var peers: [String: String] = [:]
        for cable in cables {
            peers[cable.firstPlugID] = cable.secondPlugID
            peers[cable.secondPlugID] = cable.firstPlugID
        }

        func walk(_ source: String, _ target: String) -> Bool {
            guard let incoming = byPlugID[target],
                  let slots = groups[incoming.deviceID],
                  let value = state.signals[source] else { return false }
            // The recursive entry tests the OWNER before writing the plug.
            guard state.visitedOwners.insert(incoming.deviceID).inserted else { return true }
            let input: Float = cutPlugIDs.contains(source) ? 0 : value
            state.signals[source] = input
            state.signals[target] = input
            let gated = switchDeviceIDs.contains(incoming.deviceID)
                || disrupterDeviceIDs.contains(incoming.deviceID)
            for port in slots {
                // A single-slot device does process its incoming slot.
                if slots.count > 1 && port.plugID == target { continue }
                let output: Float
                if gated {
                    guard let conducting = conductingByDeviceID[incoming.deviceID] else { return false }
                    output = conducting ? input : 0
                } else {
                    output = input
                }
                state.signals[port.plugID] = output
                guard let peer = peers[port.plugID], peer != source,
                      let other = byPlugID[peer],
                      !sourceDeviceIDs.contains(other.deviceID) else { continue }
                if !walk(port.plugID, peer) { return false }
            }
            return true
        }

        for event in events {
            switch event {
            case .resetVisited:
                state.visitedOwners.removeAll(keepingCapacity: true)
            case .sampleConsumer(let ownerID):
                guard let slots = groups[ownerID], let first = slots.first else { return nil }
                state.consumerReads[ownerID] = NativeConsumerRead(
                    first: state.signals[first.plugID],
                    second: slots.dropFirst().first.flatMap { state.signals[$0.plugID] })
            case .source(let plugID, let value):
                guard let port = byPlugID[plugID], value.isFinite, value >= 0,
                      sourceDeviceIDs.contains(port.deviceID)
                        || conditionalSourceDeviceIDs.contains(port.deviceID),
                      groups[port.deviceID]?.first?.plugID == plugID else { return nil }
                state.signals[plugID] = value
                state.sourceReads[port.deviceID] = value
                if let peer = peers[plugID] {
                    state.visitedOwners.insert(port.deviceID)
                    if !walk(plugID, peer) { return nil }
                }
            case .cutTransfer(let cable):
                // 0x457312..0x45738F clears both ends, resets visit
                // markers, then invokes propagation in both directions.
                guard cables.contains(cable),
                      cutPlugIDs.contains(cable.firstPlugID),
                      cutPlugIDs.contains(cable.secondPlugID) else { return nil }
                state.signals[cable.firstPlugID] = 0
                state.signals[cable.secondPlugID] = 0
                state.visitedOwners.removeAll(keepingCapacity: true)
                if !walk(cable.firstPlugID, cable.secondPlugID) { return nil }
                if !walk(cable.secondPlugID, cable.firstPlugID) { return nil }
            }
        }
        return state
    }

    /// Native electrical phase order, from 0x44D64E, 0x44D832 and
    /// 0x45043B. The caller must supply the observed runtime owner order;
    /// CML hierarchy or lexical ID sorting is not proven equivalent.
    /// Generator propagation can occur inside mechanical callbacks, so the
    /// caller supplies their observed events at the corresponding owner.
    public func nativeElectricalUpdate(
        previous: NativePortState,
        ownerOrder: [String],
        solarRayContributionsByDeviceID: [String: [Float]],
        generatorEventsBeforeOpticalOwner: [String: [NativePortEvent]] = [:],
        generatorEventsAfterElectricalOwner: [String: [NativePortEvent]] = [:],
        conductingByDeviceID: [String: Bool],
        observedSlotOrder: [String: [String]]? = nil
    ) -> NativePortState? {
        guard let groups = nativeSlots(observedOrder: observedSlotOrder) else { return nil }
        let known = Set(groups.keys)
        guard ownerOrder.count == known.count, Set(ownerOrder) == known,
              Set(generatorEventsBeforeOpticalOwner.keys).isSubset(of: known),
              Set(generatorEventsAfterElectricalOwner.keys).isSubset(of: known),
              Set(solarRayContributionsByDeviceID.keys).isSubset(of: solarDeviceIDs)
        else { return nil }
        func validGenerator(_ event: NativePortEvent) -> Bool {
            guard case .source(let id, let value) = event,
                  let terminal = byPlugID[id], generatorDeviceIDs.contains(terminal.deviceID),
                  value.isFinite, value >= 0 else { return false }
            return true
        }
        var events: [NativePortEvent] = [.resetVisited]
        for id in ownerOrder {
            let before = generatorEventsBeforeOpticalOwner[id] ?? []
            guard before.allSatisfy(validGenerator) else { return nil }
            events.append(contentsOf: before)
            guard let first = groups[id]?.first else { return nil }
            // Lamp GOAL/light read precedes the battery/consumer pass.
            if first.deviceType == "tmo_power_lamp" {
                events.append(.sampleConsumer(ownerID: id))
            } else if solarDeviceIDs.contains(id) {
                // Explicit empty rays mean a measured dark panel, not a missing sample.
                guard let rays = solarRayContributionsByDeviceID[id],
                      let value = CMOriginalWindowsSolarSignal.collectedPower(
                        rayContributions: rays) else { return nil }
                events.append(.source(plugID: first.plugID, value: value))
            }
        }
        for id in ownerOrder {
            guard let first = groups[id]?.first else { return nil }
            if sourceDeviceIDs.contains(id) {
                events.append(.source(plugID: first.plugID,
                                      value: CMOriginalWindowsPowerScalar.batterySource))
            } else if ["tmo_power_motor", "tmo_power_bell", "tmo_power_lightning",
                       "tmo_power_amperemeter"].contains(first.deviceType) {
                events.append(.sampleConsumer(ownerID: id))
            }
            let after = generatorEventsAfterElectricalOwner[id] ?? []
            guard after.allSatisfy(validGenerator) else { return nil }
            events.append(contentsOf: after)
        }
        return nativePortPass(previous: previous, events: events,
                              conductingByDeviceID: conductingByDeviceID,
                              observedSlotOrder: observedSlotOrder)
    }

    /// Persistent ordered electrical frames for the subset whose owner/slot
    /// order is recovered and whose only sources are batteries. Dynamic
    /// sources and unobserved disrupter timing remain on the existing solver.
    public var supportsOrderedBatteryFrames: Bool {
        recoveredNativeOwnerOrder != nil && recoveredNativeSlotOrder != nil
            && !sourceDeviceIDs.isEmpty && conditionalSourceDeviceIDs.isEmpty
            && disrupterDeviceIDs.isEmpty
            && sourceDeviceIDs.allSatisfy { id in recoveredNativeSlotOrder?[id]?.count == 1 }
    }

    /// Solar sources execute in the optical phase; disrupter gates are
    /// sampled from the running scene. Generator callbacks require a
    /// separate mechanical schedule and are not covered by this adapter.
    public var supportsOrderedElectricalFrames: Bool {
        recoveredNativeOwnerOrder != nil && recoveredNativeSlotOrder != nil
            && !sourceDeviceIDs.union(solarDeviceIDs).isEmpty
            && generatorDeviceIDs.isEmpty
            && sourceDeviceIDs.union(solarDeviceIDs).allSatisfy {
                recoveredNativeSlotOrder?[$0]?.count == 1
            }
    }

    public struct BatteryFrame: Equatable {
        public let state: NativePortState
        public let processedCuts: Set<Cable>
    }

    public func advanceOrderedBatteryFrame(
        previous: BatteryFrame?, closedSwitchIDs: Set<String>
    ) -> BatteryFrame? {
        guard supportsOrderedBatteryFrames else { return nil }
        return advanceOrderedElectricalFrame(previous: previous,
            closedSwitchIDs: closedSwitchIDs)
    }

    public func advanceOrderedElectricalFrame(
        previous: BatteryFrame?, closedSwitchIDs: Set<String>,
        solarRayContributionsByDeviceID: [String: [Float]] = [:],
        disrupterRotorAnglesByDeviceID: [String: Float] = [:]
    ) -> BatteryFrame? {
        guard supportsOrderedElectricalFrames,
              let ownerOrder = recoveredNativeOwnerOrder,
              let slotOrder = recoveredNativeSlotOrder else { return nil }
        var gates = Dictionary(uniqueKeysWithValues:
            switchDeviceIDs.map { ($0, closedSwitchIDs.contains($0)) })
        for id in disrupterDeviceIDs {
            // No known angle: fail closed until the renderer samples it.
            gates[id] = CMOriginalWindowsPowerDisrupter.conducts(
                rotorAngle: disrupterRotorAnglesByDeviceID[id] ?? .nan)
        }
        let rays = Dictionary(uniqueKeysWithValues: solarDeviceIDs.map {
            ($0, solarRayContributionsByDeviceID[$0] ?? [])
        })
        // Initial zero is a reconstruction of a fresh run, not a measured
        // native memory dump. Thereafter plug state persists between frames.
        var state = previous?.state ?? NativePortState(signals:
            Dictionary(uniqueKeysWithValues: terminals.map { ($0.plugID, Float(0)) }))
        let cuts = cables.subtracting(activeCables)
        guard (previous?.processedCuts ?? []).isSubset(of: cuts) else { return nil }
        let newCuts = cuts.subtracting(previous?.processedCuts ?? []).sorted {
            ($0.firstPlugID, $0.secondPlugID) < ($1.firstPlugID, $1.secondPlugID)
        }
        if !newCuts.isEmpty {
            guard let interrupted = nativePortPass(previous: state,
                events: newCuts.map { .cutTransfer($0) },
                conductingByDeviceID: gates, observedSlotOrder: slotOrder)
            else { return nil }
            state = interrupted
        }
        guard let next = nativeElectricalUpdate(previous: state,
            ownerOrder: ownerOrder, solarRayContributionsByDeviceID: rays,
            conductingByDeviceID: gates, observedSlotOrder: slotOrder)
        else { return nil }
        return BatteryFrame(state: next, processedCuts: cuts)
    }

    public func orderedBatteryObservation(_ frame: BatteryFrame,
                                          closedSwitchIDs: Set<String>,
                                          disrupterRotorAnglesByDeviceID: [String: Float] = [:]) -> NetworkObservation {
        let state = frame.state
        var devices: [String: Float] = [:]
        for (id, slots) in recoveredNativeSlotOrder ?? [:] {
            guard let first = slots.first, let port = byPlugID[first] else { continue }
            let value: Float?
            if let read = state.consumerReads[id] {
                if port.deviceType == "tmo_power_amperemeter" {
                    value = max(read.first ?? 0, read.second ?? 0)
                } else { value = read.first }
            } else if sourceDeviceIDs.contains(id) || solarDeviceIDs.contains(id) {
                value = state.sourceReads[id]
            } else if switchDeviceIDs.contains(id) && !closedSwitchIDs.contains(id) {
                value = nil
            } else if disrupterDeviceIDs.contains(id) &&
                !CMOriginalWindowsPowerDisrupter.conducts(
                    rotorAngle: disrupterRotorAnglesByDeviceID[id] ?? .nan) {
                value = nil
            } else { value = state.signals[first] }
            if let value, value.isFinite, value > 0 { devices[id] = value }
        }
        var wires: [Cable: Float] = [:]
        for cable in activeCables {
            guard let a = byPlugID[cable.firstPlugID], let b = byPlugID[cable.secondPlugID],
                  !(sourceDeviceIDs.contains(a.deviceID) && sourceDeviceIDs.contains(b.deviceID)),
                  let value = state.signals[cable.firstPlugID], value > 0,
                  state.signals[cable.secondPlugID] == value else { continue }
            wires[cable] = value
        }
        return NetworkObservation(deviceSignals: devices, cableSignals: wires)
    }

    /// Settled per-port bridge for order-independent networks.
    /// Each component has one source or fully observed equal source
    /// values and conducting gates. The latter transfers the same scalar,
    /// not a sum of source voltages.
    /// Native transient scheduling and unequal sources still require the
    /// ordered runtime model.
    /// Cycles are order-independent only when every gate in their powered
    /// component conducts: no conflicting zero/positive path can arrive.
    public func settledIndependentSourceObservation(
        closedSwitchIDs: Set<String> = [],
        generatorRotorCommandsByDeviceID: [String: Float] = [:],
        solarRayContributionsByDeviceID: [String: [Float]] = [:],
        disrupterRotorAnglesByDeviceID: [String: Float] = [:]
    ) -> NetworkObservation? {
        let sources = sourceDeviceIDs.union(conditionalSourceDeviceIDs)
        guard !sources.isEmpty else { return nil }
        let groups = Dictionary(grouping: terminals, by: \.deviceID)
        guard sources.allSatisfy({ groups[$0]?.count == 1 }) else { return nil }

        // Identify connected components and cyclic components, including
        // parallel cables. Resolve roots after all unions are complete.
        var cycleOwners = Set<String>()
        var parents = Dictionary(uniqueKeysWithValues: groups.keys.map { ($0, $0) })
        func root(_ id: String) -> String {
            var current = id
            while let next = parents[current], next != current { current = next }
            return current
        }
        for cable in activeCables {
            guard let a = byPlugID[cable.firstPlugID], let b = byPlugID[cable.secondPlugID] else { return nil }
            let x = root(a.deviceID), y = root(b.deviceID)
            if x == y { cycleOwners.insert(a.deviceID) }
            else { parents[x] = y }
        }
        // Native battery, generator and solar each write their own scalar
        // before invoking the same visited-owner propagation function.
        let sourcesByRoot = Dictionary(grouping: sources, by: root)
        let sourceRoots = Set(sourcesByRoot.keys)
        let sharedRoots = Set(sourcesByRoot.compactMap { component, members in
            members.count > 1 ? component : nil
        })
        var sourceValues: [String: Float] = [:]
        var events: [NativePortEvent] = []
        for id in sources.sorted() {
            guard let plug = groups[id]?.first else { return nil }
            let value: Float
            if sourceDeviceIDs.contains(id) {
                value = CMOriginalWindowsPowerScalar.batterySource
            } else if generatorDeviceIDs.contains(id) {
                if sharedRoots.contains(root(id)), generatorRotorCommandsByDeviceID[id] == nil { return nil }
                guard let output = CMOriginalWindowsPowerScalar.generatorSignal(
                    fromRotorCommand: generatorRotorCommandsByDeviceID[id] ?? 0) else { return nil }
                value = output
            } else {
                if sharedRoots.contains(root(id)), solarRayContributionsByDeviceID[id] == nil { return nil }
                guard let output = CMOriginalWindowsSolarSignal.collectedPower(
                    rayContributions: solarRayContributionsByDeviceID[id] ?? []) else { return nil }
                value = output
            }
            sourceValues[id] = value
            events.append(.source(plugID: plug.plugID, value: value))
        }
        // Exact equality only. Do not invent precedence for unequal values,
        // or mistake an absent dynamic observation for a measured zero.
        guard sharedRoots.allSatisfy({ component in
            guard let members = sourcesByRoot[component] else { return false }
            return Set(members.compactMap { sourceValues[$0] }).count == 1
        }) else { return nil }
        var gates: [String: Bool] = [:]
        for id in switchDeviceIDs { gates[id] = closedSwitchIDs.contains(id) }
        for id in disrupterDeviceIDs {
            gates[id] = disrupterRotorAnglesByDeviceID[id].map {
                CMOriginalWindowsPowerDisrupter.conducts(rotorAngle: $0)
            } == true
        }
        let cyclicRoots = Set(cycleOwners.map(root)).intersection(sourceRoots)
        // A blocked gate could cause the native first-arrival walker to
        // choose between zero and positive inputs around a cycle. Until
        // slot order is known, retain the conservative fallback for it.
        let orderSensitiveRoots = cyclicRoots.union(sharedRoots)
        guard !gates.contains(where: { id, conducting in
            !conducting && orderSensitiveRoots.contains(root(id))
        }) else { return nil }
        // Cut cables are absent from this settled reconstruction. Every
        // remaining slot starts at zero, avoiding stale disconnected power.
        var active = self
        active.cables = activeCables
        active.clearRuntimeCuts()
        let initial = NativePortState(signals: Dictionary(uniqueKeysWithValues:
            terminals.map { ($0.plugID, Float(0)) }))
        guard let state = active.nativePortPass(previous: initial,
            events: events,
            conductingByDeviceID: gates) else { return nil }
        var devices: [String: Float] = [:]
        for (owner, slots) in groups {
            // In a forest or fully conducting cycle, all ungated slots on a reached owner carry the
            // same value. The first-slot consumer read therefore does not
            // depend on unverified CML vs native component ordering.
            guard let first = slots.first, let signal = state.signals[first.plugID],
                  signal > 0 else { continue }
            if gates[owner] == false { continue }
            devices[owner] = signal
        }
        var wires: [Cable: Float] = [:]
        for cable in active.cables {
            // Equal independent battery seeds are not evidence of a
            // load path on a direct battery-to-battery connection.
            guard let left = byPlugID[cable.firstPlugID],
                  let right = byPlugID[cable.secondPlugID],
                  !(sources.contains(left.deviceID) && sources.contains(right.deviceID)),
                  let a = state.signals[cable.firstPlugID],
                  let b = state.signals[cable.secondPlugID], a == b, a > 0 else { continue }
            wires[cable] = a
        }
        return NetworkObservation(deviceSignals: devices, cableSignals: wires)
    }

    /// Bounded settled consensus over unresolved source and component
    /// slot orders. Unlike the old device reachability fallback, this keeps
    /// only positive values that agree in EVERY enumerated native walk.
    /// This is not a substitute for the original frame schedule; an unknown
    /// observation or excessive permutation count rejects the approximation.
    public func settledOrderConsensusObservation(
        closedSwitchIDs: Set<String> = [],
        generatorRotorCommandsByDeviceID: [String: Float] = [:],
        solarRayContributionsByDeviceID: [String: [Float]] = [:],
        disrupterRotorAnglesByDeviceID: [String: Float] = [:]
    ) -> NetworkObservation? {
        let groups = Dictionary(grouping: terminals, by: \.deviceID)
        let sources = sourceDeviceIDs.union(conditionalSourceDeviceIDs)
        guard !sources.isEmpty, sources.allSatisfy({ groups[$0]?.count == 1 }) else { return nil }
        let limit = 256
        func permutations(_ values: [String]) -> [[String]]? {
            var result: [[String]] = [[]]
            for value in values {
                var next: [[String]] = []
                for order in result {
                    for index in 0...order.count {
                        guard next.count < limit else { return nil }
                        var candidate = order
                        candidate.insert(value, at: index)
                        next.append(candidate)
                    }
                }
                result = next
            }
            return result
        }
        var values: [String: Float] = [:]
        for id in sources {
            if sourceDeviceIDs.contains(id) {
                values[id] = CMOriginalWindowsPowerScalar.batterySource
            } else if generatorDeviceIDs.contains(id) {
                guard let speed = generatorRotorCommandsByDeviceID[id],
                      let value = CMOriginalWindowsPowerScalar.generatorSignal(fromRotorCommand: speed)
                else { return nil }
                values[id] = value
            } else {
                guard let rays = solarRayContributionsByDeviceID[id],
                      let value = CMOriginalWindowsSolarSignal.collectedPower(rayContributions: rays)
                else { return nil }
                values[id] = value
            }
        }
        let sourceOrders: [[String]]
        if let nativeOwners = recoveredNativeOwnerOrder, generatorDeviceIDs.isEmpty {
            // The native optical pass precedes the battery pass. Within
            // each, the recovered level_elements owner order is retained.
            // Still a settled approximation: mechanical resets and
            // interleaved consumer reads require the full frame scheduler.
            let optical = nativeOwners.filter { solarDeviceIDs.contains($0) }
            let batteries = nativeOwners.filter { sourceDeviceIDs.contains($0) }
            guard Set(optical + batteries) == sources else { return nil }
            sourceOrders = [optical + batteries]
        } else {
            guard let candidates = permutations(sources.sorted()) else { return nil }
            sourceOrders = candidates
        }
        var orders: [[String: [String]]] = [[:]]
        let connected = Set(activeCables.flatMap { [$0.firstPlugID, $0.secondPlugID] })
        for owner in groups.keys.sorted() {
            guard let slots = groups[owner] else { return nil }
            let ids = slots.map(\.plugID)
            // Unwired slots cannot change traversal order. Consumer reads
            // below require agreement across all slots, not a guessed first.
            let linked = ids.filter { connected.contains($0) }
            let unlinked = ids.filter { !connected.contains($0) }
            let variants: [[String]]
            if let known = recoveredNativeSlotOrder?[owner] {
                variants = [known.filter { connected.contains($0) }]
            } else {
                guard let candidates = permutations(linked) else { return nil }
                variants = candidates
            }
            guard orders.count <= limit / sourceOrders.count / variants.count else { return nil }
            var next: [[String: [String]]] = []
            for order in orders {
                for variant in variants {
                    var candidate = order
                    candidate[owner] = recoveredNativeSlotOrder?[owner] ?? (variant + unlinked)
                    next.append(candidate)
                }
            }
            orders = next
        }
        var gates: [String: Bool] = [:]
        for id in switchDeviceIDs { gates[id] = closedSwitchIDs.contains(id) }
        for id in disrupterDeviceIDs {
            guard let phase = disrupterRotorAnglesByDeviceID[id], phase.isFinite else { return nil }
            gates[id] = CMOriginalWindowsPowerDisrupter.conducts(rotorAngle: phase)
        }
        var active = self
        active.cables = activeCables
        active.clearRuntimeCuts()
        let initial = NativePortState(signals: Dictionary(uniqueKeysWithValues:
            terminals.map { ($0.plugID, Float(0)) }))
        var consensusDevices: [String: Float]?
        var consensusWires: [Cable: Float]?
        for sourceOrder in sourceOrders {
            let events = sourceOrder.compactMap { id -> NativePortEvent? in
                guard let plug = groups[id]?.first, let value = values[id] else { return nil }
                return .source(plugID: plug.plugID, value: value)
            }
            guard events.count == sources.count else { return nil }
            for order in orders {
                guard let state = active.nativePortPass(previous: initial, events: events,
                    conductingByDeviceID: gates, observedSlotOrder: order) else { return nil }
                var devices: [String: Float] = [:]
                for (id, slots) in groups {
                    guard gates[id] != false else { continue }
                    if let known = recoveredNativeSlotOrder?[id], let first = known.first {
                        guard let value = state.signals[first] else { continue }
                        // Ammeter observes the greater of two slots.
                        if slots.first?.deviceType == "tmo_power_amperemeter",
                           known.count > 1, let second = state.signals[known[1]] {
                            let reading = max(value, second)
                            if reading > 0 { devices[id] = reading }
                        } else if value > 0 { devices[id] = value }
                    } else {
                        guard let first = slots.first, let value = state.signals[first.plugID],
                              value > 0, slots.allSatisfy({ state.signals[$0.plugID] == value })
                        else { continue }
                        devices[id] = value
                    }
                }
                var wires: [Cable: Float] = [:]
                for cable in active.cables {
                    guard let left = byPlugID[cable.firstPlugID],
                          let right = byPlugID[cable.secondPlugID],
                          !(sources.contains(left.deviceID) && sources.contains(right.deviceID)),
                          let value = state.signals[cable.firstPlugID], value > 0,
                          state.signals[cable.secondPlugID] == value else { continue }
                    wires[cable] = value
                }
                consensusDevices = consensusDevices.map { prior in
                    prior.filter { devices[$0.key] == $0.value }
                } ?? devices
                consensusWires = consensusWires.map { prior in
                    prior.filter { wires[$0.key] == $0.value }
                } ?? wires
            }
        }
        return NetworkObservation(deviceSignals: consensusDevices ?? [:],
                                  cableSignals: consensusWires ?? [:])
    }

    /// Isolate active connected components before solving. Runtime cuts
    /// split a component but never change the player's authored cables.
    private init(componentOf circuit: CMOriginalPowerCircuit,
                 owners: Set<String>, wires: Set<Cable>) {
        levelIndex = circuit.levelIndex
        sceneSHA256 = circuit.sceneSHA256
        let localTerminals = circuit.terminals.filter { owners.contains($0.deviceID) }
        terminals = localTerminals
        recoveredNativeSlotOrder = circuit.recoveredNativeSlotOrder?.filter { owners.contains($0.key) }
        recoveredNativeOwnerOrder = circuit.recoveredNativeOwnerOrder?.filter { owners.contains($0) }
        byPlugID = Dictionary(uniqueKeysWithValues: localTerminals.map { ($0.plugID, $0) })
        cables = wires
        sourceDeviceIDs = circuit.sourceDeviceIDs.intersection(owners)
        generatorDeviceIDs = circuit.generatorDeviceIDs.intersection(owners)
        solarDeviceIDs = circuit.solarDeviceIDs.intersection(owners)
        conditionalSourceDeviceIDs = circuit.conditionalSourceDeviceIDs.intersection(owners)
        passthroughDeviceIDs = circuit.passthroughDeviceIDs.intersection(owners)
        multiTerminalLoadDeviceIDs = circuit.multiTerminalLoadDeviceIDs.intersection(owners)
        switchDeviceIDs = circuit.switchDeviceIDs.intersection(owners)
        disrupterDeviceIDs = circuit.disrupterDeviceIDs.intersection(owners)
    }

    /// Apply the existing native-derived solver hierarchy independently
    /// to each active cable component. An unknown sample or 256-order
    /// budget overflow in one component cannot downgrade unrelated ones.
    /// Unsupported components still use the conservative legacy trace.
    public func componentwiseElectricalObservation(
        closedSwitchIDs: Set<String> = [],
        generatorRotorCommandsByDeviceID: [String: Float] = [:],
        solarRayContributionsByDeviceID: [String: [Float]] = [:],
        disrupterRotorAnglesByDeviceID: [String: Float] = [:],
        allowLegacyFallback: Bool = true
    ) -> NetworkObservation {
        var edges: [String: [(owner: String, wire: Cable)]] = [:]
        for wire in activeCables {
            guard let a = byPlugID[wire.firstPlugID],
                  let b = byPlugID[wire.secondPlugID] else { continue }
            edges[a.deviceID, default: []].append((b.deviceID, wire))
            edges[b.deviceID, default: []].append((a.deviceID, wire))
        }
        let sources = sourceDeviceIDs.union(conditionalSourceDeviceIDs)
        var visited = Set<String>()
        var devices: [String: Float] = [:]
        var cables: [Cable: Float] = [:]
        // Components without a source cannot produce positive signals.
        for source in sources.sorted() {
            guard visited.insert(source).inserted else { continue }
            var owners: Set<String> = [source]
            var wires = Set<Cable>()
            var queue = [source]
            var head = 0
            while head < queue.count {
                let owner = queue[head]
                head += 1
                for edge in edges[owner] ?? [] {
                    wires.insert(edge.wire)
                    if visited.insert(edge.owner).inserted {
                        owners.insert(edge.owner)
                        queue.append(edge.owner)
                    }
                }
            }
            let local = CMOriginalPowerCircuit(componentOf: self,
                                              owners: owners, wires: wires)
            let result = local.settledIndependentSourceObservation(
                closedSwitchIDs: closedSwitchIDs,
                generatorRotorCommandsByDeviceID: generatorRotorCommandsByDeviceID,
                solarRayContributionsByDeviceID: solarRayContributionsByDeviceID,
                disrupterRotorAnglesByDeviceID: disrupterRotorAnglesByDeviceID)
                ?? local.settledOrderConsensusObservation(
                    closedSwitchIDs: closedSwitchIDs,
                    generatorRotorCommandsByDeviceID: generatorRotorCommandsByDeviceID,
                    solarRayContributionsByDeviceID: solarRayContributionsByDeviceID,
                    disrupterRotorAnglesByDeviceID: disrupterRotorAnglesByDeviceID)
                ?? (allowLegacyFallback ? local.experimentalNetworkObservation(
                    closedSwitchIDs: closedSwitchIDs,
                    generatorRotorCommandsByDeviceID: generatorRotorCommandsByDeviceID,
                    solarRayContributionsByDeviceID: solarRayContributionsByDeviceID,
                    disrupterRotorAnglesByDeviceID: disrupterRotorAnglesByDeviceID)
                    : NetworkObservation(deviceSignals: [:], cableSignals: [:]))
            devices.merge(result.deviceSignals) { existing, _ in existing }
            cables.merge(result.cableSignals) { existing, _ in existing }
        }
        return NetworkObservation(deviceSignals: devices, cableSignals: cables)
    }

    /// Counterfactual electrical lamp power with every solar source dark.
    /// Keep actual cable topology and native-derived ordering constraints.
    /// Never use ambiguous legacy reachability to establish independent
    /// energy for a solar receiver. The renderer also requires matching
    /// positive full-network power before accepting this contribution.
    public func independentOpticalLampSignals(
        closedSwitchIDs: Set<String> = [],
        generatorRotorCommandsByDeviceID: [String: Float] = [:],
        disrupterRotorAnglesByDeviceID: [String: Float] = [:]
    ) -> [String: Float] {
        let dark = Dictionary(uniqueKeysWithValues:
            solarDeviceIDs.map { ($0, [Float]()) })
        let independent = componentwiseElectricalObservation(
            closedSwitchIDs: closedSwitchIDs,
            generatorRotorCommandsByDeviceID: generatorRotorCommandsByDeviceID,
            solarRayContributionsByDeviceID: dark,
            disrupterRotorAnglesByDeviceID: disrupterRotorAnglesByDeviceID,
            allowLegacyFallback: false)
        let lampIDs = Set(terminals.filter { $0.deviceType == "tmo_power_lamp" }.map(\.deviceID))
        return independent.deviceSignals.filter { lampIDs.contains($0.key) }
    }

    /// Compatibility entry for the earlier restricted battery-only bridge.
    public func settledSingleBatteryObservation(
        closedSwitchIDs: Set<String> = [],
        disrupterRotorAnglesByDeviceID: [String: Float] = [:]
    ) -> NetworkObservation? {
        guard sourceDeviceIDs.count == 1, conditionalSourceDeviceIDs.isEmpty else { return nil }
        return settledIndependentSourceObservation(closedSwitchIDs: closedSwitchIDs,
            disrupterRotorAnglesByDeviceID: disrupterRotorAnglesByDeviceID)
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

    public mutating func reset() {
        cables.removeAll(keepingCapacity: true)
        clearRuntimeCuts()
    }
}

/// Original 0x4579AD strict blade-angle threshold and 0x457285–0x4573E8
/// cut sampling. The live iOS straight Wire-to-Wire segment substitutes for
/// the native cable polyline, so the geometry is a documented reconstruction.
public enum CMOriginalScissorsCableGeometry {
    public static let activationAngle = Float(bitPattern: 0x3F060A92)
    public static let sampleStep = Float(bitPattern: 0x3A83126F)
    public static let hitDistanceSquared = Float(bitPattern: 0x38D1B717)

    public static func activates(firstAngle: Float, secondAngle: Float) -> Bool {
        guard firstAngle.isFinite, secondAngle.isFinite else { return false }
        let difference = firstAngle - secondAngle
        return difference.isFinite && abs(difference) > activationAngle
    }

    private static func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        a.x * b.x + a.y * b.y + a.z * b.z
    }

    public static func cuts(bladeStart: SIMD3<Float>, bladeEnd: SIMD3<Float>,
                            cableStart: SIMD3<Float>, cableEnd: SIMD3<Float>) -> Bool {
        guard [bladeStart, bladeEnd, cableStart, cableEnd].allSatisfy({
            $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
        }) else { return false }
        let blade = bladeEnd - bladeStart
        let wire = cableEnd - cableStart
        let bladeSquared = dot(blade, blade)
        let wireSquared = dot(wire, wire)
        guard bladeSquared.isFinite, wireSquared.isFinite,
              bladeSquared > 0, wireSquared > 0 else { return false }
        let length = sqrt(bladeSquared)
        // Imported blade UCMs are small; reject corrupt unbounded geometry
        // instead of spending an unbounded number of iterations per frame.
        guard length <= 4 else { return false }
        let direction = blade / length
        var sample: Float = 0
        while sample < length {
            let point = bladeStart + direction * sample
            let offset = point - cableStart
            let fraction = min(1, max(0, dot(offset, wire) / wireSquared))
            let delta = offset - wire * fraction
            if dot(delta, delta) < hitDistanceSquared { return true }
            sample += sampleStep
        }
        return false
    }
}
