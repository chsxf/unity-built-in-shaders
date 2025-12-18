// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/VisualizeShadingRateImage"
{
    Properties
    {
        _MainTex("", any) = "black" {}
    }

    CGINCLUDE
    #include "UnityCG.cginc"
    #include "HLSLSupport.cginc"

    uniform float _MainTexWidth;
    uniform float _MainTexHeight;

    struct appdata
    {
        float4 vertex : POSITION;
        float3 uv : TEXCOORD0;
    };

    struct v2f
    {
        float4 pos : SV_POSITION;
        float3 uv : TEXCOORD0;
    };

    v2f vert(appdata v)
    {
        v2f o;
        o.pos = UnityObjectToClipPos(v.vertex);
        o.uv = v.uv;
        return o;
    }
    ENDCG

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            Texture2D<uint> _MainTex;
            StructuredBuffer<float4> _VisualizationLut;

            float4 frag(v2f i) : SV_Target
            {
                uint2 pixel = (uint2)(i.uv.xy * float2(_MainTexWidth, _MainTexHeight));
                uint shadingRate = _MainTex.Load(int3(pixel, 0));

                return _VisualizationLut[shadingRate];
            }
            ENDCG
        }
    }
    Fallback Off
}
