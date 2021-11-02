// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/VideoDecode"
{
    Properties
    {
        _MainTex ("_MainTex (A)", 2D) = "black"
        _SecondTex ("_SecondTex (A)", 2D) = "black"
        _ThirdTex ("_ThirdTex (A)", 2D) = "black"
    }

    CGINCLUDE

        #include "UnityCG.cginc"

        sampler2D _MainTex;
        sampler2D _SecondTex;
        sampler2D _ThirdTex;
        float4 _MainTex_TexelSize;
        float4 _MainTex_ST;

        float4x4 _MatrixColorConversion;

        inline fixed4 AdjustForColorSpace(fixed4 color)
        {
#if defined(UNITY_COLORSPACE_GAMMA) || !defined(ADJUST_TO_LINEARSPACE)
            return color;
#else
            return fixed4(GammaToLinearSpace(color.rgb), color.a);
#endif
        }

        struct appdata_t {
            float4 vertex : POSITION;
            float2 texcoord : TEXCOORD0;
        };

        struct v2f {
            float4 vertex : SV_POSITION;
            float2 texcoord : TEXCOORD0;
        };

        v2f vertexDirect(appdata_t v)
        {
            v2f o;
            o.vertex = UnityObjectToClipPos(v.vertex);
            o.texcoord = TRANSFORM_TEX(v.texcoord.xy, _MainTex);
            return o;
        }

        v2f vertexFlip(appdata_t v)
        {
            v2f o;
            o.vertex = UnityObjectToClipPos(v.vertex);
            o.texcoord.x = v.texcoord.x;
            o.texcoord.y = 1.0f - v.texcoord.y;
            o.texcoord = TRANSFORM_TEX(o.texcoord.xy, _MainTex);
            return o;
        }

        fixed4 fragmentRGBOne(v2f i) : SV_Target
        {
            fixed4 y = tex2D(_MainTex, i.texcoord).a;
            fixed u = tex2D(_SecondTex, i.texcoord).a;
            fixed v = tex2D(_ThirdTex, i.texcoord).a;
            fixed y1 = 1.15625 * y.a;
            y.r = y1 + 1.59375 * v - 0.87254;
            y.g = y1 - 0.390625 * u - 0.8125 * v + 0.53137;
            y.b = y1 + 1.984375 * u - 1.06862;

            return AdjustForColorSpace(fixed4(y.rgb, 1.0));
        }

        fixed4 fragmentNV12RGBOne(v2f i) : SV_Target
        {
            float3 yCbCr = float3( tex2D(_MainTex, i.texcoord).a - 0.0625,
                                   tex2D(_SecondTex, i.texcoord).r - 0.5,
                                   tex2D(_SecondTex, i.texcoord).g - 0.5 );
            fixed4 result = fixed4( dot(float3(_MatrixColorConversion[0][0], _MatrixColorConversion[0][1], _MatrixColorConversion[0][2]), yCbCr),
                                    dot(float3(_MatrixColorConversion[1][0], _MatrixColorConversion[1][1], _MatrixColorConversion[1][2]), yCbCr),
                                    dot(float3(_MatrixColorConversion[2][0], _MatrixColorConversion[2][1], _MatrixColorConversion[2][2]), yCbCr),
                                    1.0f );
            return AdjustForColorSpace(result);
        }

        fixed4 fragmentNV12RGBA(v2f i) : SV_Target
        {
            float ty  = 0.5f * i.texcoord.x;    // Y  : left half of luma plane
            float ta  = ty + 0.5f;              // A  : right half of luma plane
            float tuv = ty;                     // UV : just use left half of chroma plane

            fixed  y  = tex2D(_MainTex,   float2(ty,  i.texcoord.y)).a;
            fixed  a  = tex2D(_MainTex,   float2(ta,  i.texcoord.y)).a;
            fixed2 uv = tex2D(_SecondTex, float2(tuv, i.texcoord.y)).rg;
            fixed  u  = uv.r;
            fixed  v  = uv.g;

            fixed y1 = 1.15625 * y;
            fixed4 result = fixed4(y1 + 1.59375 * v - 0.87254,
                                   y1 - 0.390625 * u - 0.8125 * v + 0.53137,
                                   y1 + 1.984375 * u - 1.06862,
                                   1.15625 * (a - 0.062745));

            return AdjustForColorSpace(result);
        }

        fixed4 fragmentP010RGBOne(v2f i) : SV_Target
        {
            float3 yCbCr = float3( tex2D(_MainTex, i.texcoord).r ,
                                   tex2D(_SecondTex, i.texcoord).r,
                                   tex2D(_SecondTex, i.texcoord).g);
            yCbCr *= 65535.0 / 1023.0;     // Source data is 10 bit in a 16 bit texture so we need to scale the values so that the result covers the full range from 0 to 1
            yCbCr -= float3(0.0625, 0.5, 0.5);

            fixed4 result = fixed4( dot(float3(1.1644f, 0.0f, 1.7927f), yCbCr),
                                    dot(float3(1.1644f, -0.2133f, -0.5329f), yCbCr),
                                    dot(float3(1.1644f, 2.1124f, 0.0f), yCbCr),
                                    1.0f);

            return AdjustForColorSpace(result);
        }

        fixed4 fragmentRGB_FullAlpha(v2f i) : SV_Target
        {
            float2 tc = float2(0.5f * i.texcoord.x, i.texcoord.y);
            fixed4 y = tex2D(_MainTex, tc).a;
            fixed u = tex2D(_SecondTex, tc).a;
            fixed v = tex2D(_ThirdTex, tc).a;
            fixed a = tex2D(_MainTex, float2(tc.x + 0.5f, tc.y)).a;
            fixed y1 = 1.15625 * y.a;
            y.r = y1 + 1.59375 * v - 0.87254;
            y.g = y1 - 0.390625 * u - 0.8125 * v + 0.53137;
            y.b = y1 + 1.984375 * u - 1.06862;
            return AdjustForColorSpace(fixed4(y.rgb, a));
        }

        fixed4 fragmentRGBA(v2f i) : SV_Target
        {
            float2 tc = float2(0.5f * i.texcoord.x, i.texcoord.y);
            fixed4 y = tex2D(_MainTex, tc).a;
            fixed u = tex2D(_SecondTex, tc).a;
            fixed v = tex2D(_ThirdTex, tc).a;
            fixed a = tex2D(_MainTex, float2(tc.x + 0.5f, tc.y)).a;
            fixed y1 = 1.15625 * y.a;
            y.r = y1 + 1.59375 * v - 0.87254;
            y.g = y1 - 0.390625 * u - 0.8125 * v + 0.53137;
            y.b = y1 + 1.984375 * u - 1.06862;
            return AdjustForColorSpace(fixed4(y.rgb, 1.15625*(a - 0.062745)));
        }

        fixed4 fragmentRGBASplit(v2f i) : SV_Target
        {
            float2 tc = float2(0.5f * i.texcoord.x, i.texcoord.y);
            fixed4 col = tex2D(_MainTex, tc);
            fixed a = tex2D(_MainTex, float2(tc.x + 0.5f, tc.y)).g;
            return AdjustForColorSpace(fixed4(col.rgb, a));
        }

        fixed4 fragmentRGBANormal(v2f i) : SV_Target
        {
            fixed4 col = tex2D(_MainTex, i.texcoord);
            return AdjustForColorSpace(col.rgba);
        }

    ENDCG

    SubShader
    {
        Pass
        {
            Name "YCbCr_To_RGB1"
            ZTest Always Cull Off ZWrite Off Blend Off
            CGPROGRAM
            #pragma vertex vertexDirect
            #pragma fragment fragmentRGBOne
            #pragma multi_compile_local _ ADJUST_TO_LINEARSPACE
            ENDCG
        }

        Pass
        {
            Name "YCbCrA_To_RGBAFull"
            ZTest Always Cull Off ZWrite Off Blend Off
            CGPROGRAM
            #pragma vertex vertexDirect
            #pragma fragment fragmentRGB_FullAlpha
            #pragma multi_compile_local _ ADJUST_TO_LINEARSPACE
            ENDCG
        }

        Pass
        {
            Name "YCbCrA_To_RGBA"
            ZTest Always Cull Off ZWrite Off Blend Off
            CGPROGRAM
            #pragma vertex vertexDirect
            #pragma fragment fragmentRGBA
            #pragma multi_compile_local _ ADJUST_TO_LINEARSPACE
            ENDCG
        }

        Pass
        {
            Name "Flip_RGBA_To_RGBA"
            ZTest Always Cull Off ZWrite Off Blend Off
            CGPROGRAM
            #pragma vertex vertexFlip
            #pragma fragment fragmentRGBANormal
            #pragma multi_compile_local _ ADJUST_TO_LINEARSPACE
            ENDCG
        }

        Pass
        {
            Name "Flip_RGBASplit_To_RGBA"
            ZTest Always Cull Off ZWrite Off Blend Off
            CGPROGRAM
            #pragma vertex vertexFlip
            #pragma fragment fragmentRGBASplit
            #pragma multi_compile_local _ ADJUST_TO_LINEARSPACE
            ENDCG
        }

        // NV12 format: Y plane (_MainTex / 8-bit) followed by interleaved U/V plane (_SecondTex / 8-bit each component) with 2x2 subsampling (so half width/height)
        Pass
        {
            Name "Flip_NV12_To_RGB1"
            ZTest Always Cull Off ZWrite Off Blend Off
            CGPROGRAM
            #pragma vertex vertexFlip
            #pragma fragment fragmentNV12RGBOne
            #pragma multi_compile_local _ ADJUST_TO_LINEARSPACE
            ENDCG
        }

        // NV12 format, split alpha: YA plane (_MainTex / 8-bit) followed by interleaved U/V plane (_SecondTex / 8-bit each component) with 2x2 subsampling (so half width/height)
        Pass
        {
            Name "Flip_NV12_To_RGBA"
            ZTest Always Cull Off ZWrite Off Blend Off
            CGPROGRAM
            #pragma vertex vertexFlip
            #pragma fragment fragmentNV12RGBA
            #pragma multi_compile_local _ ADJUST_TO_LINEARSPACE
            ENDCG
        }

        // P010 format: Y plane (_MainTex / 10-bit) followed by interleaved U/V plane (_SecondTex / 10-bit each component) with 2x2 subsampling (so half width/height), the shader scales the 10 bit source data to 16 bit output.
        Pass
        {
            Name "Flip_P010_To_RGB1"
            ZTest Always Cull Off ZWrite Off Blend Off
            CGPROGRAM
            #pragma vertex vertexFlip
            #pragma fragment fragmentP010RGBOne
            ENDCG
        }
    }

    FallBack Off
}
