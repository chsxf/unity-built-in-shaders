// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

// simple vertex lighting
Shader "Hidden/Editor Gizmo Lit"
{
    SubShader
    {
        Tags { "ForceSupported" = "True" "Queue" = "Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off Fog { Mode Off }
        Lighting On
        Material { Diffuse [_GizmoBatchColor] Ambient [_GizmoBatchColor] }
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
