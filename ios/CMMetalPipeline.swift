import Metal
public enum CMMetalPipeline {
 public enum BlendMode { case opaque, additive, alpha, multiply }
 public static func make(device: MTLDevice, library: MTLLibrary, colorFormat: MTLPixelFormat,
                         depthFormat: MTLPixelFormat, blend: BlendMode) throws -> MTLRenderPipelineState {
  let d=MTLRenderPipelineDescriptor()
  d.vertexFunction=library.makeFunction(name:"cmVertex")
  d.fragmentFunction=library.makeFunction(name:"cmFragment")
  d.colorAttachments[0].pixelFormat=colorFormat
  d.depthAttachmentPixelFormat=depthFormat
  let a=d.colorAttachments[0]!
  switch blend {
  case .opaque: a.isBlendingEnabled=false
  case .additive:
   a.isBlendingEnabled=true
   a.sourceRGBBlendFactor = .one; a.destinationRGBBlendFactor = .one
   a.sourceAlphaBlendFactor = .one; a.destinationAlphaBlendFactor = .one
  case .alpha:
   a.isBlendingEnabled=true
   a.sourceRGBBlendFactor = .sourceAlpha; a.destinationRGBBlendFactor = .oneMinusSourceAlpha
   a.sourceAlphaBlendFactor = .one; a.destinationAlphaBlendFactor = .oneMinusSourceAlpha
  case .multiply:
   a.isBlendingEnabled=true
   a.sourceRGBBlendFactor = .zero; a.destinationRGBBlendFactor = .sourceColor
   a.sourceAlphaBlendFactor = .zero; a.destinationAlphaBlendFactor = .one
  }
  return try device.makeRenderPipelineState(descriptor:d)
 }
}
