import Foundation

/// Win32 0x420360 -> 0x4204A0 walks 0x54-byte native region records.
/// A record qualifies ONLY with a +0x44 linked object whose selector
/// byte at +0x10 matches. No synthetic geometry or SceneKit hit is made.
public enum CMOriginalWindowsRegionSelector {
    public struct Entry {
        /// Nil means that the native entry's +0x44 pointer is absent.
        public let linkedNativeSelector: UInt8?
        public init(linkedNativeSelector: UInt8?) {
            self.linkedNativeSelector = linkedNativeSelector
        }
    }

    /// The original candle and rocket both ask for selector 3, ordinal 0.
    /// Count only linked matching entries and return the REAL record index
    /// to bind physically measured +0x24 geometry to the selected object.
    public static func matchingEntryIndex(
        in nativeRecords: [Entry],
        selector: UInt8 = 3,
        occurrence: Int = 0
    ) -> Int? {
        guard occurrence >= 0, occurrence < 1_024,
              nativeRecords.count <= 4_096 else { return nil }
        var matches = 0
        for (index, record) in nativeRecords.enumerated() {
            guard record.linkedNativeSelector == selector else { continue }
            if matches == occurrence { return index }
            matches += 1
        }
        return nil
    }
}
