#ifndef UNITY_SHADER_VARIABLES_INCLUDED
#define UNITY_SHADER_VARIABLES_INCLUDED

#include "HLSLSupport.cginc"

#if defined (DIRECTIONAL_COOKIE) || defined (DIRECTIONAL)
#define USING_DIRECTIONAL_LIGHT
#endif

#if defined (INSTANCING_ON) || defined (UNITY_SINGLE_PASS_STEREO)
// Use separate matrices in this case.
#else
#define UNITY_USE_PREMULTIPLIED_MATRICES
#endif

#ifdef UNITY_SINGLE_PASS_STEREO
	#define glstate_matrix_projection unity_StereoMatrixP[unity_StereoEyeIndex]
	#define unity_MatrixV unity_StereoMatrixV[unity_StereoEyeIndex]
	#define unity_MatrixInvV unity_StereoMatrixInvV[unity_StereoEyeIndex]
	#define unity_MatrixVP unity_StereoMatrixVP[unity_StereoEyeIndex]

	#define unity_CameraProjection unity_StereoCameraProjection[unity_StereoEyeIndex]
	#define unity_CameraInvProjection unity_StereoCameraInvProjection[unity_StereoEyeIndex]
	#define unity_WorldToCamera unity_StereoWorldToCamera[unity_StereoEyeIndex]
	#define unity_CameraToWorld unity_StereoCameraToWorld[unity_StereoEyeIndex]

	#define _WorldSpaceCameraPos unity_StereoWorldSpaceCameraPos[unity_StereoEyeIndex]
#endif

#define UNITY_MATRIX_P glstate_matrix_projection
#define UNITY_MATRIX_V unity_MatrixV
#define UNITY_MATRIX_I_V unity_MatrixInvV
#define UNITY_MATRIX_VP unity_MatrixVP
#define UNITY_MATRIX_M unity_ObjectToWorld

#ifdef UNITY_USE_PREMULTIPLIED_MATRICES
	#define UNITY_MATRIX_MVP glstate_matrix_mvp
	#define UNITY_MATRIX_MV glstate_matrix_modelview0
	#define UNITY_MATRIX_T_MV glstate_matrix_transpose_modelview0
	#define UNITY_MATRIX_IT_MV glstate_matrix_invtrans_modelview0
#else
	#define UNITY_MATRIX_MVP mul(unity_MatrixVP, unity_ObjectToWorld)
	#define UNITY_MATRIX_MV mul(unity_MatrixV, unity_ObjectToWorld)
	#define UNITY_MATRIX_T_MV transpose(UNITY_MATRIX_MV)
	#define UNITY_MATRIX_IT_MV transpose(mul(unity_WorldToObject, unity_MatrixInvV))
#endif

#define UNITY_LIGHTMODEL_AMBIENT (glstate_lightmodel_ambient * 2)

// ----------------------------------------------------------------------------


CBUFFER_START(UnityPerCamera)
	// Time (t = time since current level load) values from Unity
	float4 _Time; // (t/20, t, t*2, t*3)
	float4 _SinTime; // sin(t/8), sin(t/4), sin(t/2), sin(t)
	float4 _CosTime; // cos(t/8), cos(t/4), cos(t/2), cos(t)
	float4 unity_DeltaTime; // dt, 1/dt, smoothdt, 1/smoothdt
	
#ifndef UNITY_SINGLE_PASS_STEREO
	float3 _WorldSpaceCameraPos;
#endif
	
	// x = 1 or -1 (-1 if projection is flipped)
	// y = near plane
	// z = far plane
	// w = 1/far plane
	float4 _ProjectionParams;
	
	// x = width
	// y = height
	// z = 1 + 1.0/width
	// w = 1 + 1.0/height
	float4 _ScreenParams;
	
	// Values used to linearize the Z buffer (http://www.humus.name/temp/Linearize%20depth.txt)
	// x = 1-far/near
	// y = far/near
	// z = x/far
	// w = y/far
	float4 _ZBufferParams;

	// x = orthographic camera's width
	// y = orthographic camera's height
	// z = unused
	// w = 1.0 if camera is ortho, 0.0 if perspective
	float4 unity_OrthoParams;
CBUFFER_END


CBUFFER_START(UnityPerCameraRare)
	float4 unity_CameraWorldClipPlanes[6];

#ifndef UNITY_SINGLE_PASS_STEREO
	// Projection matrices of the camera. Note that this might be different from projection matrix
	// that is set right now, e.g. while rendering shadows the matrices below are still the projection
	// of original camera.
	float4x4 unity_CameraProjection;
	float4x4 unity_CameraInvProjection;
	float4x4 unity_WorldToCamera;
	float4x4 unity_CameraToWorld;
#endif
CBUFFER_END



// ----------------------------------------------------------------------------

CBUFFER_START(UnityLighting)

	#ifdef USING_DIRECTIONAL_LIGHT
	half4 _WorldSpaceLightPos0;
	#else
	float4 _WorldSpaceLightPos0;
	#endif

	float4 _LightPositionRange; // xyz = pos, w = 1/range

	float4 unity_4LightPosX0;
	float4 unity_4LightPosY0;
	float4 unity_4LightPosZ0;
	half4 unity_4LightAtten0;

	half4 unity_LightColor[8];


	float4 unity_LightPosition[8]; // view-space vertex light positions (position,1), or (-direction,0) for directional lights.
	// x = cos(spotAngle/2) or -1 for non-spot
	// y = 1/cos(spotAngle/4) or 1 for non-spot
	// z = quadratic attenuation
	// w = range*range
	half4 unity_LightAtten[8];
	float4 unity_SpotDirection[8]; // view-space spot light directions, or (0,0,1,0) for non-spot

	// SH lighting environment
	half4 unity_SHAr;
	half4 unity_SHAg;
	half4 unity_SHAb;
	half4 unity_SHBr;
	half4 unity_SHBg;
	half4 unity_SHBb;
	half4 unity_SHC;
CBUFFER_END

CBUFFER_START(UnityLightingOld)
	half3 unity_LightColor0, unity_LightColor1, unity_LightColor2, unity_LightColor3; // keeping those only for any existing shaders; remove in 4.0
CBUFFER_END


// ----------------------------------------------------------------------------

CBUFFER_START(UnityShadows)
	float4 unity_ShadowSplitSpheres[4];
	float4 unity_ShadowSplitSqRadii;
	float4 unity_LightShadowBias;
	float4 _LightSplitsNear;
	float4 _LightSplitsFar;
	float4x4 unity_WorldToShadow[4];
	half4 _LightShadowData;
	float4 unity_ShadowFadeCenterAndType;
CBUFFER_END

// ----------------------------------------------------------------------------

CBUFFER_START(UnityPerDraw)
#ifdef UNITY_USE_PREMULTIPLIED_MATRICES
	float4x4 glstate_matrix_mvp;
	float4x4 glstate_matrix_modelview0;
	float4x4 glstate_matrix_invtrans_modelview0;
#endif
	
	float4x4 unity_ObjectToWorld;
	float4x4 unity_WorldToObject;
	float4 unity_LODFade; // x is the fade value ranging within [0,1]. y is x quantized into 16 levels
	float4 unity_WorldTransformParams; // w is usually 1.0, or -1.0 for odd-negative scale transforms
CBUFFER_END

#ifdef UNITY_SINGLE_PASS_STEREO
CBUFFER_START(UnityStereoGlobals)
	float4x4 unity_StereoMatrixP[2];
	float4x4 unity_StereoMatrixV[2];
	float4x4 unity_StereoMatrixInvV[2];
	float4x4 unity_StereoMatrixVP[2];

	float4x4 unity_StereoCameraProjection[2];
	float4x4 unity_StereoCameraInvProjection[2];
	float4x4 unity_StereoWorldToCamera[2];
	float4x4 unity_StereoCameraToWorld[2];

	float3 unity_StereoWorldSpaceCameraPos[2];
	float4 unity_StereoScaleOffset[2];
CBUFFER_END

CBUFFER_START(UnityStereoEyeIndex)
	int unity_StereoEyeIndex;
CBUFFER_END
#endif

CBUFFER_START(UnityPerDrawRare)
	float4x4 glstate_matrix_transpose_modelview0;
CBUFFER_END


// ----------------------------------------------------------------------------

CBUFFER_START(UnityPerFrame)
	
	fixed4 glstate_lightmodel_ambient;
	fixed4 unity_AmbientSky;
	fixed4 unity_AmbientEquator;
	fixed4 unity_AmbientGround;
	fixed4 unity_IndirectSpecColor;

#ifndef UNITY_SINGLE_PASS_STEREO
	float4x4 glstate_matrix_projection;
	float4x4 unity_MatrixV;
	float4x4 unity_MatrixInvV;
	float4x4 unity_MatrixVP;
	int unity_StereoEyeIndex;
#endif

CBUFFER_END


// ----------------------------------------------------------------------------

CBUFFER_START(UnityFog)
	fixed4 unity_FogColor;
	// x = density / sqrt(ln(2)), useful for Exp2 mode
	// y = density / ln(2), useful for Exp mode
	// z = -1/(end-start), useful for Linear mode
	// w = end/(end-start), useful for Linear mode
	float4 unity_FogParams;
CBUFFER_END


// ----------------------------------------------------------------------------
// Lightmaps

// Main lightmap
UNITY_DECLARE_TEX2D(unity_Lightmap);
// Dual or directional lightmap (always used with unity_Lightmap, so can share sampler)
UNITY_DECLARE_TEX2D_NOSAMPLER(unity_LightmapInd);

// Dynamic GI lightmap
UNITY_DECLARE_TEX2D(unity_DynamicLightmap);
UNITY_DECLARE_TEX2D_NOSAMPLER(unity_DynamicDirectionality);
UNITY_DECLARE_TEX2D_NOSAMPLER(unity_DynamicNormal);

CBUFFER_START(UnityLightmaps)
	float4 unity_LightmapST;
	float4 unity_DynamicLightmapST;
CBUFFER_END


// ----------------------------------------------------------------------------
// Reflection Probes

UNITY_DECLARE_TEXCUBE(unity_SpecCube0);
UNITY_DECLARE_TEXCUBE_NOSAMPLER(unity_SpecCube1);

CBUFFER_START(UnityReflectionProbes)
	float4 unity_SpecCube0_BoxMax;
	float4 unity_SpecCube0_BoxMin;
	float4 unity_SpecCube0_ProbePosition;
	half4  unity_SpecCube0_HDR;

	float4 unity_SpecCube1_BoxMax;
	float4 unity_SpecCube1_BoxMin;
	float4 unity_SpecCube1_ProbePosition;
	half4  unity_SpecCube1_HDR;
CBUFFER_END


// ----------------------------------------------------------------------------
// Light Probe Proxy Volume

#ifndef UNITY_LIGHT_PROBE_PROXY_VOLUME
// Requires quite modern graphics support (3D float textures with filtering), so explicitly disabled on SM2.0, DX9, etc.
#define UNITY_LIGHT_PROBE_PROXY_VOLUME UNITY_SM40_PLUS_PLATFORM
#endif

#if UNITY_LIGHT_PROBE_PROXY_VOLUME
	UNITY_DECLARE_TEX3D(unity_ProbeVolumeSH);

	CBUFFER_START(UnityProbeVolume)
		// x = Disabled(0)/Enabled(1)
		// y = Computation are done in global space(0) or local space(1)
		// z = Texel size on U texture coordinate
		float4 unity_ProbeVolumeParams;

		float4x4 unity_ProbeVolumeWorldToObject;
		float3 unity_ProbeVolumeSizeInv;
		float3 unity_ProbeVolumeMin;		
	CBUFFER_END
#endif


// ----------------------------------------------------------------------------
//  Deprecated

// There used to be fixed function-like texture matrices, defined as UNITY_MATRIX_TEXTUREn. These are gone now; and are just defined to identity.
#define UNITY_MATRIX_TEXTURE0 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)
#define UNITY_MATRIX_TEXTURE1 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)
#define UNITY_MATRIX_TEXTURE2 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)
#define UNITY_MATRIX_TEXTURE3 float4x4(1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1)


#endif
