// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/Internal-DebugPattern"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
    }

        CGINCLUDE
#pragma vertex vert
#pragma fragment frag
#include "UnityCG.cginc"

    struct appdata
    {
        float4 vertex : POSITION;
        float2 uv : TEXCOORD0;
    };

    struct v2f
    {
        float2 uv : TEXCOORD0;
        float4 position : SV_POSITION;
    };

    sampler2D _MainTex;

    v2f vert(appdata v)
    {
        v2f o;
        o.uv = v.uv;
        o.position = UnityObjectToClipPos(v.vertex);
        return o;
    }
    ENDCG

        SubShader
    {
        ZTest Always
        Pass
        {
            ZWrite On
            Name "Target Color and DepthStencil"
            Stencil
            {
                Ref 255
                Comp Always
                Pass Replace
            }
            CGPROGRAM
            struct fragOut
            {
                fixed4 color : SV_Target0;
                float depth : SV_Depth;
            };

            fragOut frag(v2f i)
            {
                fragOut o;
                o.color = tex2D(_MainTex, i.uv);
                clip(o.color < 0.5 ? -1.0 : 1.0);
                #if defined(UNITY_REVERSED_Z)
                    o.depth = o.color;
                #else
                    o.depth = 1.0 - o.color;
                #endif
                return o;
            }
            ENDCG
    }
        Pass
        {
            ZWrite Off
            Name "Target only Color"
            CGPROGRAM
            struct fragOut
            {
                fixed4 color : SV_Target0;
            };

            fragOut frag(v2f i)
            {
                fragOut o;
                o.color = tex2D(_MainTex, i.uv);
                return o;
            }
            ENDCG
        }
        Pass
        {
            ZWrite On
            Name "Target only DepthStencil"
            Stencil
            {
                Ref 255
                Comp Always
                Pass Replace
            }
            CGPROGRAM
            struct fragOut
            {
                float depth : SV_Depth;
            };

            fragOut frag(v2f i)
            {
                fragOut o;
                fixed4 depth = tex2D(_MainTex, i.uv);
                clip(depth.x < 0.5 ? -1.0 : 1.0);
                #if defined(UNITY_REVERSED_Z)
                    o.depth = depth;
                #else
                    o.depth = 1.0 - depth;
                #endif
                return o;
            }
            ENDCG
        }
    }
}
