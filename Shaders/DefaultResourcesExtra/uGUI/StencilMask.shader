Shader "uGUI/Stencil Mask"
{
	Properties
	{
		_MainTex ("Diffuse (RGB), Alpha (A)", 2D) = "white" {}
		_Cutoff ("Cutoff", Range(0.01, 1.0)) = 0.2

		_StencilOp ("Stencil Operation", Float) = 2
	}

	SubShader 
	{
		Tags { "RenderType"="Opaque" "Queue"="Transparent"}
		ColorMask 0
		ZWrite off

		Stencil 
		{
			Comp always
			Pass [_StencilOp]
		}
		
		Pass
		{
		CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			float _Cutoff;

			struct appdata 
			{
				float4 vertex : POSITION;
				half4 texcoord : TEXCOORD0;
			};
			
			struct v2f 
			{
				float4 pos : SV_POSITION;
				half2 texcoord : TEXCOORD0;
			};
			
			v2f vert(appdata v) 
			{
				v2f o;
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
				return o;
			}
			
			half4 frag(v2f i) : COLOR 
			{
				half4 col = tex2D(_MainTex, i.texcoord);
				clip(col.a - _Cutoff);
				return half4(1,1,1,1);
			}
		ENDCG
		}
	}
}
