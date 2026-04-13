// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/GUITextureBlit2SRGB" {
    Properties
    {
        _MainTex ("Texture", any) = "" {}
        _Color("Multiplicative color", Color) = (1.0, 1.0, 1.0, 1.0)
    }
    SubShader {
        Pass {
            ZTest Always Cull Off ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0

            #pragma multi_compile __ CLIP_UV

            #include "UnityCG.cginc"

            UNITY_DECLARE_SCREENSPACE_TEXTURE(_MainTex);
            uniform float4 _MainTex_ST;
            uniform float4 _Color;
            uniform bool _ManualTex2SRGB;

            #ifdef CLIP_UV
            float4x4 unity_GUIClipTextureMatrix;
            sampler2D _GUIClipTexture;
            #endif

            struct appdata_t {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f {
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD0;
                
                #ifdef CLIP_UV
                float2 clipUV : TEXCOORD1;
                #endif
                
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            v2f vert (appdata_t v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_OUTPUT(v2f, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.texcoord = TRANSFORM_TEX(v.texcoord.xy, _MainTex);
                
                #ifdef CLIP_UV
                float3 eyePos = UnityObjectToViewPos(v.vertex);
                o.clipUV = mul(unity_GUIClipTextureMatrix, float4(eyePos.xy, 0, 1.0));
                #endif
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                #ifdef CLIP_UV
                if (tex2D(_GUIClipTexture, i.clipUV).a < 1.0)
                    discard;
                #endif
                
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                fixed4 colTex = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_MainTex, i.texcoord);
                if (_ManualTex2SRGB)
                    colTex.rgb = LinearToGammaSpace(colTex.rgb);
                return colTex * _Color;
            }
            ENDCG

        }
    }
    Fallback Off
}
