// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_UIE_INCLUDED
#define UNITY_UIE_INCLUDED

#if SHADER_TARGET >= 30
    #define UIE_SHADER_INFO_IN_VS 1
#else
    #define UIE_SHADER_INFO_IN_VS 0
#endif // SHADER_TARGET >= 30

#if SHADER_TARGET < 35
    #define UIE_TEXTURE_SLOT_COUNT 4
    #define UIE_FLAT_OPTIM
#else
    #define UIE_TEXTURE_SLOT_COUNT 8
    #define UIE_FLAT_OPTIM nointerpolation
#endif // SHADER_TARGET >= 35

#ifndef UIE_COLORSPACE_GAMMA
    #ifdef UNITY_COLORSPACE_GAMMA
        #define UIE_COLORSPACE_GAMMA 1
    #else
        #define UIE_COLORSPACE_GAMMA 0
    #endif // UNITY_COLORSPACE_GAMMA
#endif // UIE_COLORSPACE_GAMMA

#ifndef UIE_FRAG_T
    #if UIE_COLORSPACE_GAMMA
        #define UIE_FRAG_T fixed4
    #else
        #define UIE_FRAG_T half4
    #endif // UIE_COLORSPACE_GAMMA
#endif // UIE_FRAG_T

#ifndef UIE_V2F_COLOR_T
    #if UIE_COLORSPACE_GAMMA
        #define UIE_V2F_COLOR_T fixed4
    #else
        #define UIE_V2F_COLOR_T half4
    #endif // UIE_COLORSPACE_GAMMA
#endif // UIE_V2F_COLOR_T

// The value below is only used on older shader targets, and should be configurable for the app at hand to be the smallest possible
// The first entry is always the identity matrix
#ifndef UIE_SKIN_ELEMS_COUNT_MAX_CONSTANTS
#define UIE_SKIN_ELEMS_COUNT_MAX_CONSTANTS 20
#endif // UIE_SKIN_ELEMS_COUNT_MAX_CONSTANTS

#include "UnityCG.cginc"

sampler2D _FontTex;
float4 _FontTex_TexelSize;
float _FontTexSDFScale;

sampler2D _GradientSettingsTex;
float4 _GradientSettingsTex_TexelSize;

sampler2D _ShaderInfoTex;
float4 _ShaderInfoTex_TexelSize;

float4 _TextureInfo[UIE_TEXTURE_SLOT_COUNT]; // X id YZ texelSize

sampler2D _Texture0;
float4 _Texture0_ST;

sampler2D _Texture1;
float4 _Texture1_ST;

sampler2D _Texture2;
float4 _Texture2_ST;

sampler2D _Texture3;
float4 _Texture3_ST;

#if UIE_TEXTURE_SLOT_COUNT == 8
sampler2D _Texture4;
float4 _Texture4_ST;

sampler2D _Texture5;
float4 _Texture5_ST;

sampler2D _Texture6;
float4 _Texture6_ST;

sampler2D _Texture7;
float4 _Texture7_ST;
#endif

float4 _PixelClipInvView; // xy in clip space, zw inverse in view space
float4 _ScreenClipRect; // In clip space

#if !UIE_SHADER_INFO_IN_VS

CBUFFER_START(UITransforms)
float4 _Transforms[UIE_SKIN_ELEMS_COUNT_MAX_CONSTANTS * 3];
CBUFFER_END

CBUFFER_START(UIClipRects)
float4 _ClipRects[UIE_SKIN_ELEMS_COUNT_MAX_CONSTANTS];
CBUFFER_END

#endif // !UIE_SHADER_INFO_IN_VS

// This piecewise approximation has a precision better than 0.5 / 255 in gamma space over the [0..255] range
// i.e. abs(l2g_exact(g2l_approx(value)) - value) < 0.5 / 255
// It is much more precise than GammaToLinearSpace but remains relatively cheap
half3 uie_gamma_to_linear(half3 value)
{
    half3 low = 0.0849710 * value - 0.000163029;
    half3 high = value * (value * (value * 0.265885 + 0.736584) - 0.00980184) + 0.00319697;

    // We should be 0.5 away from any actual gamma value stored in an 8 bit channel
    const half3 split = (half3)0.0725490; // Equals 18.5 / 255
    return (value < split) ? low : high;
}

// This piecewise approximation has a very precision veryclose to that of LinearToGammaSpaceExact but explicitly
// avoids branching
half3 uie_linear_to_gamma(half3 value)
{
    half3 low = 12.92F * value;
    half3 high =  1.055F * pow(value, 0.4166667F) - 0.055F;

    const half3 split = (half3)0.0031308;
    return (value < split) ? low : high;
}

struct appdata_t
{
    float4 vertex   : POSITION;
    float4 color    : COLOR;
    float2 uv       : TEXCOORD0;
    float4 xformClipPages : TEXCOORD1; // Top-left of xform and clip pages: XY,XY
    float4 ids      : TEXCOORD2; //XYZW (xform,clip,opacity,color/textcore)
    float4 flags    : TEXCOORD3; //X (flags) Y (textcore-dilate) Z (is-arc) W (is-dynamic-colored)
    float4 opacityColorPages : TEXCOORD4; //XY: Opacity page, ZW: color page, or SVG/TexCore setting index
    float4 circle   : TEXCOORD5; // XY (outer) ZW (inner)
    float  textureId : TEXCOORD6; // X (textureId)

    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
    float4 pos : SV_POSITION;
    UIE_V2F_COLOR_T color : COLOR;
    float4 uvXY  : TEXCOORD0; // UV and ZW holds XY position in points
    UIE_FLAT_OPTIM half4 typeTexSettings : TEXCOORD1; // X: Render Type Y: Tex Index Z: SVG Gradient Index W: Is Arc
    UIE_FLAT_OPTIM fixed4 clipRectOpacityUVs : TEXCOORD2;
    UIE_FLAT_OPTIM float2 colorUVs : TEXCOORD3; // Color/TextCore UVs
    float4 clipPos : TEXCOORD4; // W holds textcore dilate flag
    half4 circle : TEXCOORD5;
#if UIE_SHADER_INFO_IN_VS
    UIE_FLAT_OPTIM float4 clipRect : TEXCOORD6; // Clip rect presampled
#endif // UIE_SHADER_INFO_IN_VS
    UNITY_VERTEX_OUTPUT_STEREO
};

static const float kUIEMeshZ = 0.0f; // Keep in track with UIRUtility.k_MeshPosZ
static const float kUIEMaskZ = 1.0f; // Keep in track with UIRUtility.k_MaskPosZ

// returns: Integer between 0 and UIE_TEXTURE_SLOT_COUNT - 1
half FindTextureSlot(float textureId)
{
#if UIE_TEXTURE_SLOT_COUNT > 4
    for(int i = 0 ; i < UIE_TEXTURE_SLOT_COUNT - 1 ; ++i)
        if (_TextureInfo[i].x == textureId)
            return i;
    return UIE_TEXTURE_SLOT_COUNT - 1;
#else
    // Unrolling because of GLES2 issues with loops.
    // Replaced '==' because they're messed up on some old GPUs.
    half slotIndex = 0;
    slotIndex += (1.0 - abs(sign(_TextureInfo[1].x - textureId))) * 1;
    slotIndex += (1.0 - abs(sign(_TextureInfo[2].x - textureId))) * 2;
    slotIndex += (1.0 - abs(sign(_TextureInfo[3].x - textureId))) * 3;
    return slotIndex;
#endif
}

// index: integer between [0..UIE_TEXTURE_SLOT_COUNT[
float4 SampleTextureSlot(half index, float2 uv)
{
    float4 result;

#if UIE_TEXTURE_SLOT_COUNT > 4
    if (index < 4)
    {
#endif
        if (index < 2)
        {
            if (index < 1)
            {
                result = tex2D(_Texture0, uv);
            }
            else
            {
                result = tex2D(_Texture1, uv);
            }
        }
        else // index >= 2
        {
            if (index < 3)
            {
                result = tex2D(_Texture2, uv);
            }
            else
            {
                result = tex2D(_Texture3, uv);
            }
        }
#if UIE_TEXTURE_SLOT_COUNT > 4
    }
    else // index >= 4
    {
        if (index < 6)
        {
            if (index < 5)
            {
                result = tex2D(_Texture4, uv);
            }
            else
            {
                result = tex2D(_Texture5, uv);
            }
        }
        else // index >= 6
        {
            if (index < 7)
            {
                result = tex2D(_Texture6, uv);
            }
            else
            {
                result = tex2D(_Texture7, uv);
            }
        }
    }
#endif

    return result;
}

// Notes on UIElements Spaces (Local, Bone, Group, World and Clip)
//
// Consider the following example:
//      *     <- Clip Space (GPU Clip Coordinates)
//    Proj
//      |     <- World Space
//   VEroot
//      |
//     VE1 (RenderHint = Group)
//      |     <- Group Space
//     VE2 (RenderHint = Bone)
//      |     <- Bone Space
//     VE3
//
// A VisualElement always emits vertices in local-space. They do not embed the transform of the emitting VisualElement.
// The renderer transforms the vertices on CPU from local-space to bone space (if available), or to the group space (if available),
// or ultimately to world-space if there is no ancestor with a bone transform or group transform.
//
// The world-to-clip transform is stored in UNITY_MATRIX_P
// The group-to-world transform is stored in UNITY_MATRIX_V
// The bone-to-group transform is stored in uie_toWorldMat.
//
// In this shader, we consider that vertices are always in bone-space, and we always apply the bone-to-group and the group-to-world
// transforms. It does not matter because in the event where there is no ancestor with a Group or Bone RenderHint, these transform
// will be identities.

static float4x4 uie_toWorldMat;

float2 uie_snap_to_integer_pos(float2 clipSpaceXY)
{
    // Convert from clip space to framebuffer space (unit = 1 pixel).
    float2 pixelPos = (clipSpaceXY + 1) / _PixelClipInvView.xy;
    // Add an offset before rounding to avoid half which is very common to land onto.
    float2 roundedPixelPos = round(pixelPos + 0.1527);
    // Go back to clip space.
    return roundedPixelPos * _PixelClipInvView.xy - 1;
}

void uie_fragment_clip(v2f IN)
{
    float4 clipRect;
#if UIE_SHADER_INFO_IN_VS
    clipRect = IN.clipRect; // Presampled in the vertex shader, and sent down to the fragment shader ready
#else // !UIE_SHADER_INFO_IN_VS
    clipRect = _ClipRects[IN.clipRectOpacityUVs.x];
#endif // UIE_SHADER_INFO_IN_VS

    float2 pointPos = IN.uvXY.zw;
    float2 clipPos = IN.clipPos.xy;
    float2 s = step(clipRect.xy, pointPos) + step(pointPos, clipRect.zw) +
        step(_ScreenClipRect.xy, clipPos) + step(clipPos, _ScreenClipRect.zw);
    clip(dot(float3(s,1),float3(1,1,-7.95f)));
}

float2 uie_decode_shader_info_texel_pos(float2 pageXY, float id, float yStride)
{
    const float kShaderInfoPageWidth = 32;
    const float kShaderInfoPageHeight = 8;
    id *= 255.0f;
    pageXY *= 255.0f; // From [0,1] to [0,255]
    float idX = id % kShaderInfoPageWidth;
    float idY = (id - idX) / kShaderInfoPageWidth;

    return float2(
        pageXY.x * kShaderInfoPageWidth + idX,
        pageXY.y * kShaderInfoPageHeight + idY * yStride);
}

void uie_vert_load_payload(appdata_t v)
{
#if UIE_SHADER_INFO_IN_VS

    float2 xformTexel = uie_decode_shader_info_texel_pos(v.xformClipPages.xy, v.ids.x, 3.0f);
    float2 row0UV = (xformTexel + float2(0, 0) + 0.5f) * _ShaderInfoTex_TexelSize.xy;
    float2 row1UV = (xformTexel + float2(0, 1) + 0.5f) * _ShaderInfoTex_TexelSize.xy;
    float2 row2UV = (xformTexel + float2(0, 2) + 0.5f) * _ShaderInfoTex_TexelSize.xy;

    uie_toWorldMat = float4x4(
        tex2Dlod(_ShaderInfoTex, float4(row0UV, 0, 0)),
        tex2Dlod(_ShaderInfoTex, float4(row1UV, 0, 0)),
        tex2Dlod(_ShaderInfoTex, float4(row2UV, 0, 0)),
        float4(0, 0, 0, 1));

#else // !UIE_SHADER_INFO_IN_VS

    int xformConstantIndex = (int)(v.ids.x * 255.0f * 3.0f);
    uie_toWorldMat = float4x4(
        _Transforms[xformConstantIndex + 0],
        _Transforms[xformConstantIndex + 1],
        _Transforms[xformConstantIndex + 2],
        float4(0, 0, 0, 1));

#endif // UIE_SHADER_INFO_IN_VS
}

float2 uie_unpack_float2(fixed4 c)
{
    return float2(c.r*255 + c.g, c.b*255 + c.a);
}

float2 uie_ray_unit_circle_first_hit(float2 rayStart, float2 rayDir)
{
    float tca = dot(-rayStart, rayDir);
    float d2 = dot(rayStart, rayStart) - tca * tca;
    float thc = sqrt(1.0f - d2);
    float t0 = tca - thc;
    float t1 = tca + thc;
    float t = min(t0, t1);
    if (t < 0.0f)
        t = max(t0, t1);
    return rayStart + rayDir * t;
}

float uie_radial_address(float2 uv, float2 focus)
{
    uv = (uv - float2(0.5f, 0.5f)) * 2.0f;
    float2 pointOnPerimeter = uie_ray_unit_circle_first_hit(focus, normalize(uv - focus));
    float2 diff = pointOnPerimeter - focus;
    if (abs(diff.x) > 0.0001f)
        return (uv.x - focus.x) / diff.x;
    if (abs(diff.y) > 0.0001f)
        return (uv.y - focus.y) / diff.y;
    return 0.0f;
}

struct GradientLocation
{
    float2 uv;
    float4 location;
};

GradientLocation uie_sample_gradient_location(float settingIndex, float2 uv, sampler2D settingsTex, float2 texelSize)
{
    // Gradient settings are stored in 3 consecutive texels:
    // - texel 0: (float4, 1 byte per float)
    //    x = gradient type (0 = tex/linear, 1 = radial)
    //    y = address mode (0 = wrap, 1 = clamp, 2 = mirror)
    //    z = radialFocus.x
    //    w = radialFocus.y
    // - texel 1: (float2, 2 bytes per float) atlas entry position
    //    xy = pos.x
    //    zw = pos.y
    // - texel 2: (float2, 2 bytes per float) atlas entry size
    //    xy = size.x
    //    zw = size.y

    float2 settingUV = float2(0.5f, settingIndex+0.5f) * texelSize;
    fixed4 gradSettings = tex2D(settingsTex, settingUV);
    if (gradSettings.x > 0.0f)
    {
        // Radial texture case
        float2 focus = (gradSettings.zw - float2(0.5f, 0.5f)) * 2.0f; // bring focus in the (-1,1) range
        uv = float2(uie_radial_address(uv, focus), 0.0);
    }

    int addressing = round(gradSettings.y * 255);
    uv.x = (addressing == 0) ? fmod(uv.x,1.0f) : uv.x; // Wrap
    uv.x = (addressing == 1) ? max(min(uv.x,1.0f), 0.0f) : uv.x; // Clamp
    float w = fmod(uv.x,2.0f);
    uv.x = (addressing == 2) ? (w > 1.0f ? 1.0f-fmod(w,1.0f) : w) : uv.x; // Mirror

    GradientLocation grad;
    grad.uv = uv;

    // Adjust UV to atlas position
    float2 nextUV = float2(texelSize.x, 0);
    grad.location.xy = (uie_unpack_float2(tex2D(settingsTex, settingUV+nextUV) * 255) + float2(0.5f, 0.5f));
    grad.location.zw = uie_unpack_float2(tex2D(settingsTex, settingUV+nextUV*2) * 255);

    return grad;
}

float TestForValue(float value, inout float flags)
{
#if SHADER_API_GLES
    float result = saturate(flags - value + 1.0);
    flags -= result * value;
    return result;
#else
    return flags == value;
#endif
}

// 1 layer : Face only
// sd           : Signed distance / sdfScale + 0.5
// sdfSizeRCP   : 1 / texture width
// sdfScale     : Signed Distance Field Scale
// isoPerimeter : Dilate / Contract the shape
float sd_to_coverage(float sd, float2 uv, float sdfSizeRCP, float sdfScale, float isoPerimeter)
{
    float ta = ddx(uv.x) * ddy(uv.y) - ddy(uv.x) * ddx(uv.y);   // Texel area covered by this pixel (parallelogram area)
    float ssr = rsqrt(abs(ta)) * sdfSizeRCP;                    // Texture to Screen Space Ratio (unit is Texel/Pixel)
    sd = (sd - 0.5) * sdfScale + isoPerimeter;                  // Signed Distance to edge (in texture space)
    return saturate(0.5 + 2.0 * sd * ssr);                      // Screen pixel coverage : center + (1 / sampling radius) * signed distance
}

// 3 Layers : Face, Outline, Underlay
// sd           : Signed distance / sdfScale + 0.5
// sdfSize      : texture height
// sdfScale     : Signed Distance Field Scale
// isoPerimeter : Dilate / Contract the shape
// softness     : softness of each outer edges
float3 sd_to_coverage(float3 sd, float2 uv, float sdfSize, float sdfScale, float3 isoPerimeter, float3 softness)
{
    // Case 1349202: The underline stretches its middle quad, making parallelogram area evaluation invalid and resulting
    //               in visual artifacts. For that reason, we can only rely on uv.y for the length ratio leading in some
    //               error when a rotation/skew/non-uniform scaling takes place.
    float ps = abs(ddx(uv.y)) + abs(ddy(uv.y));                       // Size of a pixel in texel space (approximation)
    float stsr = sdfSize * ps;                                        // Screen to Texture Space Ratio (unit is Pixel/Texel)
    sd = (sd - 0.5) * sdfScale + isoPerimeter;                        // Signed Distance to edge (in texture space)
    return saturate(0.5 + 2.0 * sd / (stsr + softness));              // Screen pixel coverage : center + (1 / sampling radius) * signed distance
}

UIE_FRAG_T uie_textcore(float textAlpha, float2 uv, float2 textCoreUV, float4 vertexColor, bool isDynamicColor, float extraDilate)
{
    float2 row0UV = (textCoreUV + float2(0, 0) + 0.5f) * _ShaderInfoTex_TexelSize.xy;
    float2 row1UV = (textCoreUV + float2(0, 1) + 0.5f) * _ShaderInfoTex_TexelSize.xy;
    float2 row2UV = (textCoreUV + float2(0, 2) + 0.5f) * _ShaderInfoTex_TexelSize.xy;
    float2 row3UV = (textCoreUV + float2(0, 3) + 0.5f) * _ShaderInfoTex_TexelSize.xy;

    float4 outlineColor  = tex2Dlod(_ShaderInfoTex, float4(row1UV, 0, 0));
    float4 underlayColor = tex2Dlod(_ShaderInfoTex, float4(row2UV, 0, 0));
    float4 settings      = tex2Dlod(_ShaderInfoTex, float4(row3UV, 0, 0));

    float4 faceColor = vertexColor;
    if (isDynamicColor)
        faceColor = tex2Dlod(_ShaderInfoTex, float4(row0UV, 0, 0));

    settings *= _FontTexSDFScale;
    float2 underlayOffset = settings.xy;
    float underlaySoftness = settings.z;
    float outlineDilate = settings.w * 0.25f;
    float3 dilate = float3(-outlineDilate, outlineDilate, 0);
    float3 softness = float3(0, 0, underlaySoftness);

    // Distance to Alpha
    float alpha1 = textAlpha;
    float alpha2 = tex2D(_FontTex, uv + underlayOffset * _FontTex_TexelSize.x).a;
    float3 alpha = sd_to_coverage(float3(alpha1, alpha1, alpha2), uv, _FontTex_TexelSize.w, _FontTexSDFScale, dilate + extraDilate, softness);

    // Blending of the 3 ARGB layers
    underlayColor.a *= alpha.z;
    faceColor.rgb *= faceColor.a;
    outlineColor.rgb *= outlineColor.a;
    underlayColor.rgb *= underlayColor.a;

    UIE_FRAG_T color = lerp(lerp(underlayColor, outlineColor, alpha.y), faceColor, alpha.x);
    color.rgb /= (color.a > 0.0f ? color.a : 1.0f);

    return color;
}

void uie_std_vert_shader_info(appdata_t v, out UIE_V2F_COLOR_T color, out float2 clipRectUV, out float2 opacityUV, out float2 colorUV)
{
#if UIE_COLORSPACE_GAMMA
    color = v.color;
#else // !UIE_COLORSPACE_GAMMA
    // Keep this in the VS to ensure that interpolation is performed in the right color space
    color = UIE_V2F_COLOR_T(uie_gamma_to_linear(v.color.rgb), v.color.a);
#endif // UIE_COLORSPACE_GAMMA

    opacityUV = (uie_decode_shader_info_texel_pos(v.opacityColorPages.xy, v.ids.z, 1.0f) + 0.5f) * _ShaderInfoTex_TexelSize.xy;
    colorUV = (uie_decode_shader_info_texel_pos(v.opacityColorPages.zw, v.ids.w, 1.0f) + 0.5f) * _ShaderInfoTex_TexelSize.xy;
#if UIE_SHADER_INFO_IN_VS
    if (v.flags.w > 0.0f)
        // Color is stored in shader info
        color = tex2Dlod(_ShaderInfoTex, float4(colorUV, 0, 0));
    clipRectUV = (uie_decode_shader_info_texel_pos(v.xformClipPages.zw, v.ids.y, 1.0f) + 0.5f) * _ShaderInfoTex_TexelSize.xy;
    color.a *= tex2Dlod(_ShaderInfoTex, float4(opacityUV, 0, 0)).a;
#else // !UIE_SHADER_INFO_IN_VS
    clipRectUV = float2(v.ids.y * 255.0f, 0.0f);
#endif // UIE_SHADER_INFO_IN_VS
}

float pixelDist(float2 uv)
{
    float dist = length(uv) - 1.0f; // Bring from [0,...] to [-1,...] range
    return dist / fwidth(dist);

    // Probably more accurate, but requires an additional length():
    // float2 ddist = float2(ddx(dist), ddy(dist));
    // return dist / length(ddist);
}

v2f uie_std_vert(appdata_t v)
{
    v2f OUT;
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

    uie_vert_load_payload(v);
    float flags = round(v.flags.x*255.0f); // Must round for MacGL VM
    // Keep the descending order for GLES2
    const float isSvgGradients   = TestForValue(4.0, flags);
    const float isDynamic        = TestForValue(3.0, flags);
    const float isTextured       = TestForValue(2.0, flags);
    const float isText           = TestForValue(1.0, flags);
    const float isSolid = 1 - saturate(isText + isTextured + isDynamic + isSvgGradients);

    v.vertex.xyz = mul(uie_toWorldMat, v.vertex);

    OUT.uvXY.zw = v.vertex.xy;
    OUT.pos = UnityObjectToClipPos(v.vertex);

    if (isText == 1 && _FontTexSDFScale == 0)
        OUT.pos.xy = uie_snap_to_integer_pos(OUT.pos.xy);

    OUT.clipPos.xy = OUT.pos.xy / OUT.pos.w;
    OUT.clipPos.zw = float2(0, v.flags.y);

    // 1 => solid, 2 => text, 3 => textured, 4 => svg
    half renderType = isSolid * 1 + isText * 2 + (isDynamic + isTextured) * 3 + isSvgGradients * 4;
    half textureSlot = FindTextureSlot(v.textureId);
    float settingIndex = v.opacityColorPages.z*(255.0f*255.0f) + v.opacityColorPages.w*255.0f;
    half isArc = v.flags.z > 0.0f ? 1.0f : 0.0f;
    half wFlags = isArc;
    if (v.flags.w > 0.0f)
        wFlags += 2.0f; // Poor man's bitset
    OUT.typeTexSettings = half4(renderType, textureSlot, settingIndex, wFlags);

    OUT.uvXY.xy = v.uv;
    if (isDynamic == 1.0f)
        OUT.uvXY.xy *= _TextureInfo[textureSlot].yz;

    uie_std_vert_shader_info(v, OUT.color, OUT.clipRectOpacityUVs.xy, OUT.clipRectOpacityUVs.zw, OUT.colorUVs.xy);
    OUT.colorUVs.xy = isText ? uie_decode_shader_info_texel_pos(v.opacityColorPages.zw, v.ids.w, 4.0f) : OUT.colorUVs.xy;

#if UIE_SHADER_INFO_IN_VS
    OUT.clipRect = tex2Dlod(_ShaderInfoTex, float4(OUT.clipRectOpacityUVs.xy, 0, 0));
#endif // UIE_SHADER_INFO_IN_VS

    OUT.circle = v.circle;

    return OUT;
}

UIE_FRAG_T uie_std_frag(v2f IN)
{
    uie_fragment_clip(IN);

    // Extract the render type
    bool isSolid        = IN.typeTexSettings.x == 1;
    bool isText         = IN.typeTexSettings.x == 2;
    bool isTextured     = IN.typeTexSettings.x == 3;
    bool isSvgGradients = IN.typeTexSettings.x == 4;
    float settingIndex  = IN.typeTexSettings.z;

    // Decode bitset
    bool isDynamicColor = IN.typeTexSettings.w >= 2.0;
    if (isDynamicColor)
        IN.typeTexSettings.w -= 2.0f;
    float isArc = IN.typeTexSettings.w;

    float2 uv = IN.uvXY.xy;

#if !UIE_SHADER_INFO_IN_VS
    IN.color.a *= tex2D(_ShaderInfoTex, IN.clipRectOpacityUVs.zw).a;
    if (isDynamicColor && !isText)
        IN.color = tex2D(_ShaderInfoTex, IN.colorUVs.xy);
#endif // !UIE_SHADER_INFO_IN_VS

    UIE_FRAG_T texColor = (UIE_FRAG_T)isSolid;
    if (isTextured)
    {
        texColor = SampleTextureSlot(IN.typeTexSettings.y, uv);
    }
    else if (isText)
    {
        float textAlpha = tex2D(_FontTex, uv).a;
        if (_FontTexSDFScale > 0.0f)
            texColor = uie_textcore(textAlpha, uv, IN.colorUVs.xy, IN.color, isDynamicColor, IN.clipPos.w);
        else
            texColor = UIE_FRAG_T(1, 1, 1, tex2D(_FontTex, uv).a);
    }
    else if (isSvgGradients)
    {
        float2 texelSize = _TextureInfo[IN.typeTexSettings.y].yz;
        GradientLocation grad = uie_sample_gradient_location(settingIndex, uv, _GradientSettingsTex, _GradientSettingsTex_TexelSize.xy);
        grad.location *= texelSize.xyxy;
        grad.uv *= grad.location.zw;
        grad.uv += grad.location.xy;
        texColor = SampleTextureSlot(IN.typeTexSettings.y, grad.uv);
    }

    UIE_FRAG_T color = (isText && _FontTexSDFScale > 0.0f) ? texColor : texColor * IN.color;

    if (isArc)
    {
        // Don't evaluate circles defined as kUnusedArc
        if (IN.circle.x > -9999.0f)
        {
            float outer = pixelDist(IN.circle.xy);
            color.a *= saturate(0.5f-outer);
        }
        if (IN.circle.z > -9999.0f)
        {
            float inner = pixelDist(IN.circle.zw);
            color.a *= 1.0f - saturate(0.5f-inner);
        }

        // Clip fragments when alpha is close to 0 (< 1/256 here).
        // This will write proper masks values in the stencil buffer.
        clip(color.a - 0.003f);
    }

    return color;
}

#ifndef UIE_CUSTOM_SHADER

v2f vert(appdata_t v) { return uie_std_vert(v); }
UIE_FRAG_T frag(v2f IN) : SV_Target { return uie_std_frag(IN); }

#endif // UIE_CUSTOM_SHADER

#endif // UNITY_UIE_INCLUDED
