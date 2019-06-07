Shader "Hidden/Shadow-ScreenBlur" {
Properties {
	_MainTex ("Base", 2D) = "white" {}
}
SubShader {
	Pass {
		ZTest Always Cull Off ZWrite Off
		Fog { Mode off }
		
CGPROGRAM
#pragma vertex vert_img
#pragma fragment frag
#pragma exclude_renderers noshadows
#pragma fragmentoption ARB_precision_hint_fastest
#include "UnityCG.cginc"

uniform sampler2D _MainTex;

// x,y of each - sample offset for blur
uniform float4 _BlurOffsets0;
uniform float4 _BlurOffsets1;
uniform float4 _BlurOffsets2;
uniform float4 _BlurOffsets3;
uniform float4 _BlurOffsets4;
uniform float4 _BlurOffsets5;
uniform float4 _BlurOffsets6;
uniform float4 _BlurOffsets7;

float4 unity_ShadowBlurParams;

#define LOOP_ITERATION(i) { 	\
	half4 sample = tex2D( _MainTex, (coord + radius * _BlurOffsets##i).xy ); \
	half sampleDist = sample.b + sample.a / 255.0; \
	half diff = dist - sampleDist; \
	diff = saturate( diffTolerance - abs(diff) ); \
	mask.xy += diff * sample.xy; }

fixed4 frag (v2f_img i) : COLOR
{
	float4 coord = float4(i.uv,0,0);
	half4 mask = tex2D( _MainTex, coord.xy );
	half dist = mask.b + mask.a / 255.0;
	half radius = saturate(unity_ShadowBlurParams.y / (1.0-dist));
	
	half diffTolerance = unity_ShadowBlurParams.x;
	
	mask.xy *= diffTolerance;

	// Would this code look better in a loop? You bet.
	// But, that requires using a uniform array in GLSL,
	// which means that shaderlab would need support for array parameters.
	// So, until we have that, this needs to be unrolled to work in GLSL, 
	// then we can revert to the looped version.
	
	LOOP_ITERATION (0);
	LOOP_ITERATION (1);
	LOOP_ITERATION (2);
	LOOP_ITERATION (3);
	LOOP_ITERATION (4);
	LOOP_ITERATION (5);
	LOOP_ITERATION (6);
	LOOP_ITERATION (7);

	half shadow = mask.x / mask.y;
	return shadow;
}
ENDCG
	}	
}

Fallback Off
}
