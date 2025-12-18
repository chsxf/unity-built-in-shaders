// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_UIE_FILTER_INCLUDED
#define UNITY_UIE_FILTER_INCLUDED

uniform float4 unity_uie_UVRect[1];

struct FilterVertexInput
{
    float4 vertex : POSITION;
    float2 uv : TEXCOORD0;
    half2 rectIndex : TEXCOORD1;
};

uint GetFilterRectIndex(FilterVertexInput v)
{
    return (uint)(v.rectIndex.x + 0.5f);
}

float4 GetFilterUVRect(uint index)
{
    return unity_uie_UVRect[index];
}

#endif // UNITY_UIE_FILTER_INCLUDED
