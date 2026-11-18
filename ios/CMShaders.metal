#include <metal_stdlib>
using namespace metal;
struct CMVertex { packed_float3 position; packed_float3 normal; packed_float2 uv; };
struct CMUniforms { float4x4 modelViewProjection; float4x4 model; float3 lightDirection; float ambient; };
struct CMOut { float4 position [[position]]; float2 uv; float3 normal; };
vertex CMOut cmVertex(uint vertexID [[vertex_id]], const device CMVertex *vertices [[buffer(0)]], constant CMUniforms &u [[buffer(1)]]) {
 CMVertex v=vertices[vertexID]; CMOut o;
 o.position=u.modelViewProjection*float4(float3(v.position),1);
 o.normal=normalize((u.model*float4(float3(v.normal),0)).xyz);
 o.uv=float2(v.uv); return o;
}
fragment float4 cmFragment(CMOut in [[stage_in]], texture2d<float> tex [[texture(0)]],
 sampler s [[sampler(0)]], constant CMUniforms &u [[buffer(1)]]) {
 float4 c=tex.sample(s,in.uv);
 float n=max(dot(normalize(in.normal),normalize(-u.lightDirection)),0.0);
 return float4(c.rgb*clamp(u.ambient+n,0.0,1.0),c.a);
}
