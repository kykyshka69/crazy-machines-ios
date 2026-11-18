import Foundation

@main struct TGAAssetSmoke {
 static func main() throws {
  guard CommandLine.arguments.count == 2 else { fatalError("Pass a directory of locally owned TGA files") }
  let root=URL(fileURLWithPath:CommandLine.arguments[1])
  let fm=FileManager.default
  guard let walker=fm.enumerator(at:root,includingPropertiesForKeys:nil) else { fatalError("Cannot enumerate folder") }
  var files=0,pixels=0,topOrigin=0,alpha=0
  for case let url as URL in walker where url.pathExtension.lowercased()=="tga" {
   let data=try Data(contentsOf:url)
   let image=try CMTGATexture(data:data)
   precondition(image.rgba.count==image.width*image.height*4)
   precondition(image.width>0 && image.height>0)
   pixels += image.width*image.height
   topOrigin += (data[17] & 0x20 != 0) ? 1 : 0
   alpha += (data[16] == 32) ? 1 : 0
   files += 1
  }
  print("TGA assets decoded: \(files); pixels: \(pixels); top-origin: \(topOrigin); 32-bit: \(alpha)")
  precondition(files==181 && topOrigin==3 && alpha==32,"Original texture inventory changed")
 }
}
