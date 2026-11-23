import Foundation

/// Selects genuinely lit original candles for SceneKit PLAYBACK only.
/// Native Win32 has separate tmo_candle_dyn behavior (0x44DAA8..0x44DB29).
/// The mobile candle's moving UCM Heat frame is not proof of native
/// selector-3 region overlap, Engine activation or puzzle GOAL.
public enum CMOriginalRocketSceneHeatSources {
    /// candle_dyn.ucm has one exact UCM Heat attachment, whose local +Z
    /// points into the 2D puzzle plane. Moving candles require a FRESH
    /// world transform from the SceneKit presentation tree every frame.
    public static func litCandleIDs(
        sourceStates: [String: Bool],
        originalTypesByID: [String: String],
        maximum: Int = 64
    ) -> [String] {
        guard maximum > 0 else { return [] }
        return Array(sourceStates.compactMap { id, isLit -> String? in
            guard isLit, !id.isEmpty,
                  originalTypesByID[id] == "tmo_candle"
                    || originalTypesByID[id] == "tmo_candle_dyn"
            else { return nil }
            return id
        }.sorted().prefix(min(maximum, 64)))
    }
}
