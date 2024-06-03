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

void DoLeafFacing(in float3 vVertexLocalPos, float3 vAnchorPosition)
{
    float3 vAnchorDisplacement = vAnchorPosition;
    
    vVertexLocalPos -= vAnchorDisplacement;
    
    float offsetLen = length(vVertexLocalPos);
    vVertexLocalPos = float3(vVertexLocalPos.x, -vVertexLocalPos.z, vVertexLocalPos.y);
    float4x4 itmv = transpose(mul(unity_WorldToObject, unity_MatrixInvV));
    vVertexLocalPos = mul(vVertexLocalPos.xyz, (float3x3) itmv);
    vVertexLocalPos = normalize(vVertexLocalPos) * offsetLen; // make sure the offset vector is still scaled
    
    vVertexLocalPos += vAnchorDisplacement;
}

#endif // SPEEDTREE_LIBRARY_INCLUDED
