// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/VR/BlitCopyHDRTonemappedToSDRTexArraySlice" {
    Properties { _MainTex ("Texture", any) = "" {} }
    SubShader {
        Pass {
            ZTest Always Cull Off ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5

            #include "UnityCG.cginc"
            #include "UnityColorGamut.cginc"

            UNITY_DECLARE_TEX2DARRAY(_MainTex);
            uniform float4 _MainTex_ST;
            uniform float  _ArraySliceIndex;
            uniform float  _SourceNitsForPaperWhite;
            uniform int    _SourceColorGamut;
            uniform bool   _SourceForceGammaToLinear;
            uniform float  _SourceMaxDisplayNits;

            struct appdata_t {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f {
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

            // Convert from one HDR encoded color gamut to another one, usually for copying backbuffers between different displays.
            float4 frag (v2f i) : SV_Target
            {
                float4 scene = UNITY_SAMPLE_TEX2DARRAY(_MainTex, float3(i.texcoord.xy, _ArraySliceIndex));

                float3 result = InverseSimpleHDRDisplayToneMapAndOETF(scene.rgb, _SourceColorGamut, _SourceForceGammaToLinear, _SourceNitsForPaperWhite, _SourceMaxDisplayNits);
                return float4(result.rgb, scene.a);
            }
            ENDCG
        }
    }
    Fallback Off
}
