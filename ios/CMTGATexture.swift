import Foundation
import Metal

public enum CMTGAError: Error {
 case invalidHeader, unsupportedFormat, invalidDimensions, truncated, allocationFailed
}

/// Decodes uncompressed 24/32-bit true-color TGA into top-left RGBA8.
public struct CMTGATexture {
 public let width:Int
 public let height:Int
 public let rgba:Data
 public init(data:Data) throws {
  let b=[UInt8](data)
  guard b.count >= 18 else { throw CMTGAError.invalidHeader }
  let id=Int(b[0]), w=Int(b[12]) | Int(b[13]) << 8, h=Int(b[14]) | Int(b[15]) << 8
  let depth=Int(b[16]), flags=b[17]
  guard b[1] == 0, b[2] == 2, (depth == 24 || depth == 32), flags & 0xC0 == 0 else { throw CMTGAError.unsupportedFormat }
  guard w>0,h>0,w<=16384,h<=16384,w<=Int.max/h,w*h<=64_000_000 else { throw CMTGAError.invalidDimensions }
  let stride=depth/8, count=w*h, start=18+id
  guard start<=b.count,count<=(b.count-start)/stride else { throw CMTGAError.truncated }
  var out=[UInt8](repeating:0,count:count*4)
  for y in 0..<h {
   for x in 0..<w {
    let src=start+(y*w+x)*stride
    let dx=(flags & 0x10 != 0) ? w-1-x : x
    let dy=(flags & 0x20 != 0) ? y : h-1-y
    let dst=(dy*w+dx)*4
    out[dst]=b[src+2];out[dst+1]=b[src+1];out[dst+2]=b[src]
    out[dst+3]=stride==4 ? b[src+3] : 255
   }
  }
  width=w;height=h;rgba=Data(out)
 }
 public func makeMetalTexture(device:MTLDevice) throws -> MTLTexture {
  let d=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:width,height:height,mipmapped:false)
  d.usage=[.shaderRead]
  guard let t=device.makeTexture(descriptor:d) else { throw CMTGAError.allocationFailed }
  rgba.withUnsafeBytes { bytes in
   t.replace(region:MTLRegionMake2D(0,0,width,height),mipmapLevel:0,withBytes:bytes.baseAddress!,bytesPerRow:width*4)
  }
  return t
 }
}
