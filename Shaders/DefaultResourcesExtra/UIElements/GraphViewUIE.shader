// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/GraphView/GraphViewUIE"
{
    Properties
    {
        // Establish sensible default values
        [HideInInspector] _MainTex("Atlas", 2D) = "white" {}
        [HideInInspector] _FontTex("Font", 2D) = "black" {}
        [HideInInspector] _CustomTex("Custom", 2D) = "black" {}
        [HideInInspector] _Color("Tint", Color) = (1,1,1,1)
    }

    CGINCLUDE
    #include "EditorUIE.cginc"

    float _GraphViewScale;
    float _EditorPixelsPerPoint;

    static const float kGraphViewEdgeFlag = 10.0f; // As defined in VertexFlags

    v2f ProcessEdge(appdata_t v)
    {
        UNITY_SETUP_INSTANCE_ID(v);
        uie_vert_load_payload(v);
        v.vertex.xyz = mul(uie_toWorldMat, v.vertex);
        v.uv.xy = mul(uie_toWorldMat, float4(v.uv.xy,0,0)).xy;

        static const float k_MinEdgeWidth = 1.75f;
        const float halfWidth = length(v.uv.xy);
        const float edgeWidth = halfWidth + halfWidth;
        const float realWidth = max(edgeWidth, k_MinEdgeWidth / _GraphViewScale);
        const float _ZoomCorrection = realWidth / edgeWidth;
        const float _ZoomFactor = _GraphViewScale * _ZoomCorrection * _EditorPixelsPerPoint;
        const float vertexHalfWidth = halfWidth + 1; // One more pixel is enough for our geometric AA
        const float sideSign = v.vertex.z;
        const float2 normal = v.uv.xy * vertexHalfWidth / halfWidth * sideSign; // Thickness direction relengthed to cover one more pixel to give custom AA space to work

        float2 vertex = v.vertex.xy + normal * _ZoomCorrection;

        v2f o;
        UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
        o.pos = UnityObjectToClipPos(float3(vertex.xy, kUIEMeshZ));
        o.uvClip.xy = float2(vertexHalfWidth*sideSign, halfWidth);
        o.typeTexSettings.x = 100.0f; // Marking as an edge
        o.typeTexSettings.y = _ZoomFactor;
        o.typeTexSettings.zw = half2(0, 0);
        o.colorUVs = float2(0,0);
        o.circle = half4(0, 0, 0, 0);

        float unused;
        float2 clipRectUVs, opacityUVs;
        uie_std_vert_shader_info(v, o.color, clipRectUVs, opacityUVs, unused, o.colorUVs.xy);

#if UIE_SHADER_INFO_IN_VS
        float4 rectClippingData = SampleShaderInfo(clipRectUVs);
        o.uvClip.zw = ComputeRelativeClipRectCoords(rectClippingData.xy, rectClippingData.zw, vertex.xy);
#else // !UIE_SHADER_INFO_IN_VS
        o.clipRectOpacityUVs.xy = clipRectUVs;
        o.clipRectOpacityUVs.zw = opacityUVs;
        o.uvClip.zw = v.vertex.xy;
#endif

        o.color.a *= edgeWidth / realWidth; // make up for bigger edge by fading it.
        return o;
    }

    v2f vert(appdata_t v)
    {
        if (v.flags.x*255.0f == kGraphViewEdgeFlag)
            return ProcessEdge(v);
        return uie_std_vert(v);
    }

    fixed4 frag(v2f IN) : SV_Target
    {
        fixed4 col = fixed4(0, 0, 0, 0);
        if (IN.typeTexSettings.x == 100.0f) // Is it an edge?
        {
            float distanceSat = saturate((IN.uvClip.y - abs(IN.uvClip.x)) * IN.typeTexSettings.y + 0.5);
            col = fixed4(IN.color.rgb, IN.color.a * distanceSat);
        }
        else
            col = uie_editor_frag(IN);
        return col;
    }
    ENDCG

    Category
    {
        Lighting Off
        Blend SrcAlpha OneMinusSrcAlpha

        // Users pass depth between [Near,Far] = [-1,1]. This gets stored on the depth buffer in [Near,Far] [0,1] regardless of the underlying graphics API.
        Cull Off    // Two sided rendering is crucial for immediate clipping
        ZWrite Off
        Stencil
        {
            Ref         255 // 255 for ease of visualization in RenderDoc, but can be just one bit
            ReadMask    255
            WriteMask   255

            CompFront Always
            PassFront Keep
            ZFailFront Replace
            FailFront Keep

            CompBack Equal
            PassBack Keep
            ZFailBack Zero
            FailBack Keep
        }

        Tags
        {
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
            "RenderType" = "Transparent"
            "PreviewType" = "Plane"
        }

        // SM3.5 version
        SubShader
        {
            Tags { "UIE_VertexTexturingIsAvailable" = "1" "UIE_ShaderModelIs35" = "1" }
            Pass
            {
                CGPROGRAM
                #pragma target 3.5
                #pragma vertex vert
                #pragma fragment frag
                #pragma require samplelod
                ENDCG
            }
        }

        // SM2.0 version
        SubShader
        {
            Pass
            {
                CGPROGRAM
                #pragma target 2.0
                #pragma vertex vert
                #pragma fragment frag
                ENDCG
            }
        }
    } // Category
}
