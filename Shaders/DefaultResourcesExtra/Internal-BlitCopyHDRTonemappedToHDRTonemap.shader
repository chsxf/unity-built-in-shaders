// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/BlitCopyHDRTonemappedToHDRTonemap" {
    Properties
    {
        _MainTex ("Texture", any) = "" {}
        _SourceNitsForPaperWhite("SourceNitsForPaperWhite", Float) = 160.0
        _SourceColorGamut("SourceColorGamut", Int) = 0
        _SourceForceGammaToLinear("SourceForceGammaToLinear", Float) = 0.0
        _SourceMaxDisplayNits("SourceMaxDisplayNits", Float) = 160.0
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
            uniform float  _SourceNitsForPaperWhite;
            uniform int    _SourceColorGamut;
            uniform bool   _SourceForceGammaToLinear;
            uniform float  _SourceMaxDisplayNits;
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

            // Convert from one HDR encoded color gamut to another one, usually for copying backbuffers between different displays.
            float4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
                float4 scene = UNITY_SAMPLE_SCREENSPACE_TEXTURE(_MainTex, i.texcoord);

                float3 result = InverseSimpleHDRDisplayToneMapAndOETF(scene.rgb, _SourceColorGamut, _SourceForceGammaToLinear, _SourceNitsForPaperWhite, _SourceMaxDisplayNits);
                // We do Inverse OETF -> ColorGamutTo709Linear -> 709LinearToColorGamut -> OETF, we could generate the combined color transform matrix on the CPU to save some GPU cost.
                result = SimpleHDRDisplayToneMapAndOETF(result.rgb, _ColorGamut, _ForceGammaToLinear, _NitsForPaperWhite, _MaxDisplayNits);
                return float4(result.rgb, scene.a);
            }
            ENDCG

        }
    }
    Fallback Off
}
