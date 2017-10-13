#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

sampler2D _MainTex, _DetailTex;
float4 _MainTex_ST, _DetailTex_ST;

float4 _Tint;
float _Metallic;
float _Smoothness;

sampler2D _NormalMap, _DetailNormalMap;
float _BumpScale, _DetailBumpScale;

struct VertexData 
{
	float4 vertex : POSITION;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float2 uv : TEXCOORD0;
};

struct Interpolators 
{
	float4 pos : SV_POSITION;
	float4 uv : TEXCOORD0;
	float3 normal : TEXCOORD1;

#ifdef BINORMAL_PER_FRAGMENT
	float4 tangent : TEXCOORD2;
#else
	float3 tangent : TEXCOORD2;
	float3 binormal : TEXCOORD3;
#endif

	float3 worldPos : TEXCOORD4;

	SHADOW_COORDS(5)

#ifdef VERTEXLIGHT_ON
	float3 vertexLightColor : TEXCOORD6;
#endif
};

void ComputeVertexLightColor(inout Interpolators i) 
{
#if defined(VERTEXLIGHT_ON)
	i.vertexLightColor = Shade4PointLights(
		unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
		unity_LightColor[0].rgb, unity_LightColor[1].rgb,
		unity_LightColor[2].rgb, unity_LightColor[3].rgb,
		unity_4LightAtten0, i.worldPos, i.normal
	);
#endif
}

float3 CreateBinormal(float3 normal, float3 tangent, float binormalSign)
{
	return cross(normal, tangent.xyz) * (binormalSign * unity_WorldTransformParams.w);
}

Interpolators MyVertexProgram(VertexData v)
{
	Interpolators i;
	i.pos = UnityObjectToClipPos(v.vertex);
	i.worldPos = mul(unity_ObjectToWorld, v.vertex);
	i.normal = UnityObjectToWorldNormal(v.normal);
#ifdef BINORMAL_PER_FRAGMENT
	i.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
#else
	i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
	i.binormal = CreateBinormal(i.normal, i.tangent.xyz, v.tangent.w);
#endif
	i.uv.xy = TRANSFORM_TEX(v.uv, _MainTex);
	i.uv.zw = TRANSFORM_TEX(v.uv, _DetailTex);	

	TRANSFER_SHADOW(i);

	ComputeVertexLightColor(i);
	return i;
}

UnityLight CreateLight(Interpolators i)
{
	UnityLight light;	

#if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT) 
	light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
#else
	light.dir = _WorldSpaceLightPos0.xyz;
#endif

	UNITY_LIGHT_ATTENUATION(attenuation, i, i.worldPos);

	light.color = _LightColor0.rgb * attenuation;	
	light.ndotl = DotClamped(i.normal, light.dir);
	return light;
}

float3 BoxProjection(float3 direction, float3 position, float3 cubemapPosition, float3 boxMin, float3 boxMax)
{
	boxMin -= position;
	boxMax -= position;
	float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;	
	float scalar = min(min(factors.x, factors.y), factors.z);
	return direction * scalar + (position - cubemapPosition);
}

UnityIndirect CreateIndirectLight(Interpolators i, float3 viewDir)
{
	UnityIndirect indirectLight;
	indirectLight.diffuse = 0;
	indirectLight.specular = 0;

#ifdef VERTEXLIGHT_ON
	indirectLight.diffuse = i.vertexLightColor;	
#endif

#ifdef FORWARD_BASE_PASS
	indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));	
	float3 reflectionDir = reflect(-viewDir, i.normal);

	Unity_GlossyEnvironmentData envData;
	envData.roughness = 1 - _Smoothness;
	envData.reflUVW = BoxProjection(reflectionDir, i.worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
	indirectLight.specular = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);
#endif
	return indirectLight;
}

void InitializeFragmentNormal(inout Interpolators i)
{
	float3 mainNormal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _BumpScale);
	float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailBumpScale);
	float3 tangentSpaceNormal = BlendNormals(mainNormal, detailNormal);
	
#ifdef BINORMAL_PER_FRAGMENT
	float3 binormal = cross(i.normal, i.tangent.xyz) * (i.tangent.w * unity_WorldTransformParams.w);
#else
	float3 binormal = i.binormal;
#endif

	i.normal = normalize(
		tangentSpaceNormal.x * i.tangent +
		tangentSpaceNormal.y * binormal + 
		tangentSpaceNormal.z * i.normal
	);
	//i.normal = i.normal.xzy;	
}

float4 MyFragmentProgram(Interpolators i) : SV_TARGET
{
	InitializeFragmentNormal(i);

	float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

	float3 albedo = tex2D(_MainTex, i.uv.xy).rgb * _Tint.rgb;	
	albedo *= tex2D(_DetailTex, i.uv.zw) * unity_ColorSpaceDouble;

	float3 specularTint;
	float oneMinusReflectivity;
	albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, specularTint, oneMinusReflectivity);		
		
	return UNITY_BRDF_PBS(
		albedo, specularTint,
		oneMinusReflectivity, _Smoothness, // NOTE(colin): 1 - roughness = _Smoothness
		i.normal, viewDir,
		CreateLight(i), CreateIndirectLight(i, viewDir)
	);
}
#endif