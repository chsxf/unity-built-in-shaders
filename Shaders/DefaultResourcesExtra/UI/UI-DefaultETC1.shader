// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "UI/DefaultETC1"
{
    Properties
    {
        [PerRendererData] _MainTex ("Sprite Texture", 2D) = "white" {}
        [PerRendererData] _AlphaTex("Sprite Alpha Texture", 2D) = "white" {}
        _Color ("Tint", Color) = (1,1,1,1)

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
        Tags
        {
            "Queue"="Transparent"
            "IgnoreProjector"="True"
            "RenderType"="Transparent"
            "PreviewType"="Plane"
            "CanUseSpriteAtlas"="True"
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
        Blend One OneMinusSrcAlpha
        ColorMask [_ColorMask]

        Pass
        {
            Name "Default"
        CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0

            #include "UnityCG.cginc"
            #include "UnityUI.cginc"

            #pragma multi_compile_local _ UNITY_UI_CLIP_RECT
            #pragma multi_compile_local _ UNITY_UI_ALPHACLIP

            struct appdata_t
            {
                float4 vertex   : POSITION;
                float4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float4 vertex   : SV_POSITION;
                fixed4 color    : COLOR;
                float2 texcoord  : TEXCOORD0;
                float4 worldPosition : TEXCOORD1;
                float4  mask : TEXCOORD2;
            };

            sampler2D _MainTex;
            fixed4 _Color;
            fixed4 _TextureSampleAdd;
            float4 _ClipRect;
            float4 _MainTex_ST;
            float _UIMaskSoftnessX;
            float _UIMaskSoftnessY;
            int _UIVertexColorAlwaysGammaSpace;

            v2f vert(appdata_t IN)
            {
                v2f OUT;
                float4 vPosition = UnityObjectToClipPos(IN.vertex);
                OUT.worldPosition = IN.vertex;
                OUT.vertex = vPosition;

                #ifdef UNITY_HALF_TEXEL_OFFSET
                OUT.vertex.xy += (_ScreenParams.zw-1.0) * float2(-1,1) * OUT.vertex.w;
                #endif

                float2 pixelSize = vPosition.w;
                pixelSize /= float2(1, 1) * abs(mul((float2x2)UNITY_MATRIX_P, _ScreenParams.xy));

                float4 clampedRect = clamp(_ClipRect, -2e10, 2e10);
                float2 maskUV = (IN.vertex.xy - clampedRect.xy) / (clampedRect.zw - clampedRect.xy);
                OUT.texcoord = TRANSFORM_TEX(IN.texcoord.xy, _MainTex);
                OUT.mask = float4(IN.vertex.xy * 2 - clampedRect.xy - clampedRect.zw, 0.25 / (0.25 * half2(_UIMaskSoftnessX, _UIMaskSoftnessY) + abs(pixelSize.xy)));

                if (_UIVertexColorAlwaysGammaSpace)
                {
                    if(!IsGammaSpace())
                    {
                        IN.color.rgb = UIGammaToLinear(IN.color.rgb);
                    }
                }

                OUT.color = IN.color * _Color;

                return OUT;
            }

            sampler2D _AlphaTex;

            fixed4 frag(v2f IN) : SV_Target
            {
                //Round up the alpha color coming from the interpolator (to 1.0/256.0 steps)
                //The incoming alpha could have numerical instability, which makes it very sensible to
                //HDR color transparency blend, when it blends with the world's texture.
                const half alphaPrecision = half(0xff);
                const half invAlphaPrecision = half(1.0/alphaPrecision);
                IN.color.a = round(IN.color.a * alphaPrecision)*invAlphaPrecision;

                fixed4 color = IN.color * UnityGetUIDiffuseColor(IN.texcoord, _MainTex, _AlphaTex, _TextureSampleAdd);

                #ifdef UNITY_UI_CLIP_RECT
                    half2 m = saturate((_ClipRect.zw - _ClipRect.xy - abs(IN.mask.xy)) * IN.mask.zw);
                    color.a *= m.x * m.y;
                #endif

                #ifdef UNITY_UI_ALPHACLIP
                clip (color.a - 0.001);
                #endif

                color.rgb *= color.a;
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
            #pragma target 2.0

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
                float4 vertex   : POSITION;
                float4 color    : COLOR;
                float2 texcoord : TEXCOORD0;
                float4 oldvertex: TEXCOORD4;
            };

            struct v2f
            {
                float4 vertex   : SV_POSITION;
                fixed4 color    : COLOR;
                float2 texcoord  : TEXCOORD0;
                float4 worldPosition : TEXCOORD1;
                float4  mask : TEXCOORD2;
                float4 positionCSNoJitter         : POSITION_CS_NO_JITTER;
                float4 previousPositionCSNoJitter : PREV_POSITION_CS_NO_JITTER;
            };

            sampler2D _MainTex;
            fixed4 _Color;
            fixed4 _TextureSampleAdd;
            float4 _ClipRect;
            float4 _MainTex_ST;
            float _UIMaskSoftnessX;
            float _UIMaskSoftnessY;
            int _UIVertexColorAlwaysGammaSpace;
            
            float _XRMotionVectorsPass;
            float xrMotionVectorsTransparentThreshold = 0.001;

            v2f vert(appdata_t IN)
            {
                v2f OUT;
                
                // We do not need jittered position in ASW
                float4 vPosition = mul(_NonJitteredViewProjMatrix, mul(UNITY_MATRIX_M, IN.vertex));
                OUT.positionCSNoJitter = vPosition;
                OUT.previousPositionCSNoJitter = mul(_PrevViewProjMatrix, mul(UNITY_PREV_MATRIX_M, IN.oldvertex));
                OUT.worldPosition = IN.vertex;
                OUT.vertex = vPosition;

                #ifdef UNITY_HALF_TEXEL_OFFSET
                OUT.vertex.xy += (_ScreenParams.zw-1.0) * float2(-1,1) * OUT.vertex.w;
                #endif

                float2 pixelSize = vPosition.w;
                pixelSize /= float2(1, 1) * abs(mul((float2x2)UNITY_MATRIX_P, _ScreenParams.xy));

                float4 clampedRect = clamp(_ClipRect, -2e10, 2e10);
                float2 maskUV = (IN.vertex.xy - clampedRect.xy) / (clampedRect.zw - clampedRect.xy);
                OUT.texcoord = TRANSFORM_TEX(IN.texcoord.xy, _MainTex);
                OUT.mask = float4(IN.vertex.xy * 2 - clampedRect.xy - clampedRect.zw, 0.25 / (0.25 * half2(_UIMaskSoftnessX, _UIMaskSoftnessY) + abs(pixelSize.xy)));

                if (_UIVertexColorAlwaysGammaSpace)
                {
                    if(!IsGammaSpace())
                    {
                        IN.color.rgb = UIGammaToLinear(IN.color.rgb);
                    }
                }

                OUT.color = IN.color * _Color;

                return OUT;
            }

            sampler2D _AlphaTex;

            fixed4 frag(v2f IN) : SV_Target
            {
                //Round up the alpha color coming from the interpolator (to 1.0/256.0 steps)
                //The incoming alpha could have numerical instability, which makes it very sensible to
                //HDR color transparency blend, when it blends with the world's texture.
                const half alphaPrecision = half(0xff);
                const half invAlphaPrecision = half(1.0/alphaPrecision);
                IN.color.a = round(IN.color.a * alphaPrecision)*invAlphaPrecision;

                fixed4 color = IN.color * UnityGetUIDiffuseColor(IN.texcoord, _MainTex, _AlphaTex, _TextureSampleAdd);

                #ifdef UNITY_UI_CLIP_RECT
                    half2 m = saturate((_ClipRect.zw - _ClipRect.xy - abs(IN.mask.xy)) * IN.mask.zw);
                    color.a *= m.x * m.y;
                #endif

                clip (color.a * _XRMotionVectorsPass - 0.001);

                float3 posNDC = IN.positionCSNoJitter.xyz * rcp(IN.positionCSNoJitter.w);
                float3 prevPosNDC = IN.previousPositionCSNoJitter.xyz * rcp(IN.previousPositionCSNoJitter.w);

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
