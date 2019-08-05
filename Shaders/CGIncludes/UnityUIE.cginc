// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_UIE_INCLUDED
#define UNITY_UIE_INCLUDED

#ifndef UIE_SKIN_USING_CONSTANTS
    #if SHADER_TARGET < 45
        #define UIE_SKIN_USING_CONSTANTS
    #endif // SHADER_TARGET < 30
#endif // UIE_SKIN_USING_CONSTANTS

// The value below is only used on older shader targets, and should be configurable for the app at hand to be the smallest possible
#ifndef UIE_SKIN_ELEMS_COUNT_MAX_CONSTANTS
#define UIE_SKIN_ELEMS_COUNT_MAX_CONSTANTS 20
#endif // UIE_SKIN_ELEMS_COUNT_MAX_CONSTANTS

#include "UnityCG.cginc"

sampler2D _MainTex;
float4 _MainTex_ST;
float4 _MainTex_TexelSize;

sampler2D _FontTex;
float4 _FontTex_ST;

sampler2D _CustomTex;
float4 _CustomTex_ST;

fixed4 _Color;
float4 _1PixelClipInvView; // xy in clip space, zw inverse in view space
float4 _PixelClipRect; // In framebuffer space

#ifdef UIE_SKIN_USING_CONSTANTS

CBUFFER_START(UITransforms)
float4 _Transforms[UIE_SKIN_ELEMS_COUNT_MAX_CONSTANTS * 4]; // 3 float4s map to matrix 3 columns (the projection column is ignored), and a float4 representing a clip rectangle
CBUFFER_END

#else // !UIE_SKIN_USING_CONSTANTS

struct Transform3x4 { float4 v0, v1, v2, clipRect; };
StructuredBuffer<Transform3x4> _TransformsBuffer; // 3 float4s map to matrix 3 columns (the projection column is ignored), and a float4 representing a clip rectangle

#endif // UIE_SKIN_USING_CONSTANTS


struct appdata_t
{
    float4 vertex   : POSITION;
    float4 color    : COLOR;
    float2 uv       : TEXCOORD0;
    float3 xformIDsAndFlags : TEXCOORD1; // transformID,clipRectID,Flags
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct v2f
{
    float4 vertex   : SV_POSITION;
    fixed4 color    : COLOR;
    float4 uvXY  : TEXCOORD0; // UV and ZW holds XY position in points
    nointerpolation fixed4 flags : TEXCOORD1;
    nointerpolation fixed4 clipRect : TEXCOORD2;
    UNITY_VERTEX_OUTPUT_STEREO
};

static const float kUIEVertexLastFlagValue = 6.0f; // Keep in track with UIR.VertexFlags

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

static float3x4 uie_toWorldMat;
static float4 uie_clipRect;

// Returns the view-space offset that must be applied to the vertex to satisfy a minimum displacement constraint.
// vertex               Coordinates of the vertex, in vertex-space.
// embeddedDisplacement Displacement vector that is embedded in vertex, in vertex-space.
// minDisplacement      Minimum length of the displacement that must be observed, in pixels.
float2 uie_get_border_offset(float4 vertex, float2 embeddedDisplacement, float minDisplacement)
{
    // Compute the displacement length in framebuffer space (unit = 1 pixel).
    float2 viewDisplacement = mul(uie_toWorldMat, float4(embeddedDisplacement, 0, 0)).xy;
    float frameDisplacementLength = length(viewDisplacement * _1PixelClipInvView.zw);

    // We need to meet the minimum displacement requirement before rounding so that we can simply add 1 after rounding
    // if we don't meet it anymore.
    float newFrameDisplacementLength = max(minDisplacement, frameDisplacementLength);
    newFrameDisplacementLength = round(newFrameDisplacementLength);
    newFrameDisplacementLength += step(newFrameDisplacementLength, minDisplacement - 0.001);

    // Convert the resulting displacement into an offset.
    float changeRatio = newFrameDisplacementLength / (frameDisplacementLength + 0.000001);
    float2 viewOffset = (changeRatio - 1) * viewDisplacement;

    return viewOffset;
}

float2 uie_snap_to_integer_pos(float2 clipSpaceXY)
{
    return ((int2)((clipSpaceXY+1)/_1PixelClipInvView.xy+0.51f)) * _1PixelClipInvView.xy-1;
}

void uie_fragment_clip(v2f IN)
{
    float2 pointPos = IN.uvXY.zw;
    float2 pixelPos = IN.vertex.xy;
    float2 s = step(IN.clipRect.xy,   pointPos) + step(pointPos, IN.clipRect.zw) +
               step(_PixelClipRect.xy, pixelPos)  + step(pixelPos, _PixelClipRect.zw);
    clip(dot(float3(s,1),float3(1,1,-7.95f)));
}

void uie_vert_load_payload(appdata_t v)
{
#ifdef UIE_SKIN_USING_CONSTANTS

    uie_toWorldMat = float3x4(
        _Transforms[v.xformIDsAndFlags.x * 4 + 0],
        _Transforms[v.xformIDsAndFlags.x * 4 + 1],
        _Transforms[v.xformIDsAndFlags.x * 4 + 2]);
    uie_clipRect = _Transforms[v.xformIDsAndFlags.y * 4 + 3];

#else // !UIE_SKIN_USING_CONSTANTS

    Transform3x4 transform = _TransformsBuffer[v.xformIDsAndFlags.x];
    uie_toWorldMat = float3x4(transform.v0, transform.v1, transform.v2);
    uie_clipRect = _TransformsBuffer[v.xformIDsAndFlags.y].clipRect;

#endif // UIE_SKIN_USING_CONSTANTS
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

v2f uie_std_vert(appdata_t v)
{
    v2f OUT;
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

    uie_vert_load_payload(v);
    float flags = v.xformIDsAndFlags.z;
    // Keep the descending order for GLES2
    const float isSVGGradients = TestForValue(5.0, flags);
    const float isEdge = TestForValue(4.0, flags);
    const float isCustom = TestForValue(3.0, flags);
    const float isTextured = TestForValue(2.0, flags);
    const float isText = TestForValue(1.0, flags);

    float2 viewOffset = float2(0, 0);
    if (isEdge == 1)
        viewOffset = uie_get_border_offset(v.vertex, v.uv, 1);

    v.vertex.xyz = mul(uie_toWorldMat, v.vertex);
    v.vertex.xy += viewOffset;

    OUT.uvXY.zw = v.vertex.xy;
    OUT.vertex = UnityObjectToClipPos(v.vertex);

    if (isText == 1)
        OUT.vertex.xy = uie_snap_to_integer_pos(OUT.vertex.xy);

    OUT.uvXY.xy = TRANSFORM_TEX(v.uv, _MainTex);
    if (isTextured == 1.0f && isCustom == 0.0f)
        OUT.uvXY.xy *= _MainTex_TexelSize.xy;
    OUT.color = v.color * _Color;
    OUT.flags = fixed4(isText, isTextured, isCustom, 1 - saturate(isText + isTextured + isCustom));
    OUT.clipRect = uie_clipRect; // In points

    return OUT;
}

fixed4 uie_std_frag(v2f IN)
{
    uie_fragment_clip(IN);

    // Extract the flags.
    fixed isText     = IN.flags.x;
    fixed isTextured = IN.flags.y;
    fixed isCustom   = IN.flags.z;
    fixed isSolid    = IN.flags.w;
    float2 uv = IN.uvXY.xy;

    half4 atlasColor = tex2D(_MainTex, uv) * isTextured;
    half4 fontColor = half4(1, 1, 1, tex2D(_FontTex, uv).a) * isText;
    half4 customColor = tex2D(_CustomTex, uv) * isCustom;

    half4 texColor = (half4)isSolid + atlasColor + fontColor + customColor;
    half4 color = texColor * IN.color;
    return color;
}

#ifndef UIE_CUSTOM_SHADER

v2f vert(appdata_t v) { return uie_std_vert(v); }
fixed4 frag(v2f IN) : SV_Target { return uie_std_frag(IN); }

#endif // UIE_CUSTOM_SHADER

#endif // UNITY_UIE_INCLUDED
