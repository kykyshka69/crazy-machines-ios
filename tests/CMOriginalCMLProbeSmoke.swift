import Foundation

@main
struct CMOriginalCMLProbeSmoke {
    static func main() {
        let data = Data([0, 0, 72, 69, 76, 76, 79, 87, 79, 82, 76, 68, 0])
        let probe = CMOriginalCMLProbe(data: data)
        precondition(probe.byteCount == data.count)
        precondition(probe.zeroByteCount == 3)
        precondition(probe.headerHex.hasPrefix("00 00 48 45"))
        precondition(probe.asciiClues == ["HELLOWORLD"])
        let empty = CMOriginalCMLProbe(data: Data())
        precondition(empty.byteCount == 0 && empty.asciiClues.isEmpty)
        print("Original CML metadata probe: OK")
    }
}
