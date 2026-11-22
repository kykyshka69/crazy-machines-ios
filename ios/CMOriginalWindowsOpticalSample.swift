import Foundation

/// Gates original Windows 0x409650 cone/light region and 0x44FD7D solar
/// attenuation on a REAL imported UCM path. No default native beam
/// properties, guessed emitter orientation or invented GOAL evidence.
public enum CMOriginalWindowsOpticalSample {
    public static func originalSolarContribution(
        sightline: CMOriginalOpticalSightline,
        beamOrigin: CMOriginalWindowsBeamRegion.Vector,
        beamForward: CMOriginalWindowsBeamRegion.Vector,
        receiverPoint: CMOriginalWindowsBeamRegion.Vector,
        nativeBeamParameters: CMOriginalWindowsBeamRegion.Parameters,
        observedEmitterPower: Float
    ) -> Float? {
        guard sightline.isUnobstructed,
              observedEmitterPower.isFinite,
              observedEmitterPower > 0,
              let hit = CMOriginalWindowsBeamRegion.intersect(
                  origin: beamOrigin, forward: beamForward,
                  target: receiverPoint, p: nativeBeamParameters
              ), hit.weight > 0 else { return nil }
        return CMOriginalWindowsSolarSignal.rayContribution(
            emitterPower: observedEmitterPower,
            interceptedFraction: hit.weight,
            pathLength: sightline.pathLength
        )
    }
}
