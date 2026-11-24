import Foundation

/// Verified native CrazyMachines.exe mechanical scalar arithmetic.
/// The original encrypted CML VALF parser at 0x4226DE..0x422730 writes
/// the Float into object +0xEC. A linked receiver at 0x44BAB2..0x44BAD0
/// receives: target.+0xE8 = source.+0xE8 * source.+0xEC / target.+0xEC.
/// Original gear link walker 0x44B955..0x44B963 separately negates the
/// receiving +0xE8. This code computes the native scalar only: it does
/// NOT prove any angular velocity or physical torque in SceneKit.
public enum CMOriginalWindowsMechanicalTransfer {
    public static func transmittedSignal(
        sourceSignal: Float, sourceVALF: Float, targetVALF: Float,
        reversesDirection: Bool = false
    ) -> Float? {
        guard sourceSignal.isFinite, sourceVALF.isFinite,
              targetVALF.isFinite, sourceVALF > 0,
              targetVALF > 0 else { return nil }
        let input = reversesDirection ? -Double(sourceSignal)
                                      : Double(sourceSignal)
        let output = input * Double(sourceVALF) / Double(targetVALF)
        guard output.isFinite,
              abs(output) <= Double(Float.greatestFiniteMagnitude)
        else { return nil }
        return Float(output)
    }

    /// Native 0x44BAD8..0x44BB0B: target += (0-target) * native timestep
    /// when an original runtime link flag +0x50 is nonzero. Neither the
    /// runtime flag nor the true +0x128 step is stored in CML; supply
    /// observed values only, never manufacture an activation or GOAL.
    public static func decayedSignal(
        previous: Float, observedNativeStep: Double
    ) -> Float? {
        guard previous.isFinite, observedNativeStep.isFinite,
              observedNativeStep >= 0, observedNativeStep <= 1 else {
            return nil
        }
        let result = Double(previous) * (1 - observedNativeStep)
        guard result.isFinite,
              abs(result) <= Double(Float.greatestFiniteMagnitude)
        else { return nil }
        return Float(result)
    }
}


/// Player-authored rope between exact named attachments in original UCMs.
/// The elastic tension is an iOS reconstruction, not recovered Win32 rope
/// solver constants. CONNECTED_TO objective references never create ropes.
public enum CMOriginalRope {
    public struct Endpoint: Hashable {
        public let objectID: String
        public let marker: String
        public init(objectID: String, marker: String) {
            self.objectID = objectID
            self.marker = marker
        }
    }

    public struct Pair: Hashable {
        public let first: Endpoint
        public let second: Endpoint
        public init?(_ a: Endpoint, _ b: Endpoint) {
            guard a.objectID != b.objectID else { return nil }
            if a.objectID < b.objectID {
                first = a; second = b
            } else {
                first = b; second = a
            }
        }
    }

    /// Names verified in the authentic rope UCMs; case-sensitive.
    public static func accepts(type: String, marker: String) -> Bool {
        switch type {
        case "tmo_rope_hook", "tmo_rope_cage", "tmo_rope_crossbow_lever", "tmo_pipe_ventil_lever", "tmo_balloon":
            return marker == "Rope"
        case "tmo_rope_scissors_1", "tmo_rope_scissors_2":
            return marker == "Rope01"
        case "tmo_rope_seesaw_lever":
            return marker == "Rope01" || marker == "Rope02"
        default:
            return false
        }
    }

    /// Retiring a simulated original owner must sever only its incident
    /// links. The editor's authored links are retained for replay.
    public static func incidentPairs(in pairs: Set<Pair>, retiredOwners: Set<String>) -> Set<Pair> {
        Set(pairs.filter {
            retiredOwners.contains($0.first.objectID) || retiredOwners.contains($0.second.objectID)
        })
    }

    /// A rope pulls only while stretched; never pushes, injects tension
    /// at rest, or changes authored length during the simulation.
    public static func tension(distance: Float, restLength: Float) -> Float {
        guard distance.isFinite, restLength.isFinite,
              restLength >= 0.01, restLength <= 30,
              distance > restLength, distance <= 60 else { return 0 }
        return min(25, (distance - restLength) * 35)
    }

    // Win32 rope/fuze-independent cut path 0x456FB0–0x4571D9.
    // 0x457042: rope samples every 0.05; 0x4571BB: blade samples
    // every 0.01; 0x4570F5: strict distance < 0.05. The actual game
    // samples its flexible rope; here the two live UCM endpoints define
    // a straight approximation. No native rope mesh or GOAL is inferred.
    public static func intersectsScissors(
        ropeStart: SIMD3<Float>, ropeEnd: SIMD3<Float>,
        bladeStart: SIMD3<Float>, bladeEnd: SIMD3<Float>
    ) -> Bool {
        guard [ropeStart, ropeEnd, bladeStart, bladeEnd].allSatisfy({
            $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
        }) else { return false }
        func dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
            a.x*b.x + a.y*b.y + a.z*b.z
        }
        let rope = ropeEnd - ropeStart
        let blade = bladeEnd - bladeStart
        let ropeLength = sqrt(dot(rope, rope))
        let bladeLength = sqrt(dot(blade, blade))
        guard ropeLength.isFinite, bladeLength.isFinite,
              ropeLength > 0, ropeLength <= 60,
              bladeLength > 0, bladeLength <= 4 else { return false }
        let ropeDirection = rope / ropeLength
        let bladeDirection = blade / bladeLength
        let ropeStep = Float(bitPattern: 0x3D4CCCCD)
        let bladeStep = Float(bitPattern: 0x3C23D70A)
        let cutoff = Float(bitPattern: 0x3D4CCCCD)
        // Cheap rejection for distant segments, without inventing
        // a cut based on overlapping bounding boxes alone.
        for axis in 0..<3 {
            if min(ropeStart[axis], ropeEnd[axis]) >
                max(bladeStart[axis], bladeEnd[axis]) + cutoff ||
                min(bladeStart[axis], bladeEnd[axis]) >
                max(ropeStart[axis], ropeEnd[axis]) + cutoff { return false }
        }
        var distance: Float = 0
        while distance < ropeLength {
            let point = ropeStart + ropeDirection * distance
            let projection = dot(point - bladeStart, bladeDirection)
            let index = max(0, min(floor(projection / bladeStep),
                                   ceil(bladeLength / bladeStep) - 1))
            // For a straight blade, its nearest discrete sample is one
            // of these two adjacent indices. Avoid a nested sampling loop.
            for sample in [index, index + 1] {
                let along = sample * bladeStep
                guard along < bladeLength else { continue }
                let difference = point - (bladeStart + bladeDirection * along)
                if sqrt(dot(difference, difference)) < cutoff { return true }
            }
            distance += ropeStep
        }
        return false
    }
}


/// Explicit open-belt link between authentic UCM "Wheel" attachments.
/// Native VALF ratio is recovered; SceneKit torque gain is provisional.
public enum CMOriginalDriveBelt {
    public struct Pair: Hashable {
        public let first: String
        public let second: String
        public init?(_ a: String, _ b: String) {
            guard !a.isEmpty, !b.isEmpty, a != b else { return nil }
            first = min(a, b); second = max(a, b)
        }
    }

    public static func accepts(type: String) -> Bool {
        ["tmo_belt_gear", "tmo_power_motor_rotor", "tmo_power_generator_rotor",
         "tmo_belt_conveyer_wheel", "tmo_power_disrupter_wheel", "tmo_steam_wheel",
         "tmo_windmill_wheel", "tmo_hammer_wheel", "tmo_belt_flag_wheel",
         "tmo_heat_grill_wheel"].contains(type)
    }

    /// Wheel marker basis in the imported original UCM files: the
    /// generator's local Y is the axle; the other nine use local Z.
    public static func wheelAxisColumn(type: String) -> Int? {
        guard accepts(type: type) else { return nil }
        return type == "tmo_power_generator_rotor" ? 1 : 2
    }

    /// The current puzzle belt renderer is planar XY. Accept either
    /// axle sign, including mirrored parts, but reject tilted wheels.
    /// This angular tolerance is a SceneKit adapter, not a native rule.
    public static func planarAxle(_ axis: SIMD3<Float>) -> Bool {
        guard [axis.x,axis.y,axis.z].allSatisfy(\.isFinite) else { return false }
        let length = hypot(hypot(axis.x,axis.y),axis.z)
        guard length.isFinite, length > 0.00001 else { return false }
        return abs(axis.z / length) >= 0.995
    }

    /// SceneKit angularVelocity is axis + magnitude, not XYZ rates.
    /// Project it onto world puzzle Z instead of using the sign alone.
    public static func planarAngularSpeed(axis: SIMD3<Float>, magnitude: Float) -> Float? {
        guard [axis.x,axis.y,axis.z,magnitude].allSatisfy(\.isFinite) else { return nil }
        if magnitude == 0 { return 0 }
        let length = hypot(hypot(axis.x,axis.y),axis.z)
        guard length.isFinite, length > 0.00001 else { return nil }
        let projected = magnitude * (axis.z / length)
        return projected.isFinite ? projected : nil
    }

    public struct Torque {
        public let first: Float
        public let second: Float
    }

    public static func correction(firstSpeed: Float, secondSpeed: Float,
                                  firstVALF: Float, secondVALF: Float) -> Torque? {
        guard [firstSpeed, secondSpeed, firstVALF, secondVALF].allSatisfy(\.isFinite),
              abs(firstSpeed) <= 80, abs(secondSpeed) <= 80,
              firstVALF >= 0.008, firstVALF <= 3,
              secondVALF >= 0.008, secondVALF <= 3 else { return nil }
        // Same-direction open belt constraint: w1*r1 = w2*r2.
        // Opposing reaction torques dissipate slip rather than generating
        // mechanical energy or spinning two stationary wheels.
        let slip = firstSpeed * firstVALF - secondSpeed * secondVALF
        guard abs(slip) > 0.005 else { return nil }
        let force = max(-8, min(8, slip * 6))
        return Torque(first: -force * firstVALF, second: force * secondVALF)
    }

    public struct Span {
        public let start: SIMD3<Float>
        public let end: SIMD3<Float>
    }

    /// Closed open-belt contour around the original Wheel marker radii.
    /// Coordinates are relative to the first wheel; the second is offset
    /// by the actual observed displacement. Arc tessellation is visual only.
    public static let arcSteps = 12
    public static let contourSpanCount = 2 + 2 * arcSteps

    public static func contour(offset: SIMD3<Float>, firstRadius: Float,
                               secondRadius: Float) -> [Span]? {
        guard let normals = tangentNormals(dx: offset.x, dy: offset.y, dz: offset.z,
            firstRadius: firstRadius, secondRadius: secondRadius) else { return nil }
        func point(_ n: SIMD2<Float>, radius: Float, center: SIMD3<Float>) -> SIMD3<Float> {
            center + SIMD3<Float>(n.x,n.y,0)*radius
        }
        let (plus,minus) = normals
        let aPlus = point(plus,radius:firstRadius,center:.zero)
        let aMinus = point(minus,radius:firstRadius,center:.zero)
        let bPlus = point(plus,radius:secondRadius,center:offset)
        let bMinus = point(minus,radius:secondRadius,center:offset)
        let direction = atan2(offset.y,offset.x)
        let distance = hypot(offset.x,offset.y)
        let theta = acos(min(1,max(-1,(firstRadius-secondRadius)/distance)))
        var result = [Span(start:aPlus,end:bPlus)]
        func arc(center: SIMD3<Float>, radius: Float, startAngle: Float,
                 sweep: Float, from: SIMD3<Float>, to: SIMD3<Float>) {
            var previous = from
            for index in 1...arcSteps {
                let angle = startAngle + sweep*Float(index)/Float(arcSteps)
                let next = index == arcSteps ? to :
                    center + SIMD3<Float>(cos(angle),sin(angle),0)*radius
                result.append(Span(start:previous,end:next))
                previous = next
            }
        }
        // Follow the second wheel's outward arc clockwise, then the
        // other external tangent, then the first wheel's outward arc.
        arc(center:offset,radius:secondRadius,startAngle:direction+theta,
            sweep:-2*theta,from:bPlus,to:bMinus)
        result.append(Span(start:bMinus,end:aMinus))
        arc(center:.zero,radius:firstRadius,startAngle:direction-theta,
            sweep:-(2 * .pi-2*theta),from:aMinus,to:aPlus)
        return result
    }

    /// Unit normal for the two external tangent spans in the puzzle XY plane.
    /// Reject coincident/intersecting or out-of-plane pulley configurations.
    public static func tangentNormals(dx: Float, dy: Float, dz: Float,
                                      firstRadius: Float, secondRadius: Float)
        -> (SIMD2<Float>, SIMD2<Float>)? {
        guard [dx, dy, dz, firstRadius, secondRadius].allSatisfy(\.isFinite),
              abs(dz) <= 0.05, firstRadius > 0, secondRadius > 0,
              firstRadius <= 3, secondRadius <= 3 else { return nil }
        let distance = hypot(dx, dy)
        guard distance.isFinite, distance > firstRadius + secondRadius,
              distance <= 30 else { return nil }
        let unit = SIMD2<Float>(dx, dy) / distance
        let side = SIMD2<Float>(-unit.y, unit.x)
        let cosine = (firstRadius - secondRadius) / distance
        let sine = sqrt(max(0, 1 - cosine * cosine))
        return (unit * cosine + side * sine, unit * cosine - side * sine)
    }
}


/// Win32 0x44BD1E–0x44BD78: tmo_heat_grill receives a mechanical
/// source and copies its negated +0xE8 into both children +0xE0.
/// This does not reconstruct thermal processing or its GOAL.
public enum CMOriginalGrillDrive {
    public static func linkedSignal(_ source: Float) -> Float? {
        source.isFinite ? -source : nil
    }

    /// iOS rotation bridge: integrate measured wheel angular velocity
    /// over actual running time, retaining a bounded phase. The original
    /// native scalar-to-physical-speed correspondence remains provisional.
    public static func phase(previous: Float, wheelSpeed: Float,
                             delta: Float) -> Float? {
        guard previous.isFinite, abs(previous) <= 2 * Float.pi,
              delta.isFinite, delta >= 0, delta <= 0.25,
              abs(wheelSpeed) <= 80,
              let speed = linkedSignal(wheelSpeed) else { return nil }
        return (previous + speed * delta).truncatingRemainder(dividingBy: 2 * .pi)
    }
}


/// Native candle->grill branch 0x44E4B1..0x44E717.
/// The source intersects the sausage Heat receiver, not the grill base.
/// Accumulated heat is stored separately from the sausage's RGB factor.
/// The same original material factor is written to all three channels.
public enum CMOriginalGrillHeat {
    public struct State {
        public var heat: Float = 0
        public var shade: Float = 1
        public var completed = false
        public init() {}
    }

    /// No intersecting source means this native branch is not executed.
    /// A non-rotating spit darkens while heat * 0.1 < 1; after that,
    /// GOAL requires both heat * 0.1 >= 1 and shade >= 0.75.
    public static func advance(_ previous: State, fraction: Float,
                               spitSignal: Float, delta: Double) -> State? {
        guard previous.heat.isFinite, previous.heat >= 0,
              previous.shade.isFinite, (0.2...1).contains(previous.shade),
              fraction.isFinite, (0...1).contains(fraction),
              spitSignal.isFinite, delta.isFinite,
              delta >= 0, delta <= 0.25 else { return nil }
        guard fraction > 0, !previous.completed else { return previous }
        var next = previous
        next.heat = Float(Double(previous.heat) + Double(fraction) * delta)
        guard next.heat.isFinite else { return nil }
        let progress = next.heat * Float(bitPattern: 0x3DCCCCCD)
        let candidate = progress < 1
            ? max(Float(bitPattern: 0x3E4CCCCD),
                  previous.shade - Float(delta * Double(Float(bitPattern: 0x3D4CCCCD))))
            : previous.shade
        if abs(spitSignal) < 1 { next.shade = candidate }
        // Native branch compares the candidate even when RGB was not written.
        next.completed = progress >= 1 && candidate >= 0.75
        return next
    }
}


/// Recovered portions of the Win32 hammer state machine 0x44BD7D–0x44C076.
/// Native +0xDC direction, timestep +0x128 and the marker gap must be
/// supplied by observation. This does not yet dispatch a gameplay GOAL.
public enum CMOriginalHammerDrive {
    public static let liftLimit = Float(bitPattern: 0x3FC90FDB)
    public static let releaseRate = Float(bitPattern: 0x40490FDB) * 2
    public static let strikeGap = Float(bitPattern: 0x3CCCCCCD)
    public static let nailLimit = Float(bitPattern: 0xBE2E147B)

    public struct Lift {
        public let angle: Float
        public let releases: Bool
    }

    public static func lift(angle: Float, wheelSignal: Float,
                            direction: Float, step: Double) -> Lift? {
        guard angle.isFinite, wheelSignal.isFinite,
              direction == 1 || direction == -1,
              step.isFinite, step >= 0 else { return nil }
        let value = Float(Double(angle) + Double(abs(wheelSignal)) * Double(direction) * 0.5 * step)
        guard value.isFinite else { return nil }
        return Lift(angle: value, releases: direction * value >= liftLimit)
    }

    public static func release(angle: Float, direction: Float,
                               step: Double) -> Float? {
        guard angle.isFinite, direction == 1 || direction == -1,
              step.isFinite, step >= 0 else { return nil }
        let value = Float(Double(angle) - Double(direction) * Double(releaseRate) * step)
        return value.isFinite ? value : nil
    }

    /// Win32 0x44BF1C–0x44BF45 adds direction * (pi/2 - acos(gap/scale)).
    /// The CRT wrapper 0x4D4D04 implements acos (0 maps to pi/2).
    /// Native scale must be supplied; SceneKit uses measured arm radius
    /// as an explicit approximation, not the unidentified PC global +0x20.
    public static func correctedAngle(angle: Float, direction: Float,
                                      gap: Float, scale: Float) -> Float? {
        guard angle.isFinite, direction == 1 || direction == -1,
              gap.isFinite, scale.isFinite, scale > 0,
              abs(gap) <= scale else { return nil }
        return angle + direction * (liftLimit - acos(gap / scale))
    }

    public struct Strike {
        public let nailY: Float
        public let terminal: Bool
    }

    /// Actual Nail attachment delta, not collision against the owner box.
    /// 0x44BEEC–0x44BF09 compares the measured gap with 0.025; then
    /// 0x44BF4B–0x44BF94 subtracts 0.025 and clamps only below -0.17.
    public static func strike(nailY: Float, observedGap: Float) -> Strike? {
        guard nailY.isFinite, observedGap.isFinite,
              nailY >= nailLimit, observedGap >= strikeGap else { return nil }
        let next = nailY - strikeGap
        return Strike(nailY: max(nailLimit, next), terminal: next < nailLimit)
    }
}


/// Persist only player-authored connections, never runtime cuts or forces.
/// The original level hash isolates preorder object IDs between scenes.
public enum CMOriginalMechanicalSnapshot {
    private struct RopeRecord: Codable {
        let firstID: String
        let firstMarker: String
        let secondID: String
        let secondMarker: String
    }
    private struct BeltRecord: Codable {
        let firstID: String
        let secondID: String
    }
    private struct Payload: Codable {
        let version: Int
        let sceneSHA256: String
        let ropes: [RopeRecord]
        let belts: [BeltRecord]
    }
    public struct Links {
        public let ropes: Set<CMOriginalRope.Pair>
        public let belts: Set<CMOriginalDriveBelt.Pair>
        public init(ropes: Set<CMOriginalRope.Pair> = [],
                    belts: Set<CMOriginalDriveBelt.Pair> = []) {
            self.ropes = ropes
            self.belts = belts
        }
    }

    public static func storageKey(sceneSHA256: String) -> String {
        "cm.original.mechanical-links.v1." + sceneSHA256
    }

    public static func encode(_ links: Links, sceneSHA256: String) throws -> Data {
        let ropes = links.ropes.map {
            RopeRecord(firstID: $0.first.objectID, firstMarker: $0.first.marker,
                secondID: $0.second.objectID, secondMarker: $0.second.marker)
        }.sorted {
            [$0.firstID,$0.firstMarker,$0.secondID,$0.secondMarker]
                .lexicographicallyPrecedes([$1.firstID,$1.firstMarker,$1.secondID,$1.secondMarker])
        }
        let belts = links.belts.map {
            BeltRecord(firstID: $0.first, secondID: $0.second)
        }.sorted {
            [$0.firstID,$0.secondID].lexicographicallyPrecedes([$1.firstID,$1.secondID])
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(Payload(version: 1, sceneSHA256: sceneSHA256,
            ropes: ropes, belts: belts))
    }

    /// Reject invalid snapshots atomically. Reconstruct through the same
    /// canonical pair initializers and type/marker gates used by the editor.
    public static func decode(_ data: Data, sceneSHA256: String,
                              objectTypes: [String: String]) -> Links? {
        guard data.count <= 64_000,
              let payload = try? JSONDecoder().decode(Payload.self, from: data),
              payload.version == 1, payload.sceneSHA256 == sceneSHA256,
              payload.ropes.count <= 64, payload.belts.count <= 64 else { return nil }
        var ropes = Set<CMOriginalRope.Pair>()
        var occupied = Set<CMOriginalRope.Endpoint>()
        for item in payload.ropes {
            guard let firstType = objectTypes[item.firstID],
                  let secondType = objectTypes[item.secondID],
                  CMOriginalRope.accepts(type: firstType, marker: item.firstMarker),
                  CMOriginalRope.accepts(type: secondType, marker: item.secondMarker) else { return nil }
            let a = CMOriginalRope.Endpoint(objectID: item.firstID, marker: item.firstMarker)
            let b = CMOriginalRope.Endpoint(objectID: item.secondID, marker: item.secondMarker)
            guard let pair = CMOriginalRope.Pair(a,b),
                  occupied.insert(a).inserted, occupied.insert(b).inserted,
                  ropes.insert(pair).inserted else { return nil }
        }
        var belts = Set<CMOriginalDriveBelt.Pair>()
        for item in payload.belts {
            guard let firstType = objectTypes[item.firstID],
                  let secondType = objectTypes[item.secondID],
                  CMOriginalDriveBelt.accepts(type: firstType),
                  CMOriginalDriveBelt.accepts(type: secondType),
                  let pair = CMOriginalDriveBelt.Pair(item.firstID,item.secondID),
                  belts.insert(pair).inserted else { return nil }
        }
        return Links(ropes: ropes, belts: belts)
    }
}


/// Game-only spring rebound adapter for authentic tmo_spring bodies.
/// Win32 0x444D3F..0x444E54 reads relative motion, tests its Y component,
/// scales by 20 and writes an output vector before setting spring +EC=1.
/// The native output-vector to SceneKit speed conversion is not recovered.
/// The bounded rebound below is a provisional planar physical adapter.
public enum CMOriginalSpringContact {
    public struct Pair: Hashable {
        public let spring: String
        public let striker: String
        public init(spring: String, striker: String) {
            self.spring = spring; self.striker = striker
        }
    }

    public struct Gate {
        private var active = Set<Pair>()
        public init() {}
        public mutating func accept(_ pair: Pair) -> Bool {
            guard pair.spring != pair.striker else { return false }
            return active.insert(pair).inserted
        }
        public mutating func end(_ pair: Pair) { active.remove(pair) }
    }

    public static func rebound(incoming: SIMD3<Float>, current: SIMD3<Float>,
                               axis: SIMD3<Float>, contact: SIMD3<Float>,
                               marker: SIMD3<Float>) -> SIMD3<Float>? {
        guard [incoming,current,axis,contact,marker].allSatisfy({
            $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
        }) else { return nil }
        let length = hypot(axis.x,axis.y)
        guard length > 0.0001, length.isFinite else { return nil }
        let n = SIMD3<Float>(axis.x/length,axis.y/length,0)
        func along(_ v: SIMD3<Float>) -> Float { v.x*n.x+v.y*n.y }
        // Genuine spring marker sits above the base. Reject underside
        // contacts instead of bouncing every body touching the mount.
        guard along(contact-marker) >= -0.03 else { return nil }
        let approach = -along(incoming)
        guard approach > 0.05 else { return nil }
        let desired = min(8,1.6*approach)
        let correction = desired - along(current)
        guard correction > 0, correction.isFinite else { return nil }
        let result = current+n*correction
        return SIMD3<Float>(result.x,result.y,0)
    }
}
