// Used on D3D11 and similar platforms for non-fullscreen clears
// (platforms that can't clear just part of the render target)
Shader "Hidden/InternalClear" {

	CGINCLUDE
	#pragma vertex vert
	#pragma fragment frag
	#pragma target 2.0
	#pragma multi_compile _ STEREO_INSTANCING_ON  UNITY_SINGLE_PASS_STEREO
	#include "UnityCG.cginc"

	struct appdata_t {
		float4 vertex : POSITION;
		fixed4 color : COLOR;
		UNITY_VERTEX_INPUT_INSTANCE_ID
	};

	struct v2f {
		float4 vertex : SV_POSITION;
		fixed4 color : COLOR;
		UNITY_VERTEX_OUTPUT_STEREO
	};

	v2f vert (appdata_t v)
	{
		UNITY_SETUP_INSTANCE_ID(v);
		v2f o;
		UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
		o.vertex = UnityObjectToClipPos(v.vertex);
		o.color = v.color;
		return o;
	}

	fixed4 frag (v2f i) : SV_Target
	{
		return i.color;
	}
	ENDCG 

	SubShader { 
		ZTest Always Cull Off
		Pass {
			ColorMask 0 ZWrite Off
			CGPROGRAM
			ENDCG
		}
		Pass {
			ZWrite Off
			CGPROGRAM
			ENDCG
		}
		Pass {
			ColorMask 0
			CGPROGRAM
			ENDCG
		}
		Pass {
			CGPROGRAM
			ENDCG
		}
		Pass {
			ColorMask 0 ZWrite Off
			Stencil { Comp Always Pass Zero }
			CGPROGRAM
			ENDCG
		}
		Pass {
			ZWrite Off
			Stencil { Comp Always Pass Zero }
			CGPROGRAM
			ENDCG
		}
		Pass {
			ColorMask 0
			Stencil { Comp Always Pass Zero }
			CGPROGRAM
			ENDCG
		}
		Pass {
			Stencil { Comp Always Pass Zero }
			CGPROGRAM
			ENDCG
		}
	}
	Fallback Off 
}
