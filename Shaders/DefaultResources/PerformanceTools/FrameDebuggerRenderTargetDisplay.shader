// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/FrameDebuggerRenderTargetDisplay"
{
    Properties
    {
        _MainTex("", any) = "black" {}
    }

    CGINCLUDE
    #include "UnityCG.cginc"
    #include "HLSLSupport.cginc"

    bool _UndoOutputSRGB;
    bool _ShouldYFlip;
    half4 _Levels;
    fixed4 _Channels;
    float _MainTexWidth;
    float _MainTexHeight;
    float _MainTexDepth;

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

    float4 ProcessColor(float4 tex)
    {
        float4 col = tex;

        // adjust levels
        col -= _Levels.rrrr;
        col /= _Levels.gggg - _Levels.rrrr;

        // leave only channels we want to show
        col *= _Channels;

        // if we're showing only a single channel, display that as grayscale
        if (dot(_Channels, float4(1, 1, 1, 1)) == 1.0)
        {
            col = dot(col, float4(1, 1, 1, 1));
        }

        // When writing to the render target, it will compress our output into
        // sRGB space. If we just want to show the linear value as-is, we need
        // to cancel the hardware's sRGB conversion, so we convert "from" sRGB
        // which the HW will revert by converting back "to" sRGB.
        if (_UndoOutputSRGB)
        {
            col.rgb = GammaToLinearSpace(saturate(col.rgb));
        }

        return col;
    }
    ENDCG

    SubShader
    {
        Cull Off
        ZWrite Off
        ZTest Always

        // 2D texture
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_local_fragment _ _TEX2DARRAY _CUBEMAP
            #pragma multi_compile_local_fragment _ _MSAA_2 _MSAA_4 _MSAA_8

            #if defined(_MSAA_2)
                #define MSAA_SAMPLES 2
            #elif defined(_MSAA_4)
                #define MSAA_SAMPLES 4
            #elif defined(_MSAA_8)
                #define MSAA_SAMPLES 8
            #else
                #define MSAA_SAMPLES 1
            #endif

            #if _TEX2DARRAY
                #if MSAA_SAMPLES == 1
                    UNITY_DECLARE_TEX2DARRAY(_MainTex);
                #else
                    Texture2DMSArray<float4, MSAA_SAMPLES> _MainTex;
                #endif
            #elif _CUBEMAP
                samplerCUBE_float _MainTex;
            #else
                #if MSAA_SAMPLES == 1
                    Texture2D _MainTex;
                #else
                    Texture2DMS<float4, MSAA_SAMPLES> _MainTex;
                #endif
            #endif

            #if MSAA_SAMPLES > 1
                float4 ResolveMainTex(int3 coord)
                {
                    float4 finalVal = 0;
                    for (int i = 0; i < MSAA_SAMPLES; ++i)
                    {
                        finalVal += _MainTex.Load(coord, i);
                    }
                    return finalVal / float(MSAA_SAMPLES);
                }
            #endif

            float4 SampleTexture(float3 uv)
            {
                #if _TEX2DARRAY
                    #if MSAA_SAMPLES == 1
                        return UNITY_SAMPLE_TEX2DARRAY(_MainTex, uv.xyz);
                    #else
                        int3 coord = int3(uv.xyz * float3(_MainTexWidth, _MainTexHeight, _MainTexDepth));
                        return ResolveMainTex(coord);
                    #endif
                #elif _CUBEMAP
                    return texCUBE(_MainTex, uv.xyz);
                #else
                    int3 coord = int3(uv.xy * float2(_MainTexWidth, _MainTexHeight), 0);

                    #if MSAA_SAMPLES == 1
                        return _MainTex.Load(coord);
                    #else
                        return ResolveMainTex(coord);
                    #endif
                #endif
            }

            float4 frag(v2f i) : SV_Target
            {
                float3 uv = i.uv;
                if (_ShouldYFlip)
                {
                    uv.y = 1.0 - uv.y;
                }

                float4 tex = SampleTexture(uv);
                return ProcessColor(tex);
            }
            ENDCG
        }
    }
    Fallback Off
}
