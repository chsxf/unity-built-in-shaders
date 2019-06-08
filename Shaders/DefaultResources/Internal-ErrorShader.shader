Shader "Hidden/InternalErrorShader"
{
	SubShader
	{
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma target 2.0
			#pragma multi_compile _ UNITY_SINGLE_PASS_STEREO
			#include "UnityCG.cginc"
			float4 vert (float4 pos : POSITION) : SV_POSITION { return UnityObjectToClipPos(pos); }
			fixed4 frag () : SV_Target { return fixed4(1,0,1,1); }
			ENDCG
		}
	}
	Fallback Off
}
