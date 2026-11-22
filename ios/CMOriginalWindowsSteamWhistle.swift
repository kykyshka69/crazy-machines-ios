import Foundation

/// Grounded in the original CrazyMachines.exe x86 path at 0x44C7D1–0x44C7EF.
/// Genuine tmo_pipe_whistle receives a steam component +0x40 and invokes
/// GOAL when its float value is GREATER THAN OR EQUAL TO 1.0.
/// At 0x44C7DF: test ah, 0x01; at 0x44C7E2: jne skip, so x87
/// equality (C0=0) is accepted. This differs from other goal cutoffs.
/// No steam pressure may be fabricated from cable voltage or touch.
public enum CMOriginalWindowsSteamWhistle {
    public static let cutoff: Float = 1.0

    public static func triggersGoal(steamPower: Float) -> Bool {
        steamPower.isFinite && steamPower >= cutoff
    }
}
