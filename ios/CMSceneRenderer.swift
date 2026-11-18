import Foundation
import Metal
import MetalKit
import simd

/// Geometry-only test renderer. White fallback texture; original materials not yet connected.
public final class CMSceneRenderer: NSObject, MTKViewDelegate {
 private let device: MTLDevice
 private let queue: MTLCommandQueue
 private let pipeline: MTLRenderPipelineState
 private let markerPipeline: MTLRenderPipelineState
 private let markerDepthState: MTLDepthStencilState
 private var markerBuffer: MTLBuffer?
 private var markerCount=0
 public var showDebugMarkers=true
 private let depthState: MTLDepthStencilState
 private let sampler: MTLSamplerState
 private let whiteTexture: MTLTexture
 private var modelTexture: MTLTexture?
 private var vertexBuffer: MTLBuffer?
 private var indexBuffer: MTLBuffer?
 private var indexCount = 0
 private var angle: Float = 0
 private var aspect: Float = 1
 private var framingCenter=SIMD3<Float>(repeating:0)
 private var framingRadius:Float=1

 private struct MarkerUniforms { var modelViewProjection:simd_float4x4 }
 private struct Uniforms {
  var modelViewProjection: simd_float4x4
  var model: simd_float4x4
  var lightDirectionAmbient: SIMD4<Float>
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
  guard let markerVertex=library.makeFunction(name:"cmMarkerVertex"),
        let markerFragment=library.makeFunction(name:"cmMarkerFragment") else { throw CMUCMError.invalidGeometry }
  let markerDescriptor=MTLRenderPipelineDescriptor()
  markerDescriptor.vertexFunction=markerVertex
  markerDescriptor.fragmentFunction=markerFragment
  markerDescriptor.colorAttachments[0].pixelFormat=view.colorPixelFormat
  markerDescriptor.depthAttachmentPixelFormat=view.depthStencilPixelFormat
  markerPipeline=try dev.makeRenderPipelineState(descriptor:markerDescriptor)
  let markerDepthDescriptor=MTLDepthStencilDescriptor()
  markerDepthDescriptor.depthCompareFunction = .always
  markerDepthDescriptor.isDepthWriteEnabled=false
  guard let markerDepth=dev.makeDepthStencilState(descriptor:markerDepthDescriptor) else { throw CMUCMError.invalidGeometry }
  markerDepthState=markerDepth
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
  // UCM vertices are 32-byte records with position at byte offset zero.
  // Compute bounds without assuming that every model is centered at origin.
  let raw=[UInt8](model.vertexData)
  func f32(_ offset:Int)->Float {
   let bits=UInt32(raw[offset]) | (UInt32(raw[offset+1]) << 8)
    | (UInt32(raw[offset+2]) << 16) | (UInt32(raw[offset+3]) << 24)
   return Float(bitPattern:bits)
  }
  var lo=SIMD3<Float>(repeating:Float.greatestFiniteMagnitude)
  var hi=SIMD3<Float>(repeating:-Float.greatestFiniteMagnitude)
  for i in 0..<model.vertexCount {
   let o=i*32
   let p=SIMD3<Float>(f32(o),f32(o+4),f32(o+8))
   guard p.x.isFinite && p.y.isFinite && p.z.isFinite else { throw CMUCMError.invalidGeometry }
   lo=simd_min(lo,p);hi=simd_max(hi,p)
  }
  framingCenter=(lo+hi)*0.5
  framingRadius=max(simd_length(hi-lo)*0.5,0.01)
 }
 public func loadDebugMarkers(_ slots:[CMAttachmentCatalog.Attachment]) throws {
  let positions=CMMarkerPoints.positions(slots)
  markerCount=positions.count
  if positions.isEmpty { markerBuffer=nil; return }
  // Metal packed_float3 has a 12-byte stride; SIMD3<Float> in Swift has a 16-byte stride.
  let floats=positions.flatMap { [$0.x,$0.y,$0.z] }
  guard let buffer=floats.withUnsafeBytes({ bytes in
   device.makeBuffer(bytes:bytes.baseAddress!,length:bytes.count,options:[])
  }) else { throw CMUCMError.invalidGeometry }
  markerBuffer=buffer
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
 private func translation(_ p:SIMD3<Float>)->simd_float4x4 {
  var m=matrix_identity_float4x4
  m.columns.3=SIMD4<Float>(p,1)
  return m
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
  let model=rotation(angle)*translation(-framingCenter)
  let distance=max(0.3,framingRadius*3.2)
  let far=max(100,distance+framingRadius*5)
  var uniforms=Uniforms(modelViewProjection:perspective(.pi/3,aspect,0.01,far)*translation(SIMD3<Float>(0,0,-distance))*model,
                        model:model,lightDirectionAmbient:SIMD4<Float>(-0.4,-0.7,-0.6,0.35))
  encoder.setRenderPipelineState(pipeline);encoder.setDepthStencilState(depthState)
  encoder.setVertexBuffer(vb,offset:0,index:0)
  encoder.setVertexBytes(&uniforms,length:MemoryLayout<Uniforms>.stride,index:1)
  encoder.setFragmentBytes(&uniforms,length:MemoryLayout<Uniforms>.stride,index:1)
  encoder.setFragmentTexture(modelTexture ?? whiteTexture,index:0);encoder.setFragmentSamplerState(sampler,index:0)
  encoder.drawIndexedPrimitives(type:.triangle,indexCount:indexCount,indexType:.uint16,indexBuffer:ib,indexBufferOffset:0)
  if showDebugMarkers,markerCount>0,let markers=markerBuffer {
   var markerUniforms=MarkerUniforms(modelViewProjection:uniforms.modelViewProjection)
   encoder.setRenderPipelineState(markerPipeline)
   encoder.setDepthStencilState(markerDepthState)
   encoder.setVertexBuffer(markers,offset:0,index:0)
   encoder.setVertexBytes(&markerUniforms,length:MemoryLayout<MarkerUniforms>.stride,index:1)
   encoder.drawPrimitives(type:.point,vertexStart:0,vertexCount:markerCount)
  }
  encoder.endEncoding();cb.present(drawable);cb.commit()
 }
}
