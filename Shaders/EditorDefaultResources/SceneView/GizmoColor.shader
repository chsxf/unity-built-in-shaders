// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

// vertex color
Shader "Hidden/Editor Gizmo"
{
    SubShader
    {
        Tags { "ForceSupported" = "True" "Queue" = "Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off Cull Off Fog { Mode Off }
        Offset -1, -1
        BindChannels
        {
            Bind "Vertex", vertex
            Bind "Color", color
        }
        Pass // regular pass
        {
            ZTest LEqual
            SetTexture [_MainTex] { combine primary }
        }
        Pass // occluded pass
        {
            ZTest Greater
            SetTexture [_MainTex] { constantColor(1,1,1,0.1) combine constant * primary }
        }
    }
}
