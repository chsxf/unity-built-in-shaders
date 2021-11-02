// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/Handles Shaded" {
    Properties {
        _Color ("Main Color", Color) = (1,1,1,1)
        _SkyColor ("Sky Color", Color) = (1,1,1,1)
        _GroundColor ("Ground Color", Color) = (1,1,1,1)
        _MainTex ("Base (RGB) Gloss (A)", 2D) = "white" {}
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrcMode ("_BlendSrcMode", Int) = 5 //SrcAlpha = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendDstMode ("_BlendDstMode", Int) = 10 //OneMinusSrcAlpha = 10
        [Enum(UnityEngine.Rendering.CompareFunction)] _HandleZTest ("_HandleZTest", Int) = 8
    }
    Category {
        Fog {Mode Off}
        Blend [_BlendSrcMode] [_BlendDstMode]
        ZWrite Off
        ZTest [_HandleZTest]

        SubShader {
            Tags { "Queue" = "Transparent" "ForceSupported" = "True" }
            Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #include "HandlesRenderShader.cginc"
            fixed4 frag (v2f i) : SV_Target { return i.color; }
            ENDCG
            }
        }
    }
}
