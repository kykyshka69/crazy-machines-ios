#include <metal_stdlib>
using namespace metal;
struct CMMarkerUniforms { float4x4 modelViewProjection; };
struct CMMarkerOut { float4 position [[position]]; float pointSize [[point_size]]; };
vertex CMMarkerOut cmMarkerVertex(uint vertexID [[vertex_id]], const device packed_float3 *positions [[buffer(0)]], constant CMMarkerUniforms &u [[buffer(1)]]) {
 CMMarkerOut o;
 o.position=u.modelViewProjection*float4(float3(positions[vertexID]),1.0);
 o.pointSize=9.0;
 return o;
}
fragment float4 cmMarkerFragment(CMMarkerOut in [[stage_in]], float2 point [[point_coord]]) {
 float2 p=point*2.0-1.0;
 if(dot(p,p)>1.0) discard_fragment();
 return float4(1.0,0.22,0.15,1.0);
}
