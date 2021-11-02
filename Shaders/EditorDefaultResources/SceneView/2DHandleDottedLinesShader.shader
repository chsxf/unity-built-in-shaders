// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/2D Handles Dotted Lines" {
    Properties
    {
        _MainTex ("Texture", Any) = "white" {}
        [Enum(UnityEngine.Rendering.CompareFunction)] _HandleZTest ("_HandleZTest", Int) = 8
    }
    SubShader
    {
        Tags { "ForceSupported" = "True" }
        Lighting Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        ZWrite Off
        ZTest [_HandleZTest]
        BindChannels {
            Bind "vertex", vertex
            Bind "color", color
            Bind "TexCoord", texcoord
        }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0

            #include "UnityCG.cginc"

            struct v2f
            {
                float4 vertex   : SV_POSITION;
                fixed4 color    : COLOR0;
                float2 uv       : TEXCOORD0;
                float2 clipUV   : TEXCOORD1;
                float4 screenPosition0 : TEXCOORD2;
                float4 screenPosition1 : TEXCOORD3;
            };

            uniform float4 _MainTex_ST;
            uniform float4x4 unity_GUIClipTextureMatrix;

            v2f vert (float4 vertex1  : POSITION,
                      float2 uv       : TEXCOORD0, // texture coordinate
                      float3 vertex2  : TEXCOORD1, // second vertex to compute angle with
                      float  dashSize : TEXCOORD2, // dash-size
                      float4 color    : COLOR0)
            {
                v2f o;

                float4  out_vertex1 = UnityObjectToClipPos(vertex1);
                float4  out_vertex2 = UnityObjectToClipPos(float4(vertex2, 1));

                float4  screenPosition0 = ComputeScreenPos(out_vertex1);
                float4  screenPosition1 = ComputeScreenPos(out_vertex2);
                screenPosition0.xy = screenPosition0.xy * _ScreenParams.xy * 0.25f;
                screenPosition1.xy = screenPosition1.xy * _ScreenParams.xy * 0.25f;
                screenPosition0.w *= dashSize;
                screenPosition1.w *= dashSize;

                float3 screenUV = UnityObjectToViewPos(vertex1);

                o.vertex  = out_vertex1;
                o.color   = color;
                o.clipUV  = mul(unity_GUIClipTextureMatrix, float4(screenUV.xy, 0, 1.0));
                o.uv      = TRANSFORM_TEX(uv.xy,_MainTex);
                o.screenPosition0 = screenPosition0;
                o.screenPosition1 = screenPosition1;
                return o;
            }

            sampler2D _MainTex;
            sampler2D _GUIClipTexture;

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4  color           = tex2D(_MainTex, i.uv) * i.color;
                color.a *= tex2D(_GUIClipTexture, i.clipUV).a;

                float2  pos0    = (i.screenPosition1.xy) / (i.screenPosition1.w);
                float2  pos1    = (i.screenPosition0.xy) / (i.screenPosition0.w);
                float2  delta   = pos1 - pos0;
                float   value   = length( delta );

                // goes back and forth between dash on / dash off
                // Note: we might want to smooth the subpixel transition between on / off
                float   dist            = frac(step( frac(value), 0.5f) * 0.5f) * 2.0f;
                return  color * dist;
            }
            ENDCG
        }
    }
}
