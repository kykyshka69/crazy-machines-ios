import Foundation
import Metal
import MetalKit
import simd

/// Geometry-only test renderer. White fallback texture; original materials not yet connected.
public final class CMSceneRenderer: NSObject, MTKViewDelegate {
 private let device: MTLDevice
 private let queue: MTLCommandQueue
 private let pipeline: MTLRenderPipelineState
 private let depthState: MTLDepthStencilState
 private let sampler: MTLSamplerState
 private let whiteTexture: MTLTexture
 private var modelTexture: MTLTexture?
 private var vertexBuffer: MTLBuffer?
 private var indexBuffer: MTLBuffer?
 private var indexCount = 0
 private var angle: Float = 0
 private var aspect: Float = 1

 private struct Uniforms {
  var modelViewProjection: simd_float4x4
  var model: simd_float4x4
  var lightDirection: SIMD3<Float>
  var ambient: Float
 }
 public init(view: MTKView) throws {
  guard let dev=view.device ?? MTLCreateSystemDefaultDevice(),
        let q=dev.makeCommandQueue(),
        let library=dev.makeDefaultLibrary() else { throw CMUCMError.invalidGeometry }
  device=dev;queue=q;view.device=dev
  view.colorPixelFormat = .bgra8Unorm
  view.depthStencilPixelFormat = .depth32Float
  view.clearColor=MTLClearColor(red:0.09,green:0.10,blue:0.13,alpha:1)
  pipeline=try CMMetalPipeline.make(device:dev,library:library,
    colorFormat:view.colorPixelFormat,depthFormat:view.depthStencilPixelFormat,blend:.opaque)
  let ds=MTLDepthStencilDescriptor()
  ds.depthCompareFunction = .less;ds.isDepthWriteEnabled=true
  guard let depth=dev.makeDepthStencilState(descriptor:ds) else { throw CMUCMError.invalidGeometry }
  depthState=depth
  let sd=MTLSamplerDescriptor()
  sd.minFilter = .linear;sd.magFilter = .linear;sd.sAddressMode = .repeat;sd.tAddressMode = .repeat
  guard let sample=dev.makeSamplerState(descriptor:sd) else { throw CMUCMError.invalidGeometry }
  sampler=sample
  let td=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.rgba8Unorm,width:1,height:1,mipmapped:false)
  td.usage=[.shaderRead]
  guard let texture=dev.makeTexture(descriptor:td) else { throw CMUCMError.invalidGeometry }
  var pixel:[UInt8]=[255,255,255,255]
  pixel.withUnsafeBytes { texture.replace(region:MTLRegionMake2D(0,0,1,1),mipmapLevel:0,withBytes:$0.baseAddress!,bytesPerRow:4) }
  whiteTexture=texture
  super.init()
  view.delegate=self
  mtkView(view,drawableSizeWillChange:view.drawableSize)
 }
 public func load(_ model:CMUCMModel) throws {
  vertexBuffer=try model.makeVertexBuffer(device:device)
  indexBuffer=try model.makeIndexBuffer(device:device)
  indexCount=model.indices.count
 }
 public func loadTexture(_ texture:CMTGATexture) throws {
  modelTexture=try texture.makeMetalTexture(device:device)
 }
 public func mtkView(_ view:MTKView,drawableSizeWillChange size:CGSize) {
  aspect=Float(size.width/max(size.height,1))
 }
 private func rotation(_ a:Float)->simd_float4x4 {
  let c=cos(a),s=sin(a)
  return simd_float4x4(columns:(SIMD4(c,0,-s,0),SIMD4(0,1,0,0),SIMD4(s,0,c,0),SIMD4(0,0,0,1)))
 }
 private func translation(_ z:Float)->simd_float4x4 {
  var m=matrix_identity_float4x4;m.columns.3.z=z;return m
 }
 private func perspective(_ fov:Float,_ aspect:Float,_ near:Float,_ far:Float)->simd_float4x4 {
  let y:Float=1/tan(fov/2),x=y/aspect,z=far/(near-far)
  return simd_float4x4(columns:(SIMD4(x,0,0,0),SIMD4(0,y,0,0),SIMD4(0,0,z,-1),SIMD4(0,0,z*near,0)))
 }
 public func draw(in view:MTKView) {
  guard let pass=view.currentRenderPassDescriptor,let drawable=view.currentDrawable,
        let vb=vertexBuffer,let ib=indexBuffer,indexCount>0,
        let cb=queue.makeCommandBuffer(),let encoder=cb.makeRenderCommandEncoder(descriptor:pass) else{return}
  angle += 0.007
  let model=rotation(angle)
  var uniforms=Uniforms(modelViewProjection:perspective(.pi/3,aspect,0.1,100)*translation(-4)*model,
                        model:model,lightDirection:SIMD3<Float>(-0.4,-0.7,-0.6),ambient:0.35)
  encoder.setRenderPipelineState(pipeline);encoder.setDepthStencilState(depthState)
  encoder.setVertexBuffer(vb,offset:0,index:0)
  encoder.setVertexBytes(&uniforms,length:MemoryLayout<Uniforms>.stride,index:1)
  encoder.setFragmentBytes(&uniforms,length:MemoryLayout<Uniforms>.stride,index:1)
  encoder.setFragmentTexture(modelTexture ?? whiteTexture,index:0);encoder.setFragmentSamplerState(sampler,index:0)
  encoder.drawIndexedPrimitives(type:.triangle,indexCount:indexCount,indexType:.uint16,indexBuffer:ib,indexBufferOffset:0)
  encoder.endEncoding();cb.present(drawable);cb.commit()
 }
}
