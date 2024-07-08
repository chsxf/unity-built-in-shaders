// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/BlitCopyHDRTonemap" {
    Properties
    {
        _MainTex ("Texture", any) = "" {}
        _NitsForPaperWhite("NitsForPaperWhite", Float) = 160.0
        _ColorGamut("ColorGamut", Int) = 0
        _ForceGammaToLinear("ForceGammaToLinear", Float) = 0.0
        _MaxDisplayNits("MaxDisplayNits", Float) = 160.0
    }
    SubShader {
        Pass {
            ZTest Always Cull Off ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "UnityColorGamut.cginc"

            UNITY_DECLARE_SCREENSPACE_TEXTURE(_MainTex);
            uniform float4 _MainTex_ST;
            uniform float  _NitsForPaperWhite;
            uniform int    _ColorGamut;
            uniform bool   _ForceGammaToLinear;
            uniform float  _MaxDisplayNits;

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
                // The scene is rendered with linear gamma and Rec.709 primaries. (DXGI_COLOR_SPACE_RGB_FULL_G10_NONE_P709)
                float4 scene = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_MainTex, i.texcoord);

                float3 result = SimpleHDRDisplayToneMapAndOETF(scene.rgb, _ColorGamut, _ForceGammaToLinear, _NitsForPaperWhite, _MaxDisplayNits);
                return float4(result.rgb, scene.a);
            }
            ENDCG

        }
    }
    Fallback Off
}
