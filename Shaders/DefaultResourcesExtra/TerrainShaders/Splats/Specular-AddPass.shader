// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/TerrainEngine/Splatmap/Specular-AddPass" {
    Properties {
        _SpecColor ("Specular Color", Color) = (0.5, 0.5, 0.5, 1)
        [PowerSlider(5.0)] _Shininess ("Shininess", Range (0.03, 1)) = 0.078125
        [HideInInspector] _TerrainHolesTexture("Holes Map (RGB)", 2D) = "white" {}
    }

    SubShader {
        Tags {
            "Queue" = "Geometry-99"
            "IgnoreProjector"="True"
            "RenderType" = "Opaque"
        }

        CGPROGRAM
        #pragma surface surf BlinnPhong decal:add vertex:SplatmapVert finalcolor:SplatmapFinalColor finalgbuffer:SplatmapFinalGBuffer fullforwardshadows nometa
        #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap forwardadd
        #pragma multi_compile_fog
        #pragma multi_compile_local_fragment __ _ALPHATEST_ON
        #pragma multi_compile_local __ _NORMALMAP
        #pragma target 3.0

        #define TERRAIN_SPLAT_ADDPASS
        #include "TerrainSplatmapCommon.cginc"

        half _Shininess;

        void surf(Input IN, inout SurfaceOutput o)
        {
            half4 splat_control;
            half weight;
            fixed4 mixedDiffuse;
            SplatmapMix(IN, splat_control, weight, mixedDiffuse, o.Normal);
            o.Albedo = mixedDiffuse.rgb;
            o.Alpha = weight;
            o.Gloss = mixedDiffuse.a;
            o.Specular = _Shininess;
        }
        ENDCG
    }

    Fallback "Hidden/TerrainEngine/Splatmap/Diffuse-AddPass"
}
