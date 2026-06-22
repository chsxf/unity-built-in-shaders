// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "UI/Unlit/Detail"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        _Color ("Main Color", Color) = (1,1,1,1)

        _DetailTex ("Detail (RGB)", 2D) = "white" {}
        _Strength ("Detail Strength", Range(0.0, 1.0)) = 0.2

        _StencilComp ("Stencil Comparison", Float) = 8
        _Stencil ("Stencil ID", Float) = 0
        _StencilOp ("Stencil Operation", Float) = 0
        _StencilWriteMask ("Stencil Write Mask", Float) = 255
        _StencilReadMask ("Stencil Read Mask", Float) = 255

        _ColorMask ("Color Mask", Float) = 15

        [Toggle(UNITY_UI_ALPHACLIP)] _UseUIAlphaClip ("Use Alpha Clip", Float) = 0
        
        [Toggle] _XRMotionVectorsPass("_XRMotionVectorsPass", Float) = 0.0
    }

    SubShader
    {
        LOD 100

        Tags
        {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
            "PreviewType"="Plane"
        }

        Stencil
        {
            Ref [_Stencil]
            Comp [_StencilComp]
            Pass [_StencilOp]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }

        Cull Off
        Lighting Off
        ZWrite Off
        ZTest [unity_GUIZTestMode]
        Blend SrcAlpha OneMinusSrcAlpha
        ColorMask [_ColorMask]

        Pass
        {
            Name "Default"
        CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityUI.cginc"

            #pragma multi_compile_local _ UNITY_UI_CLIP_RECT
            #pragma multi_compile_local _ UNITY_UI_ALPHACLIP

            struct appdata_t
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float2 texcoord2 : TEXCOORD1;
                fixed4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float2 texcoord : TEXCOORD0;
                float2 texcoord2 : TEXCOORD1;
                float4 worldPosition : TEXCOORD2;
                fixed4 color : COLOR;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            sampler2D _DetailTex;
            float4 _MainTex_ST;
            float4 _DetailTex_ST;
            float4 _DetailTex_TexelSize;
            fixed4 _Color;
            fixed _Strength;

            fixed4 _TextureSampleAdd;

            bool _UseClipRect;
            float4 _ClipRect;

            bool _UseAlphaClip;

            int _UIVertexColorAlwaysGammaSpace;

            v2f vert (appdata_t v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.worldPosition = v.vertex;
                o.vertex = UnityObjectToClipPos(o.worldPosition);

                o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.texcoord2 = TRANSFORM_TEX(v.texcoord2 * _DetailTex_TexelSize.xy, _DetailTex);

                if (_UIVertexColorAlwaysGammaSpace)
                {
                    if(!IsGammaSpace())
                    {
                        v.color.rgb = UIGammaToLinear(v.color.rgb);
                    }
                }

                o.color = v.color * _Color;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 color = (tex2D(_MainTex, i.texcoord) + _TextureSampleAdd) * i.color;
                fixed4 detail = tex2D(_DetailTex, i.texcoord2);
                color.rgb = lerp(color.rgb, color.rgb * detail.rgb, detail.a * _Strength);
                color = color * _Color;

                #ifdef UNITY_UI_CLIP_RECT
                color.a *= UnityGet2DClipping(i.worldPosition.xy, _ClipRect);
                #endif

                #ifdef UNITY_UI_ALPHACLIP
                clip (color.a - 0.001);
                #endif

                return color;
            }
            ENDCG

        }
        
        Pass
        {
            Name "XRMotionVectors"
            Tags { "LightMode" = "XRMotionVectors" }
            // Stencil write for obj motion pixels
            Stencil
            {
                WriteMask 1
                Ref 1
                Comp Always
                Pass Replace
            }
            ZWrite On
            Blend SrcAlpha OneMinusSrcAlpha
        CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityUI.cginc"
            
            float4x4 unity_MatrixPreviousM;
            #define UNITY_MATRIX_M     unity_ObjectToWorld
            #define UNITY_PREV_MATRIX_M   unity_MatrixPreviousM
            float4x4 _PrevViewProjMatrixStereo[2];
            float4x4 _NonJitteredViewProjMatrixStereo[2];
            #define  _PrevViewProjMatrix  _PrevViewProjMatrixStereo[unity_StereoEyeIndex]
            #define  _NonJitteredViewProjMatrix _NonJitteredViewProjMatrixStereo[unity_StereoEyeIndex]
            float _SpaceWarpNDCModifier;

            #pragma multi_compile_local _ UNITY_UI_CLIP_RECT
            #pragma multi_compile_local _ UNITY_UI_ALPHACLIP

            struct appdata_t
            {
                float4 vertex : POSITION;
                float2 texcoord : TEXCOORD0;
                float2 texcoord2 : TEXCOORD1;
                fixed4 color : COLOR;
                float4 oldvertex: TEXCOORD4;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 positionCSNoJitter         : POSITION_CS_NO_JITTER;
                float4 previousPositionCSNoJitter : PREV_POSITION_CS_NO_JITTER;
                float2 texcoord : TEXCOORD0;
                float2 texcoord2 : TEXCOORD1;
                float4 worldPosition : TEXCOORD2;
                fixed4 color : COLOR;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            sampler2D _MainTex;
            sampler2D _DetailTex;
            float4 _MainTex_ST;
            float4 _DetailTex_ST;
            float4 _DetailTex_TexelSize;
            fixed4 _Color;
            fixed _Strength;

            fixed4 _TextureSampleAdd;

            bool _UseClipRect;
            float4 _ClipRect;

            bool _UseAlphaClip;

            int _UIVertexColorAlwaysGammaSpace;
            
            float _XRMotionVectorsPass;

            v2f vert (appdata_t v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                
                // We do not need jittered position in ASW
                o.worldPosition = v.vertex;
                o.vertex = mul(_NonJitteredViewProjMatrix, mul(UNITY_MATRIX_M, o.worldPosition));
                o.positionCSNoJitter = o.vertex;
                o.previousPositionCSNoJitter = mul(_PrevViewProjMatrix, mul(UNITY_PREV_MATRIX_M, v.oldvertex));

                o.texcoord = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.texcoord2 = TRANSFORM_TEX(v.texcoord2 * _DetailTex_TexelSize.xy, _DetailTex);

                if (_UIVertexColorAlwaysGammaSpace)
                {
                    if(!IsGammaSpace())
                    {
                        v.color.rgb = UIGammaToLinear(v.color.rgb);
                    }
                }

                o.color = v.color * _Color;

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 color = (tex2D(_MainTex, i.texcoord) + _TextureSampleAdd) * i.color;
                fixed4 detail = tex2D(_DetailTex, i.texcoord2);
                color.rgb = lerp(color.rgb, color.rgb * detail.rgb, detail.a * _Strength);
                color = color * _Color;

                #ifdef UNITY_UI_CLIP_RECT
                color.a *= UnityGet2DClipping(i.worldPosition.xy, _ClipRect);
                #endif

                clip (color.a * _XRMotionVectorsPass - 0.001);

                float3 posNDC = i.positionCSNoJitter.xyz * rcp(i.positionCSNoJitter.w);
                float3 prevPosNDC = i.previousPositionCSNoJitter.xyz * rcp(i.previousPositionCSNoJitter.w);

                float3 velocity;
                // Calculate forward velocity
                velocity = (posNDC.xyz - prevPosNDC.xyz);

                #if UNITY_UV_STARTS_AT_TOP
                velocity.y = velocity.y * _SpaceWarpNDCModifier;
                #endif

                return float4(velocity.xyz, 1.0);
            }
            ENDCG
        }
    }
}
