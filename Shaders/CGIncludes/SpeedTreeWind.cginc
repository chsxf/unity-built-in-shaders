// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef SPEEDTREE_WIND_INCLUDED
#define SPEEDTREE_WIND_INCLUDED

#if !defined(SPEEDTREE_8_WIND) && !defined(SPEEDTREE_9_WIND)
#define SPEEDTREE_8_WIND 0
#define SPEEDTREE_9_WIND 1
#endif

#if SPEEDTREE_8_WIND

///////////////////////////////////////////////////////////////////////
//  Wind Info

CBUFFER_START(SpeedTreeWind)
    float4 _ST_WindVector;
    float4 _ST_WindGlobal;
    float4 _ST_WindBranch;
    float4 _ST_WindBranchTwitch;
    float4 _ST_WindBranchWhip;
    float4 _ST_WindBranchAnchor;
    float4 _ST_WindBranchAdherences;
    float4 _ST_WindTurbulences;
    float4 _ST_WindLeaf1Ripple;
    float4 _ST_WindLeaf1Tumble;
    float4 _ST_WindLeaf1Twitch;
    float4 _ST_WindLeaf2Ripple;
    float4 _ST_WindLeaf2Tumble;
    float4 _ST_WindLeaf2Twitch;
    float4 _ST_WindFrondRipple;
    float4 _ST_WindAnimation;
CBUFFER_END

///////////////////////////////////////////////////////////////////////
//  UnpackNormalFromFloat

float3 UnpackNormalFromFloat(float fValue)
{
    float3 vDecodeKey = float3(16.0, 1.0, 0.0625);

    // decode into [0,1] range
    float3 vDecodedValue = frac(fValue / vDecodeKey);

    // move back into [-1,1] range & normalize
    return (vDecodedValue * 2.0 - 1.0);
}


///////////////////////////////////////////////////////////////////////
//  CubicSmooth

float4 CubicSmooth(float4 vData)
{
    return vData * vData * (3.0 - 2.0 * vData);
}


///////////////////////////////////////////////////////////////////////
//  TriangleWave

float4 TriangleWave(float4 vData)
{
    return abs((frac(vData + 0.5) * 2.0) - 1.0);
}


///////////////////////////////////////////////////////////////////////
//  TrigApproximate

float4 TrigApproximate(float4 vData)
{
    return (CubicSmooth(TriangleWave(vData)) - 0.5) * 2.0;
}


///////////////////////////////////////////////////////////////////////
//  RotationMatrix
//
//  Constructs an arbitrary axis rotation matrix

float3x3 RotationMatrix(float3 vAxis, float fAngle)
{
    // compute sin/cos of fAngle
    float2 vSinCos;
    #ifdef OPENGL
        vSinCos.x = sin(fAngle);
        vSinCos.y = cos(fAngle);
    #else
        sincos(fAngle, vSinCos.x, vSinCos.y);
    #endif

    const float c = vSinCos.y;
    const float s = vSinCos.x;
    const float t = 1.0 - c;
    const float x = vAxis.x;
    const float y = vAxis.y;
    const float z = vAxis.z;

    return float3x3(t * x * x + c,      t * x * y - s * z,  t * x * z + s * y,
                    t * x * y + s * z,  t * y * y + c,      t * y * z - s * x,
                    t * x * z - s * y,  t * y * z + s * x,  t * z * z + c);
}


///////////////////////////////////////////////////////////////////////
//  mul_float3x3_float3x3

float3x3 mul_float3x3_float3x3(float3x3 mMatrixA, float3x3 mMatrixB)
{
    return mul(mMatrixA, mMatrixB);
}


///////////////////////////////////////////////////////////////////////
//  mul_float3x3_float3

float3 mul_float3x3_float3(float3x3 mMatrix, float3 vVector)
{
    return mul(mMatrix, vVector);
}


///////////////////////////////////////////////////////////////////////
//  cross()'s parameters are backwards in GLSL

#define wind_cross(a, b) cross((a), (b))

///////////////////////////////////////////////////////////////////////
//  Roll

float Roll(float fCurrent,
           float fMaxScale,
           float fMinScale,
           float fSpeed,
           float fRipple,
           float3 vPos,
           float fTime,
           float3 vRotatedWindVector)
{
    float fWindAngle = dot(vPos, -vRotatedWindVector) * fRipple;
    float fAdjust = TrigApproximate(float4(fWindAngle + fTime * fSpeed, 0.0, 0.0, 0.0)).x;
    fAdjust = (fAdjust + 1.0) * 0.5;

    return lerp(fCurrent * fMinScale, fCurrent * fMaxScale, fAdjust);
}


///////////////////////////////////////////////////////////////////////
//  Twitch

float Twitch(float3 vPos, float fAmount, float fSharpness, float fTime)
{
    const float c_fTwitchFudge = 0.87;
    float4 vOscillations = TrigApproximate(float4(fTime + (vPos.x + vPos.z), c_fTwitchFudge * fTime + vPos.y, 0.0, 0.0));

    //float fTwitch = sin(fFreq1 * fTime + (vPos.x + vPos.z)) * cos(fFreq2 * fTime + vPos.y);
    float fTwitch = vOscillations.x * vOscillations.y * vOscillations.y;
    fTwitch = (fTwitch + 1.0) * 0.5;

    return fAmount * pow(saturate(fTwitch), fSharpness);
}


///////////////////////////////////////////////////////////////////////
//  Oscillate
//
//  This function computes an oscillation value and whip value if necessary.
//  Whip and oscillation are combined like this to minimize calls to
//  TrigApproximate( ) when possible.

float Oscillate(float3 vPos,
                float fTime,
                float fOffset,
                float fWeight,
                float fWhip,
                bool bWhip,
                bool bRoll,
                bool bComplex,
                float fTwitch,
                float fTwitchFreqScale,
                inout float4 vOscillations,
                float3 vRotatedWindVector)
{
    float fOscillation = 1.0;
    if (bComplex)
    {
        if (bWhip)
            vOscillations = TrigApproximate(float4(fTime + fOffset, fTime * fTwitchFreqScale + fOffset, fTwitchFreqScale * 0.5 * (fTime + fOffset), fTime + fOffset + (1.0 - fWeight)));
        else
            vOscillations = TrigApproximate(float4(fTime + fOffset, fTime * fTwitchFreqScale + fOffset, fTwitchFreqScale * 0.5 * (fTime + fOffset), 0.0));

        float fFineDetail = vOscillations.x;
        float fBroadDetail = vOscillations.y * vOscillations.z;

        float fTarget = 1.0;
        float fAmount = fBroadDetail;
        if (fBroadDetail < 0.0)
        {
            fTarget = -fTarget;
            fAmount = -fAmount;
        }

        fBroadDetail = lerp(fBroadDetail, fTarget, fAmount);
        fBroadDetail = lerp(fBroadDetail, fTarget, fAmount);

        fOscillation = fBroadDetail * fTwitch * (1.0 - _ST_WindVector.w) + fFineDetail * (1.0 - fTwitch);

        if (bWhip)
            fOscillation *= 1.0 + (vOscillations.w * fWhip);
    }
    else
    {
        if (bWhip)
            vOscillations = TrigApproximate(float4(fTime + fOffset, fTime * 0.689 + fOffset, 0.0, fTime + fOffset + (1.0 - fWeight)));
        else
            vOscillations = TrigApproximate(float4(fTime + fOffset, fTime * 0.689 + fOffset, 0.0, 0.0));

        fOscillation = vOscillations.x + vOscillations.y * vOscillations.x;

        if (bWhip)
            fOscillation *= 1.0 + (vOscillations.w * fWhip);
    }

    //if (bRoll)
    //{
    //  fOscillation = Roll(fOscillation, _ST_WindRollingBranches.x, _ST_WindRollingBranches.y, _ST_WindRollingBranches.z, _ST_WindRollingBranches.w, vPos.xyz, fTime + fOffset, vRotatedWindVector);
    //}

    return fOscillation;
}


///////////////////////////////////////////////////////////////////////
//  Turbulence

float Turbulence(float fTime, float fOffset, float fGlobalTime, float fTurbulence)
{
    const float c_fTurbulenceFactor = 0.1;

    float4 vOscillations = TrigApproximate(float4(fTime * c_fTurbulenceFactor + fOffset, fGlobalTime * fTurbulence * c_fTurbulenceFactor + fOffset, 0.0, 0.0));

    return 1.0 - (vOscillations.x * vOscillations.y * vOscillations.x * vOscillations.y * fTurbulence);
}


///////////////////////////////////////////////////////////////////////
//  GlobalWind
//
//  This function positions any tree geometry based on their untransformed
//  position and 4 wind floats.

float3 GlobalWind(float3 vPos, float3 vInstancePos, bool bPreserveShape, float3 vRotatedWindVector, float time)
{
    // WIND_LOD_GLOBAL may be on, but if the global wind effect (WIND_EFFECT_GLOBAL_ST_Wind)
    // was disabled for the tree in the Modeler, we should skip it

    float fLength = 1.0;
    if (bPreserveShape)
        fLength = length(vPos.xyz);

    // compute how much the height contributes
    #ifdef SPEEDTREE_Z_UP
        float fAdjust = max(vPos.z - (1.0 / _ST_WindGlobal.z) * 0.25, 0.0) * _ST_WindGlobal.z;
    #else
        float fAdjust = max(vPos.y - (1.0 / _ST_WindGlobal.z) * 0.25, 0.0) * _ST_WindGlobal.z;
    #endif
    if (fAdjust != 0.0)
        fAdjust = pow(abs(fAdjust), _ST_WindGlobal.w);

    // primary oscillation
    float4 vOscillations = TrigApproximate(float4(vInstancePos.x + time, vInstancePos.y + time * 0.8, 0.0, 0.0));
    float fOsc = vOscillations.x + (vOscillations.y * vOscillations.y);
    float fMoveAmount = _ST_WindGlobal.y * fOsc;

    // move a minimum amount based on direction adherence
    fMoveAmount += _ST_WindBranchAdherences.x / _ST_WindGlobal.z;

    // adjust based on how high up the tree this vertex is
    fMoveAmount *= fAdjust;

    // xy component
    #ifdef SPEEDTREE_Z_UP
        vPos.xy += vRotatedWindVector.xy * fMoveAmount;
    #else
        vPos.xz += vRotatedWindVector.xz * fMoveAmount;
    #endif

    if (bPreserveShape)
        vPos.xyz = normalize(vPos.xyz) * fLength;

    return vPos;
}


///////////////////////////////////////////////////////////////////////
//  SimpleBranchWind

float3 SimpleBranchWind(float3 vPos,
                        float3 vInstancePos,
                        float fWeight,
                        float fOffset,
                        float fTime,
                        float fDistance,
                        float fTwitch,
                        float fTwitchScale,
                        float fWhip,
                        bool bWhip,
                        bool bRoll,
                        bool bComplex,
                        float3 vRotatedWindVector)
{
    // turn the offset back into a nearly normalized vector
    float3 vWindVector = UnpackNormalFromFloat(fOffset);
    vWindVector = vWindVector * fWeight;

    // try to fudge time a bit so that instances aren't in sync
    fTime += vInstancePos.x + vInstancePos.y;

    // oscillate
    float4 vOscillations;
    float fOsc = Oscillate(vPos, fTime, fOffset, fWeight, fWhip, bWhip, bRoll, bComplex, fTwitch, fTwitchScale, vOscillations, vRotatedWindVector);

    vPos.xyz += vWindVector * fOsc * fDistance;

    return vPos;
}


///////////////////////////////////////////////////////////////////////
//  DirectionalBranchWind

float3 DirectionalBranchWind(float3 vPos,
                             float3 vInstancePos,
                             float fWeight,
                             float fOffset,
                             float fTime,
                             float fDistance,
                             float fTurbulence,
                             float fAdherence,
                             float fTwitch,
                             float fTwitchScale,
                             float fWhip,
                             bool bWhip,
                             bool bRoll,
                             bool bComplex,
                             bool bTurbulence,
                             float3 vRotatedWindVector)
{
    // turn the offset back into a nearly normalized vector
    float3 vWindVector = UnpackNormalFromFloat(fOffset);
    vWindVector = vWindVector * fWeight;

    // try to fudge time a bit so that instances aren't in sync
    fTime += vInstancePos.x + vInstancePos.y;

    // oscillate
    float4 vOscillations;
    float fOsc = Oscillate(vPos, fTime, fOffset, fWeight, fWhip, bWhip, false, bComplex, fTwitch, fTwitchScale, vOscillations, vRotatedWindVector);

    vPos.xyz += vWindVector * fOsc * fDistance;

    // add in the direction, accounting for turbulence
    float fAdherenceScale = 1.0;
    if (bTurbulence)
        fAdherenceScale = Turbulence(fTime, fOffset, _ST_WindAnimation.x, fTurbulence);

    if (bWhip)
        fAdherenceScale += vOscillations.w * _ST_WindVector.w * fWhip;

    //if (bRoll)
    //  fAdherenceScale = Roll(fAdherenceScale, _ST_WindRollingBranches.x, _ST_WindRollingBranches.y, _ST_WindRollingBranches.z, _ST_WindRollingBranches.w, vPos.xyz, fTime + fOffset, vRotatedWindVector);

    vPos.xyz += vRotatedWindVector * fAdherence * fAdherenceScale * fWeight;

    return vPos;
}


///////////////////////////////////////////////////////////////////////
//  DirectionalBranchWindFrondStyle

float3 DirectionalBranchWindFrondStyle(float3 vPos,
                                       float3 vInstancePos,
                                       float fWeight,
                                       float fOffset,
                                       float fTime,
                                       float fDistance,
                                       float fTurbulence,
                                       float fAdherence,
                                       float fTwitch,
                                       float fTwitchScale,
                                       float fWhip,
                                       bool bWhip,
                                       bool bRoll,
                                       bool bComplex,
                                       bool bTurbulence,
                                       float3 vRotatedWindVector,
                                       float3 vRotatedBranchAnchor)
{
    // turn the offset back into a nearly normalized vector
    float3 vWindVector = UnpackNormalFromFloat(fOffset);
    vWindVector = vWindVector * fWeight;

    // try to fudge time a bit so that instances aren't in sync
    fTime += vInstancePos.x + vInstancePos.y;

    // oscillate
    float4 vOscillations;
    float fOsc = Oscillate(vPos, fTime, fOffset, fWeight, fWhip, bWhip, false, bComplex, fTwitch, fTwitchScale, vOscillations, vRotatedWindVector);

    vPos.xyz += vWindVector * fOsc * fDistance;

    // add in the direction, accounting for turbulence
    float fAdherenceScale = 1.0;
    if (bTurbulence)
        fAdherenceScale = Turbulence(fTime, fOffset, _ST_WindAnimation.x, fTurbulence);

    //if (bRoll)
    //  fAdherenceScale = Roll(fAdherenceScale, _ST_WindRollingBranches.x, _ST_WindRollingBranches.y, _ST_WindRollingBranches.z, _ST_WindRollingBranches.w, vPos.xyz, fTime + fOffset, vRotatedWindVector);

    if (bWhip)
        fAdherenceScale += vOscillations.w * _ST_WindVector.w * fWhip;

    float3 vWindAdherenceVector = vRotatedBranchAnchor - vPos.xyz;
    vPos.xyz += vWindAdherenceVector * fAdherence * fAdherenceScale * fWeight;

    return vPos;
}


///////////////////////////////////////////////////////////////////////
//  BranchWind

// Apply only to better, best, palm winds
float3 BranchWind(bool isPalmWind, float3 vPos, float3 vInstancePos, float4 vWindData, float3 vRotatedWindVector, float3 vRotatedBranchAnchor)
{
    if (isPalmWind)
    {
        vPos = DirectionalBranchWindFrondStyle(vPos, vInstancePos, vWindData.x, vWindData.y, _ST_WindBranch.x, _ST_WindBranch.y, _ST_WindTurbulences.x, _ST_WindBranchAdherences.y, _ST_WindBranchTwitch.x, _ST_WindBranchTwitch.y, _ST_WindBranchWhip.x, true, false, true, true, vRotatedWindVector, vRotatedBranchAnchor);
    }
    else
    {
        vPos = SimpleBranchWind(vPos, vInstancePos, vWindData.x, vWindData.y, _ST_WindBranch.x, _ST_WindBranch.y, _ST_WindBranchTwitch.x, _ST_WindBranchTwitch.y, _ST_WindBranchWhip.x, false, false, true, vRotatedWindVector);
    }

    return vPos;
}


///////////////////////////////////////////////////////////////////////
//  LeafRipple

float3 LeafRipple(float3 vPos,
                  inout float3 vDirection,
                  float fScale,
                  float fPackedRippleDir,
                  float fTime,
                  float fAmount,
                  bool bDirectional,
                  float fTrigOffset)
{
    // compute how much to move
    float4 vInput = float4(fTime + fTrigOffset, 0.0, 0.0, 0.0);
    float fMoveAmount = fAmount * TrigApproximate(vInput).x;

    if (bDirectional)
    {
        vPos.xyz += vDirection.xyz * fMoveAmount * fScale;
    }
    else
    {
        float3 vRippleDir = UnpackNormalFromFloat(fPackedRippleDir);
        vPos.xyz += vRippleDir * fMoveAmount * fScale;
    }

    return vPos;
}


///////////////////////////////////////////////////////////////////////
//  LeafTumble

float3 LeafTumble(float3 vPos,
                  inout float3 vDirection,
                  float fScale,
                  float3 vAnchor,
                  float3 vGrowthDir,
                  float fTrigOffset,
                  float fTime,
                  float fFlip,
                  float fTwist,
                  float fAdherence,
                  float3 vTwitch,
                  float4 vRoll,
                  bool bTwitch,
                  bool bRoll,
                  float3 vRotatedWindVector)
{
    // compute all oscillations up front
    float3 vFracs = frac((vAnchor + fTrigOffset) * 30.3);
    float fOffset = vFracs.x + vFracs.y + vFracs.z;
    float4 vOscillations = TrigApproximate(float4(fTime + fOffset, fTime * 0.75 - fOffset, fTime * 0.01 + fOffset, fTime * 1.0 + fOffset));

    // move to the origin and get the growth direction
    float3 vOriginPos = vPos.xyz - vAnchor;
    float fLength = length(vOriginPos);

    // twist
    float fOsc = vOscillations.x + vOscillations.y * vOscillations.y;
    float3x3 matTumble = RotationMatrix(vGrowthDir, fScale * fTwist * fOsc);

    // with wind
    float3 vAxis = wind_cross(vGrowthDir, vRotatedWindVector);
    float fDot = clamp(dot(vRotatedWindVector, vGrowthDir), -1.0, 1.0);
    #ifdef SPEEDTREE_Z_UP
        vAxis.z += fDot;
    #else
        vAxis.y += fDot;
    #endif
    vAxis = normalize(vAxis);

    float fAngle = acos(fDot);

    float fAdherenceScale = 1.0;
    //if (bRoll)
    //{
    //  fAdherenceScale = Roll(fAdherenceScale, vRoll.x, vRoll.y, vRoll.z, vRoll.w, vAnchor.xyz, fTime, vRotatedWindVector);
    //}

    fOsc = vOscillations.y - vOscillations.x * vOscillations.x;

    float fTwitch = 0.0;
    if (bTwitch)
        fTwitch = Twitch(vAnchor.xyz, vTwitch.x, vTwitch.y, vTwitch.z + fOffset);

    matTumble = mul_float3x3_float3x3(matTumble, RotationMatrix(vAxis, fScale * (fAngle * fAdherence * fAdherenceScale + fOsc * fFlip + fTwitch)));

    vDirection = mul_float3x3_float3(matTumble, vDirection);
    vOriginPos = mul_float3x3_float3(matTumble, vOriginPos);

    vOriginPos = normalize(vOriginPos) * fLength;

    return (vOriginPos + vAnchor);
}


///////////////////////////////////////////////////////////////////////
//  LeafWind
//  Optimized (for instruction count) version. Assumes leaf 1 and 2 have the same options

float3 LeafWind(bool isBestWind,
                bool bLeaf2,
                float3 vPos,
                inout float3 vDirection,
                float fScale,
                float3 vAnchor,
                float fPackedGrowthDir,
                float fPackedRippleDir,
                float fRippleTrigOffset,
                float3 vRotatedWindVector)
{

    vPos = LeafRipple(vPos, vDirection, fScale, fPackedRippleDir,
                            (bLeaf2 ? _ST_WindLeaf2Ripple.x : _ST_WindLeaf1Ripple.x),
                            (bLeaf2 ? _ST_WindLeaf2Ripple.y : _ST_WindLeaf1Ripple.y),
                            false, fRippleTrigOffset);

    if (isBestWind)
    {
        float3 vGrowthDir = UnpackNormalFromFloat(fPackedGrowthDir);
        vPos = LeafTumble(vPos, vDirection, fScale, vAnchor, vGrowthDir, fPackedGrowthDir,
                          (bLeaf2 ? _ST_WindLeaf2Tumble.x : _ST_WindLeaf1Tumble.x),
                          (bLeaf2 ? _ST_WindLeaf2Tumble.y : _ST_WindLeaf1Tumble.y),
                          (bLeaf2 ? _ST_WindLeaf2Tumble.z : _ST_WindLeaf1Tumble.z),
                          (bLeaf2 ? _ST_WindLeaf2Tumble.w : _ST_WindLeaf1Tumble.w),
                          (bLeaf2 ? _ST_WindLeaf2Twitch.xyz : _ST_WindLeaf1Twitch.xyz),
                          0.0f,
                          (bLeaf2 ? true : true),
                          (bLeaf2 ? true : true),
                          vRotatedWindVector);
    }

    return vPos;
}


///////////////////////////////////////////////////////////////////////
//  RippleFrondOneSided

float3 RippleFrondOneSided(float3 vPos,
                           inout float3 vDirection,
                           float fU,
                           float fV,
                           float fRippleScale
#ifdef WIND_EFFECT_FROND_RIPPLE_ADJUST_LIGHTING
                           , float3 vBinormal
                           , float3 vTangent
#endif
                           )
{
    float fOffset = 0.0;
    if (fU < 0.5)
        fOffset = 0.75;

    float4 vOscillations = TrigApproximate(float4((_ST_WindFrondRipple.x + fV) * _ST_WindFrondRipple.z + fOffset, 0.0, 0.0, 0.0));

    float fAmount = fRippleScale * vOscillations.x * _ST_WindFrondRipple.y;
    float3 vOffset = fAmount * vDirection;
    vPos.xyz += vOffset;

    #ifdef WIND_EFFECT_FROND_RIPPLE_ADJUST_LIGHTING
        vTangent.xyz = normalize(vTangent.xyz + vOffset * _ST_WindFrondRipple.w);
        float3 vNewNormal = normalize(wind_cross(vBinormal.xyz, vTangent.xyz));
        if (dot(vNewNormal, vDirection.xyz) < 0.0)
            vNewNormal = -vNewNormal;
        vDirection.xyz = vNewNormal;
    #endif

    return vPos;
}

///////////////////////////////////////////////////////////////////////
//  RippleFrondTwoSided

float3 RippleFrondTwoSided(float3 vPos,
                           inout float3 vDirection,
                           float fU,
                           float fLengthPercent,
                           float fPackedRippleDir,
                           float fRippleScale
#ifdef WIND_EFFECT_FROND_RIPPLE_ADJUST_LIGHTING
                           , float3 vBinormal
                           , float3 vTangent
#endif
                           )
{
    float4 vOscillations = TrigApproximate(float4(_ST_WindFrondRipple.x * fLengthPercent * _ST_WindFrondRipple.z, 0.0, 0.0, 0.0));

    float3 vRippleDir = UnpackNormalFromFloat(fPackedRippleDir);

    float fAmount = fRippleScale * vOscillations.x * _ST_WindFrondRipple.y;
    float3 vOffset = fAmount * vRippleDir;

    vPos.xyz += vOffset;

    #ifdef WIND_EFFECT_FROND_RIPPLE_ADJUST_LIGHTING
        vTangent.xyz = normalize(vTangent.xyz + vOffset * _ST_WindFrondRipple.w);
        float3 vNewNormal = normalize(wind_cross(vBinormal.xyz, vTangent.xyz));
        if (dot(vNewNormal, vDirection.xyz) < 0.0)
            vNewNormal = -vNewNormal;
        vDirection.xyz = vNewNormal;
    #endif

    return vPos;
}


///////////////////////////////////////////////////////////////////////
//  RippleFrond

float3 RippleFrond(float3 vPos,
                   inout float3 vDirection,
                   float fU,
                   float fV,
                   float fPackedRippleDir,
                   float fRippleScale,
                   float fLenghtPercent
                #ifdef WIND_EFFECT_FROND_RIPPLE_ADJUST_LIGHTING
                   , float3 vBinormal
                   , float3 vTangent
                #endif
                   )
{
    return RippleFrondOneSided(vPos,
                                vDirection,
                                fU,
                                fV,
                                fRippleScale
                            #ifdef WIND_EFFECT_FROND_RIPPLE_ADJUST_LIGHTING
                                , vBinormal
                                , vTangent
                            #endif
                                );
}

#endif // SPEEDTREE_8_WIND


#if SPEEDTREE_9_WIND
//
// DATA DEFINITIONS
//
struct WindBranchState // 8 floats | 32B
{
    float3 m_vNoisePosTurbulence;
    float m_fIndependence;
    float m_fBend;
    float m_fOscillation;
    float m_fTurbulence;
    float m_fFlexibility;
};
struct WindRippleState // 8 floats | 32B
{
    float3 m_vNoisePosTurbulence;
    float m_fIndependence;
    float m_fPlanar;
    float m_fDirectional;
    float m_fFlexibility;
    float m_fShimmer;
};
struct CBufferSpeedTree9 // 44 floats | 176B
{
    float3 m_vWindDirection;
    float  m_fWindStrength;

    float3 m_vTreeExtents;
    float  m_fSharedHeightStart;

    float m_fBranch1StretchLimit;
    float m_fBranch2StretchLimit;
    float m_fWindIndependence; 
    float pad1;

    WindBranchState m_sShared;
    WindBranchState m_sBranch1;
    WindBranchState m_sBranch2;
    WindRippleState m_sRipple;
};



//
// CONSTANT BUFFER
//
CBUFFER_START(SpeedTreeWind)
    float4 _ST_WindVector;
    float4 _ST_TreeExtents_SharedHeightStart;
    float4 _ST_BranchStretchLimits;
    float4 _ST_Shared_NoisePosTurbulence_Independence;
    float4 _ST_Shared_Bend_Oscillation_Turbulence_Flexibility;
    float4 _ST_Branch1_NoisePosTurbulence_Independence;
    float4 _ST_Branch1_Bend_Oscillation_Turbulence_Flexibility;
    float4 _ST_Branch2_NoisePosTurbulence_Independence;
    float4 _ST_Branch2_Bend_Oscillation_Turbulence_Flexibility;
    float4 _ST_Ripple_NoisePosTurbulence_Independence;
    float4 _ST_Ripple_Planar_Directional_Flexibility_Shimmer;

    float4 _ST_HistoryWindVector;
    float4 _ST_HistoryTreeExtents_SharedHeightStart;
    float4 _ST_HistoryBranchStretchLimits;
    float4 _ST_HistoryShared_NoisePosTurbulence_Independence;
    float4 _ST_HistoryShared_Bend_Oscillation_Turbulence_Flexibility;
    float4 _ST_HistoryBranch1_NoisePosTurbulence_Independence;
    float4 _ST_HistoryBranch1_Bend_Oscillation_Turbulence_Flexibility;
    float4 _ST_HistoryBranch2_NoisePosTurbulence_Independence;
    float4 _ST_HistoryBranch2_Bend_Oscillation_Turbulence_Flexibility;
    float4 _ST_HistoryRipple_NoisePosTurbulence_Independence;
    float4 _ST_HistoryRipple_Planar_Directional_Flexibility_Shimmer;
CBUFFER_END

CBufferSpeedTree9 ReadCBuffer(bool bHistory /*must be known compile-time*/)
{
    CBufferSpeedTree9 cb;
    cb.m_vWindDirection                 = bHistory ? _ST_HistoryWindVector.xyz                    : _ST_WindVector.xyz;
    cb.m_fWindStrength                  = bHistory ? _ST_HistoryWindVector.w                      : _ST_WindVector.w;
    cb.m_vTreeExtents                   = bHistory ? _ST_HistoryTreeExtents_SharedHeightStart.xyz : _ST_TreeExtents_SharedHeightStart.xyz;
    cb.m_fSharedHeightStart             = bHistory ? _ST_HistoryTreeExtents_SharedHeightStart.w   : _ST_TreeExtents_SharedHeightStart.w;
    cb.m_fBranch1StretchLimit           = bHistory ? _ST_HistoryBranchStretchLimits.x             : _ST_BranchStretchLimits.x;
    cb.m_fBranch2StretchLimit           = bHistory ? _ST_HistoryBranchStretchLimits.y             : _ST_BranchStretchLimits.y;
    cb.m_fWindIndependence              = bHistory ? _ST_HistoryBranchStretchLimits.z             : _ST_BranchStretchLimits.z;

    // Shared Wind State
    cb.m_sShared.m_vNoisePosTurbulence  = bHistory ? _ST_HistoryShared_NoisePosTurbulence_Independence.xyz       : _ST_Shared_NoisePosTurbulence_Independence.xyz;
    cb.m_sShared.m_fIndependence        = bHistory ? _ST_HistoryShared_NoisePosTurbulence_Independence.w         : _ST_Shared_NoisePosTurbulence_Independence.w;
    cb.m_sShared.m_fBend                = bHistory ? _ST_HistoryShared_Bend_Oscillation_Turbulence_Flexibility.x : _ST_Shared_Bend_Oscillation_Turbulence_Flexibility.x;
    cb.m_sShared.m_fOscillation         = bHistory ? _ST_HistoryShared_Bend_Oscillation_Turbulence_Flexibility.y : _ST_Shared_Bend_Oscillation_Turbulence_Flexibility.y;
    cb.m_sShared.m_fTurbulence          = bHistory ? _ST_HistoryShared_Bend_Oscillation_Turbulence_Flexibility.z : _ST_Shared_Bend_Oscillation_Turbulence_Flexibility.z;
    cb.m_sShared.m_fFlexibility         = bHistory ? _ST_HistoryShared_Bend_Oscillation_Turbulence_Flexibility.w : _ST_Shared_Bend_Oscillation_Turbulence_Flexibility.w;

    // Branch1 Wind State
    cb.m_sBranch1.m_vNoisePosTurbulence  = bHistory ? _ST_HistoryBranch1_NoisePosTurbulence_Independence.xyz       : _ST_Branch1_NoisePosTurbulence_Independence.xyz;
    cb.m_sBranch1.m_fIndependence        = bHistory ? _ST_HistoryBranch1_NoisePosTurbulence_Independence.w         : _ST_Branch1_NoisePosTurbulence_Independence.w;
    cb.m_sBranch1.m_fBend                = bHistory ? _ST_HistoryBranch1_Bend_Oscillation_Turbulence_Flexibility.x : _ST_Branch1_Bend_Oscillation_Turbulence_Flexibility.x;
    cb.m_sBranch1.m_fOscillation         = bHistory ? _ST_HistoryBranch1_Bend_Oscillation_Turbulence_Flexibility.y : _ST_Branch1_Bend_Oscillation_Turbulence_Flexibility.y;
    cb.m_sBranch1.m_fTurbulence          = bHistory ? _ST_HistoryBranch1_Bend_Oscillation_Turbulence_Flexibility.z : _ST_Branch1_Bend_Oscillation_Turbulence_Flexibility.z;
    cb.m_sBranch1.m_fFlexibility         = bHistory ? _ST_HistoryBranch1_Bend_Oscillation_Turbulence_Flexibility.w : _ST_Branch1_Bend_Oscillation_Turbulence_Flexibility.w;

    // Branch2 Wind State
    cb.m_sBranch2.m_vNoisePosTurbulence  = bHistory ? _ST_HistoryBranch2_NoisePosTurbulence_Independence.xyz       : _ST_Branch2_NoisePosTurbulence_Independence.xyz;
    cb.m_sBranch2.m_fIndependence        = bHistory ? _ST_HistoryBranch2_NoisePosTurbulence_Independence.w         : _ST_Branch2_NoisePosTurbulence_Independence.w;
    cb.m_sBranch2.m_fBend                = bHistory ? _ST_HistoryBranch2_Bend_Oscillation_Turbulence_Flexibility.x : _ST_Branch2_Bend_Oscillation_Turbulence_Flexibility.x;
    cb.m_sBranch2.m_fOscillation         = bHistory ? _ST_HistoryBranch2_Bend_Oscillation_Turbulence_Flexibility.y : _ST_Branch2_Bend_Oscillation_Turbulence_Flexibility.y;
    cb.m_sBranch2.m_fTurbulence          = bHistory ? _ST_HistoryBranch2_Bend_Oscillation_Turbulence_Flexibility.z : _ST_Branch2_Bend_Oscillation_Turbulence_Flexibility.z;
    cb.m_sBranch2.m_fFlexibility         = bHistory ? _ST_HistoryBranch2_Bend_Oscillation_Turbulence_Flexibility.w : _ST_Branch2_Bend_Oscillation_Turbulence_Flexibility.w;

    // Ripple Wind State
    cb.m_sRipple.m_vNoisePosTurbulence   = bHistory ? _ST_HistoryRipple_NoisePosTurbulence_Independence.xyz      : _ST_Ripple_NoisePosTurbulence_Independence.xyz;
    cb.m_sRipple.m_fIndependence         = bHistory ? _ST_HistoryRipple_NoisePosTurbulence_Independence.w        : _ST_Ripple_NoisePosTurbulence_Independence.w;
    cb.m_sRipple.m_fPlanar               = bHistory ? _ST_HistoryRipple_Planar_Directional_Flexibility_Shimmer.x : _ST_Ripple_Planar_Directional_Flexibility_Shimmer.x;
    cb.m_sRipple.m_fDirectional          = bHistory ? _ST_HistoryRipple_Planar_Directional_Flexibility_Shimmer.y : _ST_Ripple_Planar_Directional_Flexibility_Shimmer.y;
    cb.m_sRipple.m_fFlexibility          = bHistory ? _ST_HistoryRipple_Planar_Directional_Flexibility_Shimmer.z : _ST_Ripple_Planar_Directional_Flexibility_Shimmer.z;
    cb.m_sRipple.m_fShimmer              = bHistory ? _ST_HistoryRipple_Planar_Directional_Flexibility_Shimmer.w : _ST_Ripple_Planar_Directional_Flexibility_Shimmer.w;

    // transformations : all wind vectors are in local space
    cb.m_vWindDirection  = mul((float3x3) unity_WorldToObject, cb.m_vWindDirection); 
    return cb;
}


//
// UTILS
//
float NoiseHash(float n) { return frac(sin(n) * 1e4); }
float NoiseHash(float2 p){ return frac(1e4 * sin(17.0f * p.x + p.y * 0.1f) * (0.1f + abs(sin(p.y * 13.0f + p.x)))); }
float QNoise(float2 x)
{
    float2 i = floor(x);
    float2 f = frac(x);
    
    // four corners in 2D of a tile
    float a = NoiseHash(i);
    float b = NoiseHash(i + float2(1.0, 0.0));
    float c = NoiseHash(i + float2(0.0, 1.0));
    float d = NoiseHash(i + float2(1.0, 1.0));
    
    // same code, with the clamps in smoothstep and common subexpressions optimized away.
    float2 u = f * f * (float2(3.0, 3.0) - float2(2.0, 2.0) * f);
    
    return lerp(a, b, u.x) + (c - a) * u.y * (1.0f - u.x) + (d - b) * u.x * u.y;
}
float4 RuntimeSdkNoise2DFlat(float3 vNoisePos3d)
{
	float2 vNoisePos = vNoisePos3d.xz;

#ifdef USE_ST_NOISE_TEXTURE // test this toggle during shader perf tuning
    return texture2D(g_samNoiseKernel, vNoisePos.xy) - float4(0.5f, 0.5f, 0.5f, 0.5f);
#else
    const float c_fFrequecyScale = 20.0f;
    const float c_fAmplitudeScale = 1.0f;
    const float	c_fAmplitueShift = 0.0f;

    float fNoiseX = (QNoise(vNoisePos * c_fFrequecyScale) + c_fAmplitueShift) * c_fAmplitudeScale - 0.5f;
    float fNoiseY = (QNoise(vNoisePos.yx * 0.5f * c_fFrequecyScale) + c_fAmplitueShift) * c_fAmplitudeScale;
    return float4(fNoiseX, fNoiseY, 0.0f, 0.0f);
#endif
}
float  WindUtil_Square(float  fValue) { return fValue * fValue; }
float2 WindUtil_Square(float2 fValue) { return fValue * fValue; }
float3 WindUtil_Square(float3 fValue) { return fValue * fValue; }
float4 WindUtil_Square(float4 fValue) { return fValue * fValue; }

float3 WindUtil_UnpackNormalizedFloat(float fValue)
{
    float3 vReturn = frac(float3(fValue * 0.01f, fValue, fValue * 100.0f));

    vReturn -= 0.5f;
    vReturn *= 2.0f;

    return normalize(vReturn);
}


//
// SPEEDTREE WIND 9
//

// returns position offset (caller must apply to the vertex position)
float3 RippleWindMotion(
    float3 vUpVector,
    float3 vWindDirection,
    float3 vVertexPositionIn,
    float3 vGlobalNoisePosition,

    float  fRippleWeight,
    float3 vRippleNoisePosTurbulence,
    float  fRippleIndependence,
    float  fRippleFlexibility,
    float  fRippleDirectional,
    float  fRipplePlanar
)
{
    float3 vNoisePosition = vGlobalNoisePosition + vRippleNoisePosTurbulence + vVertexPositionIn * fRippleIndependence;
    vNoisePosition += vWindDirection * (fRippleFlexibility * fRippleWeight);
    
    float4 vNoise = RuntimeSdkNoise2DFlat(vNoisePosition);

    float fRippleFactor = (vNoise.r + 0.25f) * fRippleDirectional;
    float3 vMotion = vWindDirection * fRippleFactor + vUpVector * (vNoise.g * fRipplePlanar);
    vMotion *= fRippleWeight;
    
    return vMotion;
}

// returns updated position
float3 BranchWindPosition(
    float3 vUp,
    float3 vWindDirection,
    float3 vVertexPositionIn,
    float3 vGlobalNoisePosition,

    float  fPackedBranchDir,
    float  fPackedBranchNoiseOffset,
    float  fBranchWeight,
    float  fBranchStretchLimit,
    float3 vBranchNoisePosTurbulence,
    float  fBranchIndependence,
    float  fBranchTurbulence,
    float  fBranchOscillation,
    float  fBranchBend,
    float  fBranchFlexibility
)
{
    float fLength = fBranchWeight * fBranchStretchLimit;
    if (fLength == 0.0f)
    {
        return vVertexPositionIn;
    }

    float3 vBranchDir = WindUtil_UnpackNormalizedFloat(fPackedBranchDir);
    float3 vBranchNoiseOffset = WindUtil_UnpackNormalizedFloat(fPackedBranchNoiseOffset);
    float3 vAnchor = vVertexPositionIn - vBranchDir * fLength;
    vVertexPositionIn -= vAnchor;

    float3 vWind = normalize(vWindDirection + vUp * WindUtil_Square(dot(vBranchDir, vWindDirection)));

    float3 vNoisePosition = vGlobalNoisePosition + vBranchNoisePosTurbulence + vBranchNoiseOffset * fBranchIndependence;
    vNoisePosition += vWind * (fBranchFlexibility * fBranchWeight);
    float4 vNoise = RuntimeSdkNoise2DFlat(vNoisePosition);

    float3 vOscillationTurbulent = cross(vWind, vBranchDir) * fBranchTurbulence;
    float3 vMotion = (vWind * vNoise.r + vOscillationTurbulent * vNoise.g) * fBranchOscillation;
    vMotion += vWind * (fBranchBend * (1.0f - vNoise.b));
    vMotion *= fBranchWeight;

    return normalize(vVertexPositionIn + vMotion) * fLength + vAnchor;
}

// returns updated position
float3 SharedWindPosition(
    float3 vUp,
    float3 vWindDirection,
    float3 vVertexPositionIn,
    float3 vGlobalNoisePosition,

    float  fTreeHeight,
    float  fSharedHeightStart,
    float3 vSharedNoisePosTurbulence,
    float  fSharedTurbulence,
    float  fSharedOscillation,
    float  fSharedBend,
    float  fSharedFlexibility
)
{
    float fLengthSq = dot(vVertexPositionIn, vVertexPositionIn);
    if (fLengthSq == 0.0f)
    {
        return vVertexPositionIn;
    }
    float fLength = sqrt(fLengthSq);

    float fHeight = vVertexPositionIn.y;
    float fMaxHeight = fTreeHeight;

    float fWeight = WindUtil_Square(max(fHeight - (fMaxHeight * fSharedHeightStart), 0.0f) / fMaxHeight);

    float3 vNoisePosition = vGlobalNoisePosition + vSharedNoisePosTurbulence;
    vNoisePosition += vWindDirection * (fSharedFlexibility * fWeight);
    float4 vNoise = RuntimeSdkNoise2DFlat(vNoisePosition);
    
    float3 vOscillationTurbulent = cross(vWindDirection, vUp) * fSharedTurbulence;
    float3 vMotion = (vWindDirection * vNoise.r + vOscillationTurbulent * vNoise.g) * fSharedOscillation;
    vMotion += vWindDirection * (fSharedBend * (1.0f - vNoise.b));
    vMotion *= fWeight;

    return normalize(vVertexPositionIn + vMotion) * fLength;
}



//
// CBUFFER UNPACKING
//
// structured parameter input stubs
// *Wind*()    : float / float2/3/4 inputs, meat of animation logic (above)
// *Wind*_cb() : unpacks the cb struct
// *Wind*_s()  : unpacks the structs within the cb
float3 RippleWindMotion_s(
    float3 vUpVector,
    float3 vWindDirection,
    float3 vVertexPositionIn,
    float3 vGlobalNoisePosition,

    float fRippleWeight,
    in WindRippleState sRipple
)
{
    return RippleWindMotion(
        vUpVector,
        vWindDirection,
        vVertexPositionIn,
        vGlobalNoisePosition,
        fRippleWeight,
        sRipple.m_vNoisePosTurbulence,
        sRipple.m_fIndependence,
        sRipple.m_fFlexibility,
        sRipple.m_fDirectional,
        sRipple.m_fPlanar
    );
}


float3 BranchWindPosition_s(
    float3 vUp,
    float3 vWindDirection,
    float3 vVertexPositionIn,
    float3 vGlobalNoisePosition,

    float fBranch2Weight,
    float fBranch2StretchLimit,
    float fPackedBranch2Dir,
    float fPackedBranch2NoiseOffset,
    in WindBranchState sBranch
)
{
    return BranchWindPosition(
        vUp,
        vWindDirection,
        vVertexPositionIn,
        vGlobalNoisePosition,
        fPackedBranch2Dir,
        fPackedBranch2NoiseOffset,
        fBranch2Weight,
        fBranch2StretchLimit,
        sBranch.m_vNoisePosTurbulence,
        sBranch.m_fIndependence,
        sBranch.m_fTurbulence,
        sBranch.m_fOscillation,
        sBranch.m_fBend,
        sBranch.m_fFlexibility
    );
}

float3 SharedWindPosition_s(
    float3 vUp,
    float3 vWindDirection,
    float3 vVertexPositionIn,
    float3 vGlobalNoisePosition,

    float fTreeHeight,
    float fSharedHeightStart,
    in WindBranchState sShared
)
{
    return SharedWindPosition(
        vUp,
        vWindDirection,
        vVertexPositionIn,
        vGlobalNoisePosition,
        fTreeHeight,
        fSharedHeightStart,
        sShared.m_vNoisePosTurbulence,
        sShared.m_fTurbulence,
        sShared.m_fOscillation,
        sShared.m_fBend,
        sShared.m_fFlexibility
    );
}


// ------------------------------
float3 RippleWindMotion_cb(
    float3 vUpVector,
    float3 vVertexPositionIn,
    float3 vGlobalNoisePosition,

    float fRippleWeight,
    in CBufferSpeedTree9 cb
)
{
    return RippleWindMotion_s(
        vUpVector,
        cb.m_vWindDirection,
        vVertexPositionIn,
        vGlobalNoisePosition,
        fRippleWeight,
        cb.m_sRipple
    );
}


float3 BranchWindPosition_cb(
    float3 vUp,
    float3 vGlobalNoisePosition,
    float3 vVertexPositionIn,

    float fBranchWeight,
    float fPackedBranchDir,
    float fPackedBranchNoiseOffset,
    in CBufferSpeedTree9 cb,
    int iBranch // 1 or 2
)
{
    if(iBranch == 1)
    {
        return BranchWindPosition_s(
            vUp,
            cb.m_vWindDirection,
            vVertexPositionIn,
            vGlobalNoisePosition,
    
            fBranchWeight,
            cb.m_fBranch1StretchLimit,
            fPackedBranchDir,
            fPackedBranchNoiseOffset,
            cb.m_sBranch1
        );
    }
    
    return BranchWindPosition_s(
        vUp,
        cb.m_vWindDirection,
        vVertexPositionIn,
        vGlobalNoisePosition,
    
        fBranchWeight,
        cb.m_fBranch2StretchLimit,
        fPackedBranchDir,
        fPackedBranchNoiseOffset,
        cb.m_sBranch2
    );
}


float3 SharedWindPosition_cb(
    float3 vUp,
    float3 vVertexPositionIn,
    float3 vGlobalNoisePosition,

    in CBufferSpeedTree9 cb
)
{
    return SharedWindPosition_s(
        vUp,
        cb.m_vWindDirection,
        vVertexPositionIn,
        vGlobalNoisePosition,
        cb.m_vTreeExtents.y, // y-up = height
        cb.m_fSharedHeightStart,
        cb.m_sShared
    );
}

#endif // SPEEDTREE_9_WIND

#endif // SPEEDTREE_WIND_INCLUDED
