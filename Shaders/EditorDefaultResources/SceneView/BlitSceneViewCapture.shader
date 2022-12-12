// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/BlitSceneViewCapture"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "" {}
    }
    SubShader
    {
        Tags { "ForceSupported" = "True" }
        Pass
        {
            ZTest Always Cull Off ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            UNITY_DECLARE_SCREENSPACE_TEXTURE(_MainTex);
            uniform float4 _MainTex_ST;

            struct appdata_t
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD0;
            };

            v2f vert (appdata_t v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.texcoord = TRANSFORM_TEX(v.texcoord.xy, _MainTex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                #if UNITY_UV_STARTS_AT_TOP
                i.texcoord.y = 1.0 - i.texcoord.y;
                #endif
                return UNITY_SAMPLE_SCREENSPACE_TEXTURE(_MainTex, i.texcoord);
            }
            ENDCG
        }
    }
    Fallback Off
}
