import Foundation

/// The original Win32 power-switch *contact* predicate at 0x44C98B..0x44CA2B.
///
/// The incoming electrical node +0x40 is set to ZERO only when the selected
/// switch-side physics scalar (+0xEC) equals ±1 but the mating contact scalar
/// (+0xC8) differs from that same exact sign. Other non-NaN scalar positions
/// leave the existing value untouched. This is NOT a lever-animation rule.
///
/// Original contact scalars cannot be inferred from SwiftUI tap bools or
/// a SceneKit Euler angle without recovering Win32 0x41F7C0/0x41F4D0.
public enum CMOriginalWindowsSwitchContactGate {
    public struct ContactPair: Equatable {
        public let selectedContact: Float
        public let matingContact: Float
        public init(selectedContact: Float, matingContact: Float) {
            self.selectedContact = selectedContact
            self.matingContact = matingContact
        }
    }

    /// Returns nil if either field is unavailable/nonfinite: never manufacture
    /// a conductive circuit from a NaN/unknown original contact state.
    public static func preservesPower(_ pair: ContactPair) -> Bool? {
        guard pair.selectedContact.isFinite, pair.matingContact.isFinite else {
            return nil
        }
        if pair.selectedContact == 1 { return pair.matingContact == 1 }
        if pair.selectedContact == -1 { return pair.matingContact == -1 }
        // Windows skips its zero-write when first contact is neither ±1.
        // This does NOT prove a physically closed switch for an unpowered node.
        return true
    }

    /// Apply Win32 branch to an ALREADY-observed electrical input. The real
    /// traversal and node +0x50/renderer propagation are separate mechanisms.
    public static func propagatedPower(
        _ incoming: Float,
        contacts: ContactPair
    ) -> Float? {
        guard incoming.isFinite, let preserve = preservesPower(contacts) else {
            return nil
        }
        return preserve ? incoming : 0
    }
}