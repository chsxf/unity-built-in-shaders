// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

// MIT License
// Copyright (c) 2022 Erin Catto
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// 
// The above notice is included due to a significant portion of the following shader code
// coming from Box2D.

Shader "Hidden/Physics2D/SDF_Point"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            Cull Off

        Pass
        {
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing

            #include "UnityCG.cginc"
            #define UNITY_INDIRECT_DRAW_ARGS IndirectDrawIndexedArgs
            #include "UnityIndirect.cginc"

            // Swizzle for Transform Plane:
            // 0 = XY plane with Z rotation.
            // 1 = XZ plane with Y rotation.
            // 2 = ZY plane with X rotation.
            float4 transformPlaneSwizzle(float4 input, int transform_plane)
            {
                if (transform_plane == 0)
                    return input.xyzw;

                if (transform_plane == 1)
                    return input.xzyw;

                return input.zyxw;
            }          
            
            struct vertexInput
            {
                float4 vertex   : POSITION;
            };

            struct fragInput
            {
                float4 vertex       : SV_POSITION;
                float4 position     : TEXCOORD0;
                fixed4 color        : COLOR;
                float thickness     : THICKNESS;
            }; 

            struct pointElement
            {
                float2 position;
                float radius;
                float depth;
                float4 color;
            };

            StructuredBuffer<pointElement> element_buffer;
            int transform_plane;
            float thickness;
            
            fragInput vert(const vertexInput input, const uint instance_id: SV_InstanceID)
            {
                fragInput output;

                const pointElement element = element_buffer[instance_id];

                // Frag position.
                const float4 local_mesh_vertex = input.vertex;
                output.position = local_mesh_vertex;
                
                // Color.
                output.color = element.color;

                // Calculate orthographic pixel size.
                const float4 pre_transformed = float4((local_mesh_vertex.xy + element.position.xy).xy, element.depth, local_mesh_vertex.w);
                float pixel_size = (pre_transformed.w / (float2(1, 1) * abs(mul((float2x2)UNITY_MATRIX_P, _ScreenParams.xy)))).y;
                // If we're using a perspective projection then scale by eye-depth.
                if (unity_OrthoParams.w == 0.0f)
                    pixel_size *= length(UnityObjectToViewPos( pre_transformed ).xyz);
                
                // Vertex.
                const float radius = element.radius;
                const float2 position = element.position;
                const float scaling = radius * pixel_size;
                const float2 p = (local_mesh_vertex.xy * scaling.xx) + position.xy;

                // Calculate transformed (plane) vertex.
                const float4 transformed = transformPlaneSwizzle( float4(p.xy, element.depth, local_mesh_vertex.w), transform_plane );
                
                // Thickness.
                output.thickness = thickness * (pixel_size / scaling);
                
                // Transformed vertex.
                output.vertex = UnityObjectToClipPos( transformed );
                
                return output;
            }

            fixed4 frag(fragInput input) : SV_Target
            {
                const float radius = 0.9;
                
                // Distance to point circumference.
                const float2 w = input.position.xy;
                const float dw = length(w);

                const float thickness = input.thickness;
                if (dw > radius + thickness)
                    discard;
                
                fixed4 color = input.color;
                
                if (dw >= radius)
                {
                    const float dist = abs(dw - radius);
                    color.a *= smoothstep(thickness, 0.0, dist);
                    return color;
                }

                return color;
            }
            
            ENDHLSL
        }
    }
}
