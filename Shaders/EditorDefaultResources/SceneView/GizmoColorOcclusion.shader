// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

// color, with occlusion
Shader "Hidden/Editor Gizmo Color Occlusion"
{
    SubShader
    {
        Tags { "ForceSupported" = "True" "Queue" = "Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off Cull Off Fog { Mode Off }
        ZTest LEqual
        BindChannels
        {
            Bind "Vertex", vertex
            Bind "Color", color
        }
        Pass { }
        Pass { }
    }
}
