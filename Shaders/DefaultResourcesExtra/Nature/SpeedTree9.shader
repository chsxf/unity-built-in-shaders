// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader"Nature/SpeedTree9"
{
    Properties
    {
        _MainTex ("Base (RGB) Transparency (A)", 2D) = "white" {}
        _ColorTint ("Color", Color) = (1,1,1,1)

        [Toggle(EFFECT_HUE_VARIATION)] _HueVariationKwToggle("Hue Variation", Float) = 0
        _HueVariationColor ("Hue Variation Color", Color) = (1.0,0.5,0.0,0.1)

        [Toggle(EFFECT_BUMP)] _NormalMapKwToggle("Normal Mapping", Float) = 0
        _NormalMap ("Normalmap", 2D) = "bump" {}

        _ExtraTex ("Smoothness (R), Metallic (G), AO (B)", 2D) = "(0.5, 0.0, 1.0)" {}
        _Glossiness ("Smoothness", Range(0.0, 1.0)) = 0.5
        _Metallic ("Metallic", Range(0.0, 1.0)) = 0.0

        [Toggle(EFFECT_SUBSURFACE)] _SubsurfaceKwToggle("Subsurface", Float) = 0
        _SubsurfaceTex ("Subsurface (RGB)", 2D) = "white" {}
        _SubsurfaceColor ("Subsurface Color", Color) = (1,1,1,1)
        _SubsurfaceIndirect ("Subsurface Indirect", Range(0.0, 1.0)) = 0.25

        [Toggle(EFFECT_BILLBOARD)] _BillboardKwToggle("Billboard", Float) = 0
        _BillboardShadowFade ("Billboard Shadow Fade", Range(0.0, 1.0)) = 0.5

        [Enum(No,2,Yes,0)] _TwoSided ("Two Sided", Int) = 2 // enum matches cull mode
        [Toggle(EFFECT_LEAF_FACING)] _LeafFacingKwToggle("Leaf Facing", Float) = 0

        // wind
        [Toggle(WIND_SHARED)] _WIND_SHARED("Shared", Float) = 0
        [Toggle(WIND_BRANCH1)] _WIND_BRANCH1("Branch 1", Float) = 0
        [Toggle(WIND_BRANCH2)] _WIND_BRANCH2("Branch 2", Float) = 0
        [Toggle(WIND_RIPPLE)] _WIND_RIPPLE("Ripple", Float) = 0
        [Toggle(WIND_SHIMMER)] _WIND_SHIMMER("Shimmer", Float) = 0
    }

    SubShader
    {
        Tags
        {
            "Queue"="AlphaTest"
            "IgnoreProjector"="True"
            "RenderType"="TransparentCutout"
            "DisableBatching"="LODFading"
        }
        LOD 400
        Cull [_TwoSided]

        CGPROGRAM
            #pragma surface SpeedTreeSurf SpeedTreeSubsurface vertex:SpeedTreeVert9 dithercrossfade addshadow
            #pragma target 3.0
            #define LOD_FADE_PERCENTAGE 1
            #pragma instancing_options assumeuniformscaling maxcount:50

            #pragma shader_feature_local EFFECT_BILLBOARD

            #pragma shader_feature_local_vertex WIND_SHARED
            #pragma shader_feature_local_vertex WIND_BRANCH1
            #pragma shader_feature_local_vertex WIND_BRANCH2
            #pragma shader_feature_local_vertex WIND_RIPPLE
            #pragma shader_feature_local_vertex WIND_SHIMMER

            #pragma shader_feature_local_vertex EFFECT_LEAF_FACING
            #pragma shader_feature_local_fragment EFFECT_HUE_VARIATION
            #pragma shader_feature_local_fragment EFFECT_SUBSURFACE
            #pragma shader_feature_local_fragment EFFECT_BUMP
            #pragma shader_feature_local_fragment EFFECT_EXTRA_TEX

            //#pragma enable_d3d11_debug_symbols

            #define ENABLE_WIND 1
            #define EFFECT_BACKSIDE_NORMALS
            #define SPEEDTREE_Y_UP

#include "UnityCG.cginc"
#include "UnityPBSLighting.cginc"
#include "SpeedTreeShaderLibrary.cginc"

#if ENABLE_WIND
#define SPEEDTREE_9_WIND 1
#include "SpeedTreeWind.cginc"
void Wind9(inout appdata_full sIn, bool bHistory /*must be compile-time constant*/)
{
    CBufferSpeedTree9 cb = ReadCBuffer(bHistory);
    const float fWindDirectionLengthSq = dot(cb.m_vWindDirection, cb.m_vWindDirection);
    if (fWindDirectionLengthSq == 0.0f) // check if we have valid wind vector
    {
        return;
    }

    float3 vUp = normalize(mul((float3x3) unity_WorldToObject, float3(0.0, 1.0, 0.0)));
    float3 vWindyPosition = sIn.vertex.xyz;

    // global noise applied to animation instances to break off synchronized
    // movement among multiple instances under wind effect.
    float3 treePos = float3(unity_ObjectToWorld[0].w, unity_ObjectToWorld[1].w, unity_ObjectToWorld[2].w);
    float3 vGlobalNoisePosition = treePos * cb.m_fWindIndependence;

    #if WIND_RIPPLE
    {
        float fRippleWeight = sIn.texcoord1.w;
        float3 vMotion = RippleWindMotion(
            vUp,
            cb.m_vWindDirection,
            vWindyPosition,
            vGlobalNoisePosition,
            fRippleWeight,
            cb.m_sRipple.m_vNoisePosTurbulence,
            cb.m_sRipple.m_fIndependence,
            cb.m_sRipple.m_fFlexibility,
            cb.m_sRipple.m_fDirectional,
            cb.m_sRipple.m_fPlanar,
            cb.m_vTreeExtents.y, // y-up = height
            cb.m_fImportScaling
        );
        vWindyPosition += vMotion;

        #if WIND_SHIMMER
        sIn.normal = normalize(sIn.normal - (vMotion * cb.m_sRipple.m_fShimmer));
        #endif
    }
    #endif

    #if WIND_BRANCH2
    {
        float fBranch2Weight = sIn.texcoord2.z;
        float fPackedBranch2Dir = sIn.texcoord2.y;
        float fPackedBranch2NoiseOffset = sIn.texcoord2.x;
        vWindyPosition = BranchWindPosition(
            vUp,
            cb.m_vWindDirection,
            vWindyPosition,
            vGlobalNoisePosition,
            fPackedBranch2Dir,
            fPackedBranch2NoiseOffset,
            fBranch2Weight,
            cb.m_fBranch2StretchLimit,
            cb.m_sBranch2.m_vNoisePosTurbulence,
            cb.m_sBranch2.m_fIndependence,
            cb.m_sBranch2.m_fTurbulence,
            cb.m_sBranch2.m_fOscillation,
            cb.m_sBranch2.m_fBend,
            cb.m_sBranch2.m_fFlexibility,
            cb.m_vTreeExtents.y, // y-up = height
            cb.m_fImportScaling
        );
    }
    #endif

    #if WIND_BRANCH1
    {
        float fBranch1Weight = sIn.texcoord1.z;
        float fPackedBranch1Dir = sIn.texcoord.w;
        float fPackedBranch1NoiseOffset = sIn.texcoord.z;
        vWindyPosition = BranchWindPosition(
            vUp,
            cb.m_vWindDirection,
            vWindyPosition,
            vGlobalNoisePosition,
            fPackedBranch1Dir,
            fPackedBranch1NoiseOffset,
            fBranch1Weight,
            cb.m_fBranch1StretchLimit,
            cb.m_sBranch1.m_vNoisePosTurbulence,
            cb.m_sBranch1.m_fIndependence,
            cb.m_sBranch1.m_fTurbulence,
            cb.m_sBranch1.m_fOscillation,
            cb.m_sBranch1.m_fBend,
            cb.m_sBranch1.m_fFlexibility,
            cb.m_vTreeExtents.y, // y-up = height
            cb.m_fImportScaling
        );
    }
    #endif

    #if WIND_SHARED
    {
        vWindyPosition = SharedWindPosition(
            vUp,
            cb.m_vWindDirection,
            vWindyPosition,
            vGlobalNoisePosition,
            cb.m_vTreeExtents.y, // y-up = height
            cb.m_fSharedHeightStart,
            cb.m_sShared.m_vNoisePosTurbulence,
            cb.m_sShared.m_fTurbulence,
            cb.m_sShared.m_fOscillation,
            cb.m_sShared.m_fBend,
            cb.m_sShared.m_fFlexibility,
            cb.m_fImportScaling
        );
    }
    #endif

    sIn.vertex.xyz = vWindyPosition;
}
#endif // ENABLE_WIND

void SpeedTreeVert9(inout appdata_full v)
{
#if defined(EFFECT_LEAF_FACING) && !defined(EFFECT_BILLBOARD)
    const bool bHasCameraFacingLeaf = v.texcoord3.a > 0.0f || v.texcoord2.a > 0.0f;
    if(bHasCameraFacingLeaf)
    {
        float3 vAnchorPos = v.texcoord3.a > 0.0f ? v.texcoord3.xyz : v.texcoord2.xyz;
        v.vertex.xyz = DoLeafFacing(v.vertex.xyz, vAnchorPos);
    }
#endif // EFFECT_LEAF_FACING

    float3 vVertexObjectSpacePosition = v.vertex;
#if ENABLE_WIND
    const bool bHistory = false; // must be compile time constant
    Wind9(v, bHistory);
#endif

    float3 vWindDisplacement = v.vertex - vVertexObjectSpacePosition;

#if defined(EFFECT_BILLBOARD)
    float3 treePos = float3(unity_ObjectToWorld[0].w, unity_ObjectToWorld[1].w, unity_ObjectToWorld[2].w);
    BillboardSeamCrossfade(v, treePos);
#endif // EFFECT_BILLBOARD
}




///////////////////////////////////////////////////////////////////////
//  surface shader

struct Input
{
    half2 uv_MainTex : TEXCOORD0;
    fixed4 color : COLOR;

#ifdef EFFECT_BACKSIDE_NORMALS
    fixed facing : VFACE;
#endif
};


sampler2D _MainTex;
fixed4 _ColorTint;
int _TwoSided;

#ifdef EFFECT_BUMP
    sampler2D _NormalMap;
#endif

#ifdef EFFECT_EXTRA_TEX
    sampler2D _ExtraTex;
#else
half _Glossiness;
half _Metallic;
#endif

#ifdef EFFECT_HUE_VARIATION
    half4 _HueVariationColor;
#endif

#ifdef EFFECT_BILLBOARD
    half _BillboardShadowFade;
#endif

#ifdef EFFECT_SUBSURFACE
    sampler2D _SubsurfaceTex;
    fixed4 _SubsurfaceColor;
    half _SubsurfaceIndirect;
#endif

half4 LightingSpeedTreeSubsurface(inout SurfaceOutputStandard s, half3 viewDir, UnityGI gi)
{
#ifdef EFFECT_SUBSURFACE
        half fSubsurfaceRough = 0.7 - s.Smoothness * 0.5;
        half fSubsurface = GGXTerm(clamp(-dot(gi.light.dir, viewDir), 0, 1), fSubsurfaceRough);

        // put modulated subsurface back into emission
        s.Emission *= (gi.indirect.diffuse * _SubsurfaceIndirect + gi.light.color * fSubsurface);
#endif

    return LightingStandard(s, viewDir, gi);
}

void LightingSpeedTreeSubsurface_GI(inout SurfaceOutputStandard s, UnityGIInput data, inout UnityGI gi)
{
#ifdef EFFECT_BILLBOARD
        // fade off the shadows on billboards to avoid artifacts
        data.atten = lerp(data.atten, 1.0, _BillboardShadowFade);
#endif

    LightingStandard_GI(s, data, gi);
}

half4 LightingSpeedTreeSubsurface_Deferred(SurfaceOutputStandard s, half3 viewDir, UnityGI gi, out half4 outGBuffer0, out half4 outGBuffer1, out half4 outGBuffer2)
{
    // no light/shadow info in deferred, so stop subsurface
    s.Emission = half3(0, 0, 0);

    return LightingStandard_Deferred(s, viewDir, gi, outGBuffer0, outGBuffer1, outGBuffer2);
}

void SpeedTreeSurf(Input IN, inout SurfaceOutputStandard OUT)
{
    fixed4 color = tex2D(_MainTex, IN.uv_MainTex) * _ColorTint;
    float fBlend = IN.color.a;

    // transparency
    OUT.Alpha = color.a * fBlend;
    clip(OUT.Alpha - 0.3333);

    // color
    OUT.Albedo = color.rgb;

    // hue variation
#ifdef EFFECT_HUE_VARIATION
    half3 shiftedColor = lerp(OUT.Albedo, _HueVariationColor.rgb, IN.color.g);

    // preserve vibrance
    half maxBase = max(OUT.Albedo.r, max(OUT.Albedo.g, OUT.Albedo.b));
    half newMaxBase = max(shiftedColor.r, max(shiftedColor.g, shiftedColor.b));
    maxBase /= newMaxBase;
    maxBase = maxBase * 0.5f + 0.5f;
    shiftedColor.rgb *= maxBase;

    OUT.Albedo = saturate(shiftedColor);
#endif

    // normal
#ifdef EFFECT_BUMP
    OUT.Normal = UnpackNormal(tex2D(_NormalMap, IN.uv_MainTex));
#elif defined(EFFECT_BACKSIDE_NORMALS) || defined(EFFECT_BILLBOARD)
    OUT.Normal = float3(0, 0, 1);
#endif

    // flip normal on backsides
#ifdef EFFECT_BACKSIDE_NORMALS
    if (IN.facing < 0.5)
    {
        OUT.Normal.z = -OUT.Normal.z;
    }
#endif

    // adjust billboard normals to improve GI and matching
#ifdef EFFECT_BILLBOARD
        OUT.Normal.z *= 0.5;
        OUT.Normal = normalize(OUT.Normal);
#endif

    // extra
#ifdef EFFECT_EXTRA_TEX
    fixed4 extra = tex2D(_ExtraTex, IN.uv_MainTex);
    OUT.Smoothness = extra.r; // no slider is exposed when ExtraTex is not available, hence we skip the multiplication here
    OUT.Metallic = extra.g;
    OUT.Occlusion = extra.b * IN.color.r;
#else
    OUT.Smoothness = _Glossiness;
    OUT.Metallic = _Metallic;
    OUT.Occlusion = IN.color.r;
#endif

    // subsurface (hijack emissive)
#ifdef EFFECT_SUBSURFACE
    OUT.Emission = tex2D(_SubsurfaceTex, IN.uv_MainTex) * _SubsurfaceColor;
#endif
}


        ENDCG
    }

    // targeting SM2.0: Many effects are disabled for fewer instructions
//    SubShader
//    {
//        Tags
//        {
//            "Queue"="AlphaTest"
//            "IgnoreProjector"="True"
//            "RenderType"="TransparentCutout"
//            "DisableBatching"="LODFading"
//        }
//        LOD 400
//        Cull [_TwoSided]
//
//        CGPROGRAM
//            #pragma surface SpeedTreeSurf Standard vertex:SpeedTreeVert addshadow noinstancing
//            #define LOD_FADE_PERCENTAGE 1
//            #pragma shader_feature_local EFFECT_BILLBOARD
//            #pragma shader_feature_local EFFECT_EXTRA_TEX
//
//            #include "SpeedTree8Common.cginc"
//
//        ENDCG
//    }

    FallBack "Transparent/Cutout/VertexLit"
    CustomEditor "SpeedTree9ShaderGUI"
}
