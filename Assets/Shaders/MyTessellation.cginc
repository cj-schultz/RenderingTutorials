﻿// Upgrade NOTE: replaced 'defined _TESSELLATION_EDGE' with 'defined (_TESSELLATION_EDGE)'

#if !defined(TESSELLATION_INCLUDED)
#define TESSELLATION_INCLUDED



struct TessellationFactors
{
	float edge[3] : SV_TessFactor;
	float inside : SV_InsideTessFactor;
};

struct TessellationControlPoint 
{
	float4 vertex : INTERNALTESSPOS;
	float3 normal : NORMAL;
	float4 tangent : TANGENT;
	float2 uv : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float2 uv2 : TEXCOORD2;
};

TessellationControlPoint MyTessellationVertexProgram(VertexData v)
{
	TessellationControlPoint p;
	p.vertex = v.vertex;
	p.normal = v.normal;
	p.tangent = v.tangent;
	p.uv = v.uv;
	p.uv1 = v.uv1;
	p.uv2 = v.uv2;
	return p;
}

[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("fractional_odd")]
[UNITY_patchconstantfunc("MyPatchConstantFunction")]
TessellationControlPoint MyHullProgram(InputPatch<TessellationControlPoint, 3> patch, uint id : SV_OutputControlPointID)
{
	return patch[id];
}

[UNITY_domain("tri")]
InterpolatorsVertex MyDomainProgram(TessellationFactors factors, OutputPatch<VertexData, 3> patch, float3 baryCoords : SV_DomainLocation)
{
	VertexData data;

#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName = \
		patch[0].fieldName * baryCoords.x + \
		patch[1].fieldName * baryCoords.y + \
		patch[2].fieldName * baryCoords.z;
	
	MY_DOMAIN_PROGRAM_INTERPOLATE(vertex);
	MY_DOMAIN_PROGRAM_INTERPOLATE(normal);
	MY_DOMAIN_PROGRAM_INTERPOLATE(tangent);
	MY_DOMAIN_PROGRAM_INTERPOLATE(uv);
	MY_DOMAIN_PROGRAM_INTERPOLATE(uv1);
	MY_DOMAIN_PROGRAM_INTERPOLATE(uv2);

	return MyVertexProgram(data);
}

float _TessellationUniform;
float _TessellationEdgeLength;

float TessellationEdgeFactor(float3 p0, float3 p1)
{
#if defined (_TESSELLATION_EDGE)	
	float edgeLength = distance(p0, p1);

	float3 edgeCenter = (p0 + p1) * 0.5;
	float viewDistance = distance(edgeCenter, _WorldSpaceCameraPos);

	return edgeLength * _ScreenParams.y / (_TessellationEdgeLength * viewDistance);;
#else
	return _TessellationUniform;
#endif	
}

TessellationFactors MyPatchConstantFunction(InputPatch<TessellationControlPoint, 3> patch)
{
	float3 p0 = mul(unity_ObjectToWorld, patch[0].vertex).xyz;
	float3 p1 = mul(unity_ObjectToWorld, patch[1].vertex).xyz;
	float3 p2 = mul(unity_ObjectToWorld, patch[2].vertex).xyz;
	TessellationFactors f;
	f.edge[0] = TessellationEdgeFactor(p1, p2);
	f.edge[1] = TessellationEdgeFactor(p2, p0);
	f.edge[2] = TessellationEdgeFactor(p0, p1);
	f.inside =
		(TessellationEdgeFactor(p1, p2) +
			TessellationEdgeFactor(p2, p0) +
			TessellationEdgeFactor(p0, p1)) * (1 / 3.0);
	return f;
}

#endif