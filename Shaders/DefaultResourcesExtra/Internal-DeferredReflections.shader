Shader "Hidden/Internal-DeferredReflections" {
Properties {
	_SrcBlend ("", Float) = 1
	_DstBlend ("", Float) = 1
}
SubShader {

// Calculates reflection contribution from a single probe (rendered as cubes) or default reflection (rendered as full screen quad)
Pass {
	ZWrite Off
	ZTest LEqual
	Blend [_SrcBlend] [_DstBlend]
CGPROGRAM
#pragma target 3.0
#pragma vertex vert_deferred
#pragma fragment frag

#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityStandardBRDF.cginc"

sampler2D _CameraGBufferTexture0;
sampler2D _CameraGBufferTexture1;
sampler2D _CameraGBufferTexture2;

half3 distanceFromAABB(half3 p, half3 aabbMin, half3 aabbMax)
{
	return max(max(p - aabbMax, aabbMin - p), half3(0.0, 0.0, 0.0));
}

half4 frag (unity_v2f_deferred i) : SV_Target
{
	// Stripped from UnityDeferredCalculateLightParams, refactor into function ?
	i.ray = i.ray * (_ProjectionParams.z / i.ray.z);
	float2 uv = i.uv.xy / i.uv.w;

	half4 gbuffer1 = tex2D (_CameraGBufferTexture1, uv);
	half4 gbuffer2 = tex2D (_CameraGBufferTexture2, uv);

	// read depth and reconstruct world position
	float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
	
	depth = Linear01Depth (depth);
	float4 vertextPosition = float4(i.ray * depth,1);
	
	half3 normalWorld = gbuffer2.rgb * 2 - 1;
	normalWorld = normalize(normalWorld);

	half3 specColor = gbuffer1.rgb;
	float3 worldPos = mul (_CameraToWorld, vertextPosition).xyz;
	float3 eyeVec = normalize(worldPos - _WorldSpaceCameraPos);
	half oneMinusReflectivity = 1 - SpecularStrength(specColor.rgb);
	
	half oneMinusRoughness = gbuffer1.a;
	half3 worldNormal = reflect(eyeVec, normalWorld);

	#if UNITY_SPECCUBE_BOX_PROJECTION		
		half3 worldNormal0 = BoxProjectedCubemapDirection (worldNormal, worldPos, unity_SpecCube0_ProbePosition, unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
	#else
		half3 worldNormal0 = worldNormal;
	#endif

	half3 env0 = Unity_GlossyEnvironment (UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, worldNormal0, 1 - oneMinusRoughness);

	half nv = DotClamped (normalWorld, eyeVec);
	half occlusion = 1.0; // TODO: Occlusion(i.tex.xy); Need to have OcclusionMap + OcclusionStrength, but they come from Standard shader, which isn't available in this shader
						  //       Rej said - "Not sure 100%, but I think Occlusion should be applied when _reading_ from ReflectionBuffer. Otherwise, Occlusion information is stored in GBuffer0.a"
	half grazingTerm = saturate(oneMinusRoughness + (1-oneMinusReflectivity));
	half3 rgb = env0 * occlusion * FresnelLerp (specColor, grazingTerm, nv);

	// Calculate falloff value, so reflections on the edges of the probe would gradually blend to previous reflection.
	// Also this ensures that pixels not located in the reflection probe AABB won't accidentally pick up reflections from this probe
	half3 distance = distanceFromAABB(worldPos, unity_SpecCube0_BoxMin.xyz, unity_SpecCube0_BoxMax.xyz);
	half falloff = saturate(1.0 - length(distance));
	return half4(rgb, falloff);
}

ENDCG
}

// Adds reflection buffer to the lighting buffer
Pass 
{
	ZWrite Off
	ZTest Always
	Blend [_SrcBlend] [_DstBlend]

	CGPROGRAM
		#pragma target 3.0
		#pragma vertex vert_deferred
		#pragma fragment frag_fullscreen
		#pragma multi_compile ___ UNITY_HDR_ON

		#include "UnityCG.cginc"
		#include "UnityDeferredLibrary.cginc"

		sampler2D _CameraReflectionsTexture;

		half4 frag_fullscreen (unity_v2f_deferred i) : SV_Target
		{
			float2 uv = i.uv.xy / i.uv.w;
			half4 c = tex2D (_CameraReflectionsTexture, uv);
			#ifdef UNITY_HDR_ON
			return c;
			#else
			return exp2(-c); 
			#endif
			
		}
	ENDCG
}

}
Fallback Off
}
