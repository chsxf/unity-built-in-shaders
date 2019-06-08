Shader "Hidden/Internal-StencilWrite"
{
	SubShader
	{
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#include "UnityCG.cginc"
			float4 vert (float4 pos : POSITION) : SV_POSITION { return UnityObjectToClipPos(pos); }
			fixed4 frag () : SV_Target { return fixed4(0,0,0,0); }
			ENDCG
		}
	}
	Fallback Off
}
