#if !defined(MY_DEFERRED_SHADING)
#define MY_DEFERRED_SHADING

#include "UnityCG.cginc"

struct VertexData
{
	float4 vertex : POSITION;	
	float3 normal : NORMAL;
};

struct Interpolators
{
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
	float3 ray : TEXCOORD1;
};

UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);

Interpolators VertexProgram(VertexData v)
{
	Interpolators i;
	i.pos = UnityObjectToClipPos(v.vertex);
	i.uv = ComputeScreenPos(i.pos);
	i.ray = v.normal;
	return i;
}

float4 FragmentProgram(Interpolators i) : SV_TARGET
{
	float2 uv = i.uv.xy / i.uv.w;

	float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
	depth = Linear01Depth(depth);

	float3 rayToFarPlane = i.ray * _ProjectionParams.z / i.ray.z;
	float3 viewPos = rayToFarPlane * depth;
	float3 worldPos = mul(unity_CameraToWorld, float4(viewPos, 1)).xyz;

	return 0;
}

#endif