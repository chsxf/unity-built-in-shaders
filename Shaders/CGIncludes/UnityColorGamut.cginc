// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_COLOR_GAMUT_INCLUDED
#define UNITY_COLOR_GAMUT_INCLUDED

// Conversion methods for dealing with HDR encoding within the built-in render pipeline.

// These values must match the ColorGamut enum in ColorGamut.h
#define kColorGamutSRGB         0
#define kColorGamutRec709       1
#define kColorGamutRec2020      2
#define kColorGamutDisplayP3    3
#define kColorGamutHDR10        4
#define kColorGamutDolbyHDR     5
#define kColorGamutP3D65G22     6

#if SHADER_API_METAL
#define kReferenceLuminanceWhiteForRec709 100
#else
#define kReferenceLuminanceWhiteForRec709 80
#endif

float3 LinearToSRGB(float3 color)
{
    // Approximately pow(color, 1.0 / 2.2)
    return color < 0.0031308 ? 12.92 * color : 1.055 * pow(abs(color), 1.0 / 2.4) - 0.055;
}

float3 SRGBToLinear(float3 color)
{
    // Approximately pow(color, 2.2)
    return color < 0.04045 ? color / 12.92 : pow(abs(color + 0.055) / 1.055, 2.4);
}

static const float3x3 Rec709ToRec2020 =
{
    0.627402, 0.329292, 0.043306,
    0.069095, 0.919544, 0.011360,
    0.016394, 0.088028, 0.895578
};

static const float3x3 Rec2020ToRec709 =
{
    1.660496, -0.587656, -0.072840,
    -0.124547, 1.132895, -0.008348,
    -0.018154, -0.100597, 1.118751
};

#define PQ_M1 (2610.0 / 4096.0 / 4)
#define PQ_M2 (2523.0 / 4096.0 * 128)
#define PQ_C1 (3424.0 / 4096.0)
#define PQ_C2 (2413.0 / 4096.0 * 32)
#define PQ_C3 (2392.0 / 4096.0 * 32)

float3 LinearToST2084(float3 color)
{
    float3 cp = pow(abs(color), PQ_M1);
    return pow((PQ_C1 + PQ_C2 * cp) / (1 + PQ_C3 * cp), PQ_M2);
}

float3 ST2084ToLinear(float3 color)
{
    float3 x = pow(abs(color), 1.0 / PQ_M2);
    return pow(max(x - PQ_C1, 0) / (PQ_C2 - PQ_C3 * x), 1.0 / PQ_M1);
}


static const float3x3 Rec709ToP3D65Mat =
{
    0.822462, 0.177538, 0.000000,
    0.033194, 0.966806, 0.000000,
    0.017083, 0.072397, 0.910520
};

static const float3x3 P3D65MatToRec709 =
{
     1.224940, -0.224940,  0.000000,
    -0.042056,  1.042056,  0.000000,
    -0.019637, -0.078636,  1.098273
};

float3 LinearToGamma22(float3 color)
{
    return pow(abs(color.rgb), float3(0.454545454545455, 0.454545454545455, 0.454545454545455));
}

float3 Gamma22ToLinear(float3 color)
{
    return pow(abs(color.rgb), float3(2.2, 2.2, 2.2));
}


float3 SimpleHDRDisplayToneMapAndOETF(float3 scene, int colorGamut, bool forceGammaToLinear, float nitsForPaperWhite, float maxDisplayNits)
{
        float3 result = (IsGammaSpace() || forceGammaToLinear) ? float3(GammaToLinearSpaceExact(scene.r), GammaToLinearSpaceExact(scene.g), GammaToLinearSpaceExact(scene.b)) : scene.rgb;

        if (colorGamut == kColorGamutSRGB)
        {
            if (!IsGammaSpace())
                result = LinearToSRGB(result);
        }
        else if (colorGamut == kColorGamutHDR10)
        {
            const float st2084max = 10000.0;
            const float hdrScalar = nitsForPaperWhite / st2084max;
            // The HDR scene is in Rec.709, but the display is Rec.2020
            result = mul(Rec709ToRec2020, result);
            // Apply the ST.2084 curve to the scene.
            result = LinearToST2084(result * hdrScalar);
        }
        else if (colorGamut == kColorGamutP3D65G22)
        {
            const float hdrScalar = nitsForPaperWhite / maxDisplayNits;
            // The HDR scene is in Rec.709, but the display is P3
            result = mul(Rec709ToP3D65Mat, result);
            // Apply gamma 2.2
            result = LinearToGamma22(result * hdrScalar);
        }
        else // colorGamut == kColorGamutRec709
        {
            const float hdrScalar = nitsForPaperWhite / kReferenceLuminanceWhiteForRec709;
            result *= hdrScalar;
        }
    return result;
}

float3 InverseSimpleHDRDisplayToneMapAndOETF(float3 result, int colorGamut, bool forceGammaToLinear, float nitsForPaperWhite, float maxDisplayNits)
{
        if (colorGamut == kColorGamutSRGB)
        {
            if (!IsGammaSpace())
                result = SRGBToLinear(result);
        }
        else if (colorGamut == kColorGamutHDR10)
        {
            const float st2084max = 10000.0;
            const float hdrScalar = nitsForPaperWhite / st2084max;

            // Unapply the ST.2084 curve to the scene.
            result = ST2084ToLinear(result);
            result = result / hdrScalar;

            // The display is Rec.2020, but HDR scene is in Rec.709
            result = mul(Rec2020ToRec709, result);

        }
        else if (colorGamut == kColorGamutP3D65G22)
        {
            const float hdrScalar = nitsForPaperWhite / maxDisplayNits;

            // Unapply gamma 2.2
            result = Gamma22ToLinear(result);
            result = result / hdrScalar;

            // The display is P3, but he HDR scene is in Rec.709
            result = mul(P3D65MatToRec709, result);
        }
        else // colorGamut == kColorGamutRec709
        {
            const float hdrScalar = nitsForPaperWhite / kReferenceLuminanceWhiteForRec709;
            result /= hdrScalar;
        }

        result = (IsGammaSpace() || forceGammaToLinear) ? float3(LinearToGammaSpaceExact(result.r), LinearToGammaSpaceExact(result.g), LinearToGammaSpaceExact(result.b)) : result.rgb;

        return result;
}

#endif
