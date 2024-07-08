// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

#ifdef SKINNING_GENERIC_VERTEX_VIEW_FORMAT
#error Internal-Skinning-Util.cginc has been included twice
#endif

#define SKINNING_GENERIC_VERTEX_USE_STRUCTURED_BUFFER (2)
#define SKINNING_GENERIC_VERTEX_USE_RAW_BUFFER (3)

// GPU skinning code can use either Structured or Raw buffer for the mesh data access; this
// varies by platform. Choices here should match what's in GraphicsCaps::computeBufferTargetForGeometryBuffer
// on the C++ side.
#if defined(SHADER_API_GLCORE) || defined(SHADER_API_GLES) || defined(SHADER_API_GLES3) || defined(SHADER_API_METAL) || defined(SHADER_API_VULKAN) || defined(SHADER_API_SWITCH)
    #define SKINNING_GENERIC_VERTEX_VIEW_FORMAT SKINNING_GENERIC_VERTEX_USE_STRUCTURED_BUFFER
#else
    #define SKINNING_GENERIC_VERTEX_VIEW_FORMAT SKINNING_GENERIC_VERTEX_USE_RAW_BUFFER
#endif

#if SKIN_NORM && SKIN_TANG
#define VERTEX_STRIDE 10
#elif SKIN_NORM
#define VERTEX_STRIDE 6
#else
#define VERTEX_STRIDE 3
#endif

#if SKIN_BONESFORVERT <= 1
#define SKININFLUENCE_STRIDE 1
#elif SKIN_BONESFORVERT == 2
#define SKININFLUENCE_STRIDE 4
#elif SKIN_BONESFORVERT == 4
#define SKININFLUENCE_STRIDE 8
#else
#error Unpexcted bone influence count SKIN_BONESFORVERT
#endif

#define BLENDSHAPE_STRIDE 10

struct MeshVertex
{
    float3 pos;
#if SKIN_NORM
    float3 norm;
#endif
#if SKIN_TANG
    float4 tang;
#endif
};

struct SkinInfluence
{
#if SKIN_BONESFORVERT <= 1
    int index0;
#elif SKIN_BONESFORVERT == 2
    float weight0, weight1;
    int index0, index1;
#elif SKIN_BONESFORVERT == 4
    float weight0, weight1, weight2, weight3;
    int index0, index1, index2, index3;
#endif
};

struct BlendShapeVertex
{
    int index;
    float3 pos;
    float3 norm;
    float3 tang;
};

#if SKINNING_GENERIC_VERTEX_VIEW_FORMAT == SKINNING_GENERIC_VERTEX_USE_RAW_BUFFER

#define SKINNING_GENERIC_VERTEX_BUFFER SAMPLER_UNIFORM ByteAddressBuffer
#define SKINNING_GENERIC_VERTEX_RWBUFFER SAMPLER_UNIFORM RWByteAddressBuffer
#define SKINNING_GENERIC_SKIN_BUFFER SAMPLER_UNIFORM ByteAddressBuffer
#define SKINNING_GENERIC_SKIN_BUFFER_BLENDSHAPE SAMPLER_UNIFORM ByteAddressBuffer

float   FetchBuffer (ByteAddressBuffer buffer, int offset)     { return asfloat(buffer.Load (offset << 2)); }
float2  FetchBuffer2(ByteAddressBuffer buffer, int offset)     { return asfloat(buffer.Load2(offset << 2)); }
float3  FetchBuffer3(ByteAddressBuffer buffer, int offset)     { return asfloat(buffer.Load3(offset << 2)); }
float4  FetchBuffer4(ByteAddressBuffer buffer, int offset)     { return asfloat(buffer.Load4(offset << 2)); }

float   FetchBuffer (RWByteAddressBuffer buffer, int offset)   { return asfloat(buffer.Load (offset << 2)); }
float2  FetchBuffer2(RWByteAddressBuffer buffer, int offset)   { return asfloat(buffer.Load2(offset << 2)); }
float3  FetchBuffer3(RWByteAddressBuffer buffer, int offset)   { return asfloat(buffer.Load3(offset << 2)); }
float4  FetchBuffer4(RWByteAddressBuffer buffer, int offset)   { return asfloat(buffer.Load4(offset << 2)); }

void StoreBuffer (RWByteAddressBuffer buffer, int offset, float  value) { buffer.Store (offset << 2, asuint(value)); }
void StoreBuffer2(RWByteAddressBuffer buffer, int offset, float2 value) { buffer.Store2(offset << 2, asuint(value)); }
void StoreBuffer3(RWByteAddressBuffer buffer, int offset, float3 value) { buffer.Store3(offset << 2, asuint(value)); }
void StoreBuffer4(RWByteAddressBuffer buffer, int offset, float4 value) { buffer.Store4(offset << 2, asuint(value)); }


MeshVertex FetchVert(SKINNING_GENERIC_VERTEX_BUFFER vertices, const uint index)
{
    MeshVertex vert;
    int stride = VERTEX_STRIDE;
    int offset = index * stride;

    vert.pos = FetchBuffer3(vertices, offset);
    offset += 3;

#if SKIN_NORM
    vert.norm = FetchBuffer3(vertices, offset);
    offset += 3;
#endif

#if SKIN_TANG
    vert.tang = FetchBuffer4(vertices, offset);
#endif
    return vert;
}

MeshVertex FetchVert(SKINNING_GENERIC_VERTEX_RWBUFFER vertices, const uint index)
{
    MeshVertex vert;
    int stride = VERTEX_STRIDE;
    int offset = index * stride;

    vert.pos = FetchBuffer3(vertices, offset);
    offset += 3;

#if SKIN_NORM
    vert.norm = FetchBuffer3(vertices, offset);
    offset += 3;
#endif

#if SKIN_TANG
    vert.tang = FetchBuffer4(vertices, offset);
#endif
    return vert;
}

SkinInfluence FetchSkin(SKINNING_GENERIC_SKIN_BUFFER skins, const uint index)
{
    SkinInfluence skin;
    int stride = SKININFLUENCE_STRIDE;
    int offset = index * stride;

#if SKIN_BONESFORVERT <= 1
    skin.index0 = asint(FetchBuffer(skins, offset));
#elif SKIN_BONESFORVERT == 2
    float4 raw = FetchBuffer4(skins, offset);
    skin.weight0 = raw.x;
    skin.weight1 = raw.y;
    skin.index0 = asint(raw.z);
    skin.index1 = asint(raw.w);
#elif SKIN_BONESFORVERT == 4
    float4 raw0 = FetchBuffer4(skins, offset);
    int4 raw1 = asint(FetchBuffer4(skins, offset + 4));
    skin.weight0 = raw0.x;
    skin.weight1 = raw0.y;
    skin.weight2 = raw0.z;
    skin.weight3 = raw0.w;
    skin.index0 = raw1.x;
    skin.index1 = raw1.y;
    skin.index2 = raw1.z;
    skin.index3 = raw1.w;
#endif

    return skin;
}

BlendShapeVertex FetchBlendShape(SKINNING_GENERIC_SKIN_BUFFER_BLENDSHAPE blendShapes, const uint index)
{
    BlendShapeVertex blendShape;
    int stride = BLENDSHAPE_STRIDE;
    int offset = index * stride;

    float4 raw0 = FetchBuffer4(blendShapes, offset);
    float4 raw1 = FetchBuffer4(blendShapes, offset + 4);
    float2 raw2 = FetchBuffer2(blendShapes, offset + 8);

    blendShape.index = asint(raw0.x);
    blendShape.pos = raw0.yzw;
    blendShape.norm = raw1.xyz;
    blendShape.tang = float3(raw1.w, raw2.x, raw2.y);

    return blendShape;
}

void StoreVert(SKINNING_GENERIC_VERTEX_RWBUFFER vertices, MeshVertex vertex, const uint index)
{
    int stride = VERTEX_STRIDE;
    int offset = index * stride;

    StoreBuffer3(vertices, offset, vertex.pos);
    offset += 3;

#if SKIN_NORM
    StoreBuffer3(vertices, offset, vertex.norm);
    offset += 3;
#endif

#if SKIN_TANG
    StoreBuffer4(vertices, offset, vertex.tang);
#endif

}
#elif SKINNING_GENERIC_VERTEX_VIEW_FORMAT == SKINNING_GENERIC_VERTEX_USE_STRUCTURED_BUFFER
#define SKINNING_GENERIC_VERTEX_BUFFER SAMPLER_UNIFORM StructuredBuffer<MeshVertex>
#define SKINNING_GENERIC_VERTEX_RWBUFFER SAMPLER_UNIFORM RWStructuredBuffer<MeshVertex>
#define SKINNING_GENERIC_SKIN_BUFFER SAMPLER_UNIFORM StructuredBuffer<SkinInfluence>
#define SKINNING_GENERIC_SKIN_BUFFER_BLENDSHAPE SAMPLER_UNIFORM StructuredBuffer<BlendShapeVertex>

MeshVertex FetchVert(SKINNING_GENERIC_VERTEX_BUFFER vertices, const uint index)
{
    return vertices[index];
}

MeshVertex FetchVert(SKINNING_GENERIC_VERTEX_RWBUFFER vertices, const uint index)
{
    return vertices[index];
}

SkinInfluence FetchSkin(SKINNING_GENERIC_SKIN_BUFFER skins, const uint index)
{
    return skins[index];
}

BlendShapeVertex FetchBlendShape(SKINNING_GENERIC_SKIN_BUFFER_BLENDSHAPE blendShapes, const uint index)
{
    return blendShapes[index];
}

void StoreVert(SKINNING_GENERIC_VERTEX_RWBUFFER outVertices, MeshVertex vertex, const uint index)
{
    outVertices[index].pos = vertex.pos;
#if SKIN_NORM
    outVertices[index].norm = vertex.norm;
#endif
#if SKIN_TANG
    outVertices[index].tang = vertex.tang;
#endif
}

#endif
