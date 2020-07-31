// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifndef UNITY_RAY_TRACING_MESH_UTILS_INCLUDED
#define UNITY_RAY_TRACING_MESH_UTILS_INCLUDED

// This helper file contains a list of utility functions needed to fetch vertex attributes from within closesthit or anyhit shaders.

// HLSL example:
// struct Vertex
// {
//     float3 position;
//     float2 texcoord;
// };

// Vertex FetchVertex(uint vertexIndex)
// {
//      Vertex v;
//      v.position = UnityRayTracingFetchVertexAttribute3(vertexIndex, kVertexAttributePosition);
//      v.texcoord = UnityRayTracingFetchVertexAttribute2(vertexIndex, kVertexAttributeTexCoord0);
//      return v;
// }

// uint3 triangleIndices = UnityRayTracingFetchTriangleIndices(PrimitiveIndex());
// Vertex v0, v1, v2;
// v0 = FetchVertex(triangleIndices.x);
// v1 = FetchVertex(triangleIndices.y);
// v2 = FetchVertex(triangleIndices.z);
// Interpolate the vertices using the barycentric coordinates available as input to the closesthit or anyhit shaders.

#define kMaxVertexStreams 8

struct MeshInfo
{
    uint vertexSize[kMaxVertexStreams];                 // The stride between 2 consecutive vertices in the vertex buffer. There is an entry for each vertex stream.
    uint baseVertex;                                    // A value added to each index before reading a vertex from the vertex buffer.
    uint vertexStart;
    uint indexSize;                                     // 0 when an index buffer is not used, 2 for 16-bit indices or 4 for 32-bit indices.
    uint indexStart;                                    // The location of the first index to read from the index buffer.
};

struct VertexAttributeInfo
{
    uint Stream;                                        // The stream index used to fetch the vertex attribute. There can be up to kMaxVertexStreams streams.
    uint Format;                                        // One of the kVertexFormat* values from bellow.
    uint ByteOffset;                                    // The attribute offset in bytes into the vertex structure.
    uint Dimension;                                     // The dimension (#channels) of the vertex attribute.
};

// Valid values for the attributeType parameter in UnityRayTracingFetchVertexAttribute* functions.
#define kVertexAttributePosition    0
#define kVertexAttributeNormal      1
#define kVertexAttributeTangent     2
#define kVertexAttributeColor       3
#define kVertexAttributeTexCoord0   4
#define kVertexAttributeTexCoord1   5
#define kVertexAttributeTexCoord2   6
#define kVertexAttributeTexCoord3   7
#define kVertexAttributeTexCoord4   8
#define kVertexAttributeTexCoord5   9
#define kVertexAttributeTexCoord6   10
#define kVertexAttributeTexCoord7   11

// Supported
#define kVertexFormatFloat          0
#define kVertexFormatFloat16        1
#define kVertexFormatUNorm8         2
// Not supported
#define kVertexFormatSNorm8         3
#define kVertexFormatUNorm16        4
#define kVertexFormatSNorm16        5
#define kVertexFormatUInt8          6
#define kVertexFormatSInt8          7
#define kVertexFormatUInt16         8
#define kVertexFormatSInt16         9
#define kVertexFormatUInt32         10
#define kVertexFormatSInt32         11

StructuredBuffer<MeshInfo>              unity_MeshInfo_RT;
StructuredBuffer<VertexAttributeInfo>   unity_MeshVertexDeclaration_RT;

ByteAddressBuffer unity_MeshVertexBuffers_RT[kMaxVertexStreams];
ByteAddressBuffer unity_MeshIndexBuffer_RT;

uint3 UnityRayTracingFetchTriangleIndices(uint primitiveIndex)
{
    uint3 indices;

    MeshInfo meshInfo = unity_MeshInfo_RT[0];

    if (meshInfo.indexSize == 2)
    {
        const uint offsetInBytes = (meshInfo.indexStart + primitiveIndex * 3) << 1;
        const uint dwordAlignedOffset = offsetInBytes & ~3;
        const uint2 fourIndices = unity_MeshIndexBuffer_RT.Load2(dwordAlignedOffset);

        if (dwordAlignedOffset == offsetInBytes)
        {
            indices.x = fourIndices.x & 0xffff;
            indices.y = (fourIndices.x >> 16) & 0xffff;
            indices.z = fourIndices.y & 0xffff;
        }
        else
        {
            indices.x = (fourIndices.x >> 16) & 0xffff;
            indices.y = fourIndices.y & 0xffff;
            indices.z = (fourIndices.y >> 16) & 0xffff;
        }

        indices = indices + meshInfo.baseVertex.xxx;
    }
    else if (meshInfo.indexSize == 4)
    {
        const uint offsetInBytes = (meshInfo.indexStart + primitiveIndex * 3) << 2;
        indices = unity_MeshIndexBuffer_RT.Load3(offsetInBytes) + meshInfo.baseVertex.xxx;
    }
    else // meshInfo.indexSize == 0
    {
        const uint firstVertexIndex = primitiveIndex * 3 + meshInfo.vertexStart;
        indices = firstVertexIndex.xxx + uint3(0, 1, 2);
    }

    return indices;
}

#define INVALID_VERTEX_ATTRIBUTE_OFFSET 0xFFFFFFFF

// attributeType is one of the kVertexAttribute* defines
float2 UnityRayTracingFetchVertexAttribute2(uint vertexIndex, uint attributeType)
{
    VertexAttributeInfo vertexDecl = unity_MeshVertexDeclaration_RT[attributeType];

    const uint attributeByteOffset  = vertexDecl.ByteOffset;
    const uint attributeDimension   = vertexDecl.Dimension;

    if (attributeByteOffset == INVALID_VERTEX_ATTRIBUTE_OFFSET || attributeDimension < 2)
        return float2(0, 0);

    const uint vertexSize       = unity_MeshInfo_RT[0].vertexSize[vertexDecl.Stream];
    const uint vertexAddress    = vertexIndex * vertexSize;
    const uint attributeAddress = vertexAddress + attributeByteOffset;
    const uint attributeFormat  = vertexDecl.Format;

    if (attributeFormat == kVertexFormatFloat)
    {
        return asfloat(unity_MeshVertexBuffers_RT[vertexDecl.Stream].Load2(attributeAddress));
    }
    else if (attributeFormat == kVertexFormatFloat16)
    {
        const uint twoHalfs = unity_MeshVertexBuffers_RT[vertexDecl.Stream].Load(attributeAddress);
        return float2(f16tof32(twoHalfs), f16tof32(twoHalfs >> 16));
    }
    else
        // Vertex attribute format not supported.
        return float2(0, 0);
}

// attributeType is one of the kVertexAttribute* defines
float3 UnityRayTracingFetchVertexAttribute3(uint vertexIndex, uint attributeType)
{
    VertexAttributeInfo vertexDecl = unity_MeshVertexDeclaration_RT[attributeType];

    const uint attributeByteOffset = vertexDecl.ByteOffset;
    const uint attributeDimension = vertexDecl.Dimension;

    if (attributeByteOffset == INVALID_VERTEX_ATTRIBUTE_OFFSET || attributeDimension < 3)
        return float3(0, 0, 0);

    const uint vertexSize       = unity_MeshInfo_RT[0].vertexSize[vertexDecl.Stream];
    const uint vertexAddress    = vertexIndex * vertexSize;
    const uint attributeAddress = vertexAddress + attributeByteOffset;
    const uint attributeFormat  = vertexDecl.Format;

    if (attributeFormat == kVertexFormatFloat)
    {
        return asfloat(unity_MeshVertexBuffers_RT[vertexDecl.Stream].Load3(attributeAddress));
    }
    else if (attributeFormat == kVertexFormatFloat16)
    {
        const uint2 fourHalfs = unity_MeshVertexBuffers_RT[vertexDecl.Stream].Load2(attributeAddress);
        return float3(f16tof32(fourHalfs.x), f16tof32(fourHalfs.x >> 16), f16tof32(fourHalfs.y));
    }
    else if (attributeFormat == kVertexFormatUNorm8)
    {
        const uint value = unity_MeshVertexBuffers_RT[vertexDecl.Stream].Load(attributeAddress);
        return float3(value & 0xff, (value & 0xff00) >> 8, (value & 0xff0000) >> 16) / 255.0f;
    }
    else
        // Vertex attribute format not supported.
        return float3(0, 0, 0);
}

// attributeType is one of the kVertexAttribute* defines
float4 UnityRayTracingFetchVertexAttribute4(uint vertexIndex, uint attributeType)
{
    VertexAttributeInfo vertexDecl = unity_MeshVertexDeclaration_RT[attributeType];

    const uint attributeByteOffset = vertexDecl.ByteOffset;
    const uint attributeDimension = vertexDecl.Dimension;

    if (attributeByteOffset == INVALID_VERTEX_ATTRIBUTE_OFFSET || attributeDimension < 4)
        return float4(0, 0, 0, 0);

    const uint vertexSize       = unity_MeshInfo_RT[0].vertexSize[vertexDecl.Stream];
    const uint vertexAddress    = vertexIndex * vertexSize;
    const uint attributeAddress = vertexAddress + attributeByteOffset;
    const uint attributeFormat  = vertexDecl.Format;

    if (attributeFormat == kVertexFormatFloat)
    {
        return asfloat(unity_MeshVertexBuffers_RT[vertexDecl.Stream].Load4(attributeAddress));
    }
    else if (attributeFormat == kVertexFormatFloat16)
    {
        const uint2 fourHalfs = unity_MeshVertexBuffers_RT[vertexDecl.Stream].Load2(attributeAddress);
        return float4(f16tof32(fourHalfs.x), f16tof32(fourHalfs.x >> 16), f16tof32(fourHalfs.y), f16tof32(fourHalfs.y >> 16));
    }
    else if (attributeFormat == kVertexFormatUNorm8)
    {
        const uint value = unity_MeshVertexBuffers_RT[vertexDecl.Stream].Load(attributeAddress);
        return float4(value & 0xff, (value & 0xff00) >> 8, (value & 0xff0000) >> 16, (value & 0xff000000) >> 24) / 255.0f;
    }
    else
        // Vertex attribute format not supported.
        return float4(0, 0, 0, 0);
}

#endif  //#ifndef UNITY_RAY_TRACING_MESH_UTILS_INCLUDED
