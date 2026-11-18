import Foundation

@main struct UCMNegativeSmoke {
 static func put32(_ data:inout Data,_ offset:Int,_ value:UInt32) {
  for i in 0..<4 { data[offset+i]=UInt8(truncatingIfNeeded:value >> (8*i)) }
 }
 static func expectFailure(_ name:String,_ data:Data) {
  do { _=try CMUCMModel(data:data);fatalError("Accepted invalid UCM: \(name)") }
  catch is CMUCMError { print("rejected \(name)") }
  catch { fatalError("Unexpected error for \(name): \(error)") }
 }
 static func main() throws {
  guard CommandLine.arguments.count==2 else { fatalError("Pass one original .ucm fixture path") }
  let valid=try Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[1]))
  _=try CMUCMModel(data:valid)
  for length in 0..<92 { expectFailure("short-header-\(length)",Data(valid.prefix(length))) }
  var bad=valid;bad[0]=0;expectFailure("magic",bad)
  bad=valid;put32(&bad,4,99);expectFailure("version",bad)
  bad=valid;put32(&bad,72,0);expectFailure("zero-groups",bad)
  bad=valid;put32(&bad,80,0);expectFailure("zero-vertices",bad)
  bad=valid;put32(&bad,72,UInt32.max);expectFailure("oversized-groups",bad)
  bad=valid;put32(&bad,76,UInt32.max);expectFailure("oversized-faces",bad)
  bad=valid;put32(&bad,80,UInt32.max);expectFailure("oversized-vertices",bad)
  bad=valid;put32(&bad,84,UInt32.max);expectFailure("oversized-records",bad)
  bad=valid;bad.append(0);expectFailure("trailing-byte",bad)
  for cut in [1,2,4,8,16,32,64,128] where valid.count>cut {
   expectFailure("truncated-\(cut)",Data(valid.dropLast(cut)))
  }
  print("All UCM malformed-input cases rejected")
 }
}
