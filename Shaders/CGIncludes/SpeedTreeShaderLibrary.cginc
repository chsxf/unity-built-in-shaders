// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

///////////////////////////////////////////////////////////////////////
//  SpeedTreeLibrary.cginc

#ifndef SPEEDTREE_LIBRARY_INCLUDED
#define SPEEDTREE_LIBRARY_INCLUDED

#include "UnityCG.cginc"

void BillboardSeamCrossfade(inout appdata_full v, float3 treePos)
{
    // crossfade faces
    bool topDown = (v.texcoord.z > 0.5);
    float3 viewDir = UNITY_MATRIX_IT_MV[2].xyz;
    float3 cameraDir = normalize(mul((float3x3) unity_WorldToObject, _WorldSpaceCameraPos - treePos));
    float viewDot = max(dot(viewDir, v.normal), dot(cameraDir, v.normal));
    viewDot *= viewDot;
    viewDot *= viewDot;
    viewDot += topDown ? 0.38 : 0.18; // different scales for horz and vert billboards to fix transition zone
    v.color = float4(1, 1, 1, clamp(viewDot, 0, 1));

    // if invisible, avoid overdraw
    if (viewDot < 0.3333)
    {
        v.vertex.xyz = float3(0, 0, 0);
    }

    // adjust lighting on billboards to prevent seams between the different faces
    if (topDown)
    {
        v.normal += cameraDir;
    }
    else
    {
        half3 binormal = cross(v.normal, v.tangent.xyz) * v.tangent.w;
        float3 right = cross(cameraDir, binormal);
        v.normal = cross(binormal, right);
    }
    v.normal = normalize(v.normal);
}

float3 DoLeafFacing(float3 vPos, float3 anchor)
{
    float3 facingPosition = vPos - anchor; // move to origin
    float offsetLen = length(facingPosition);

    // rotate X -90deg: normals keep looking 'up' while cards/leaves now 'stand up' and face the view plane
    facingPosition = float3(facingPosition.x, -facingPosition.z, facingPosition.y);

    // extract scale from model matrix
    float3 scale = float3(
        length(float3(UNITY_MATRIX_M[0][0], UNITY_MATRIX_M[1][0], UNITY_MATRIX_M[2][0])),
        length(float3(UNITY_MATRIX_M[0][1], UNITY_MATRIX_M[1][1], UNITY_MATRIX_M[2][1])),
        length(float3(UNITY_MATRIX_M[0][2], UNITY_MATRIX_M[1][2], UNITY_MATRIX_M[2][2]))
    );
    
    // inverse of model : discards object rotations & scale
    // inverse of view  : discards camera rotations
    float3x3 matCardFacingTransform = mul((float3x3)unity_WorldToObject, (float3x3) UNITY_MATRIX_I_V);
    
    // re-encode the scale into the final transformation (otherwise cards would look small if tree is scaled up via world transform)
    matCardFacingTransform[0] *= scale.x;
    matCardFacingTransform[1] *= scale.y;
    matCardFacingTransform[2] *= scale.z;

    // make the leaves/cards face the camera
    facingPosition = mul(matCardFacingTransform, facingPosition.xyz);
    facingPosition = normalize(facingPosition) * offsetLen; // make sure the offset vector is still scaled
    
    return facingPosition + anchor; // move back to branch
}


#define SPEEDTREE_SUPPORT_NON_UNIFORM_SCALING 0
float3 TransformWindVectorFromWorldToLocalSpace(float3 vWindDirection)
{
    // we intend to transform the world-space wind vector into local space.
#if SPEEDTREE_SUPPORT_NON_UNIFORM_SCALING 
    // the inverse world matrix would contain scale transformation as well, so we need
    // to get rid of scaling of the wind direction while doing inverse rotation.
    float3 scaleInv = float3(
        length(float3(UNITY_MATRIX_M[0][0], UNITY_MATRIX_M[1][0], UNITY_MATRIX_M[2][0])),
        length(float3(UNITY_MATRIX_M[0][1], UNITY_MATRIX_M[1][1], UNITY_MATRIX_M[2][1])),
        length(float3(UNITY_MATRIX_M[0][2], UNITY_MATRIX_M[1][2], UNITY_MATRIX_M[2][2]))
    );
    float3x3 matWorldToLocalSpaceRotation = float3x3( // 3x3 discards translation
        UNITY_MATRIX_I_M[0][0] * scaleInv.x, UNITY_MATRIX_I_M[0][1]             , UNITY_MATRIX_I_M[0][2],
        UNITY_MATRIX_I_M[1][0]             , UNITY_MATRIX_I_M[1][1] * scaleInv.y, UNITY_MATRIX_I_M[1][2],
        UNITY_MATRIX_I_M[2][0]             , UNITY_MATRIX_I_M[2][1]             , UNITY_MATRIX_I_M[2][2] * scaleInv.z
    );
    float3 vLocalSpaceWind = mul(matWorldToLocalSpaceRotation, vWindDirection);
#else
    // Assume uniform scaling for the object -- discard translation and invert object rotations (and scale).
    // We'll normalize to get rid of scaling after the transformation.
    // - mul((float3x3) UNITY_MATRIX_I_M, vWindDirection)   <-- UNITY_MATRIX_I_M not defined
    // - mul(vWindDirection, (float3x3) UNITY_MATRIX_M  )   <-- UNITY_MATRIX_M can be used, which is the transpose of UNITY_MATRIX_I_M ignoring scaling and translate
    float3 vLocalSpaceWind = mul(vWindDirection, (float3x3) UNITY_MATRIX_M);
#endif
    float windVecLength = length(vLocalSpaceWind);
    if (windVecLength > 1e-5)
        vLocalSpaceWind *= (1.0f / windVecLength); // normalize
    return vLocalSpaceWind;
}
#endif // SPEEDTREE_LIBRARY_INCLUDED
