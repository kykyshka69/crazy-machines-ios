import Foundation
@main
struct OriginalWindowsRegionSelectorSmoke {
    static func main() {
        typealias S = CMOriginalWindowsRegionSelector
        let records: [S.Entry] = [
            .init(linkedNativeSelector: nil),
            .init(linkedNativeSelector: 2),
            .init(linkedNativeSelector: 3),
            .init(linkedNativeSelector: 5),
            .init(linkedNativeSelector: 3)
        ]
        precondition(S.matchingEntryIndex(in: records) == 2)
        precondition(S.matchingEntryIndex(in: records, occurrence: 1) == 4)
        precondition(S.matchingEntryIndex(in: records, occurrence: 2) == nil)
        precondition(S.matchingEntryIndex(in: records, selector: 2) == 1)
        precondition(S.matchingEntryIndex(in: records, selector: 5) == 3)
        precondition(S.matchingEntryIndex(in: records, selector: 1) == nil)
        precondition(S.matchingEntryIndex(in: records, occurrence: -1) == nil)
        precondition(S.matchingEntryIndex(in: records, occurrence: 1024) == nil)
        precondition(S.matchingEntryIndex(in: []) == nil)
        let dense = Array(repeating: S.Entry(linkedNativeSelector: 3), count: 1024)
        precondition(S.matchingEntryIndex(in: dense, occurrence: 1023) == 1023)
        let oversized = Array(repeating: S.Entry(linkedNativeSelector: 3), count: 4097)
        precondition(S.matchingEntryIndex(in: oversized) == nil)
        print("Win32 selector-3 original linked region record ordering passed")
    }
}
