// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

// simple wire no depth test
Shader "Hidden/Editor Gizmo"
{
    SubShader
    {
        Tags { "ForceSupported" = "True" "Queue" = "Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off Cull Off Fog { Mode Off }
        Offset -1, -1
        Color [_GizmoBatchColor]
        Pass // regular pass
        {
            ZTest Always
            SetTexture [_MainTex] { combine primary }
        }
        Pass // occluded pass
        {
            ZTest Never
        }
    }
}
