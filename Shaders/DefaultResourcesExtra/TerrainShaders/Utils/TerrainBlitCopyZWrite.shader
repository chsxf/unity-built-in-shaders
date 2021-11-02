// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

// Duplicate of Internal-BlitCopy, with ZTest and ZWrite On to support extended edge sampling in PaintContext
Shader "Hidden/TerrainEngine/TerrainBlitCopyZWrite" {
    Properties
    {
        _MainTex ("Texture", any) = "" {}
        _Color("Multiplicative color", Color) = (1.0, 1.0, 1.0, 1.0)
    }
    SubShader {
        Pass {
            ZTest LEqual Cull Off ZWrite On

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            UNITY_DECLARE_SCREENSPACE_TEXTURE(_MainTex);
            uniform float4 _MainTex_ST;
            uniform float4 _Color;

            struct appdata_t {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert (appdata_t v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.texcoord = TRANSFORM_TEX(v.texcoord.xy, _MainTex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                return UNITY_SAMPLE_SCREENSPACE_TEXTURE(_MainTex, i.texcoord) * _Color;
            }
            ENDCG

        }
    }
    Fallback Off
}
