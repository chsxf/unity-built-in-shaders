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

Shader "Hidden/Physics2D/SDF_CapsuleGeometry"
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

            bool isInteriorFill(int fillOptions) { return fillOptions & 1; }
            bool isOutlineFill(int fillOptions) { return fillOptions & 2; }
            bool isOrientationFill(int fillOptions) { return fillOptions & 4; }
            
            struct vertexInput
            {
                float4 vertex   : POSITION;
            };

            struct fragInput
            {
                float4 vertex       : SV_POSITION;
                float4 position     : TEXCOORD0;
                fixed4 color        : COLOR;
                fixed4 fillColor    : FILLCOLOR;
                float length        : LENGTH;
                float thickness     : THICKNESS;
                bool drawOutline    : DRAWOUTLINE;
                bool drawOrientation : DRAWORIENTATION;
                bool drawInterior    : DRAWINTERIOR;
            }; 

            struct capsuleGeometryElement
            {
                float4 transform;
                float radius;
                float length;
                float depth;
                int fillOptions;
                float4 color;
            };

            StructuredBuffer<capsuleGeometryElement> element_buffer;
            int transform_plane;
            float thickness;
            float fillAlpha;
            
            fragInput vert(const vertexInput input, const uint instance_id: SV_InstanceID)
            {
                fragInput output;

                const capsuleGeometryElement element = element_buffer[instance_id];

                // Frag position.
                const float4 local_mesh_vertex = input.vertex;
                output.position = local_mesh_vertex;

                // Fill flags.
                output.drawOutline = isOutlineFill(element.fillOptions);
                output.drawOrientation = isOrientationFill(element.fillOptions);
                output.drawInterior = isInteriorFill(element.fillOptions);
                
                // Color.
                output.color = element.color;
                if (output.drawInterior)
                {
                    if (output.drawOutline)
                        output.fillColor = fixed4(element.color.rgb, element.color.a * fillAlpha);
                    else
                        output.fillColor = element.color;
                }
                
                // Length.
                const float line_length = element.length;
                
                // Scale quad large enough to hold capsule.
                const float radius = element.radius;
                const float scale = radius + 0.5 * line_length;

                // Quad range of [-1, 1] implies normalize radius and length.
                output.length = line_length / scale;
                
                const float4 xf = element.transform;
                const float c = xf.z;
                const float s = xf.w;
                
                const float2 p = local_mesh_vertex.xy * scale.xx;
                const float2 p_rot = float2(c * p.x - s * p.y, s * p.x + c * p.y) + xf.xy;

                // Calculate transformed (plane) vertex.
                const float4 transformed = transformPlaneSwizzle( float4(p_rot.xy, element.depth, local_mesh_vertex.w), transform_plane );

                // Calculate orthographic pixel size.
                float pixel_size = (transformed.w / (float2(1, 1) * abs(mul((float2x2)UNITY_MATRIX_P, _ScreenParams.xy)))).y;
                // If we're using a perspective projection then scale by eye-depth.
                if (unity_OrthoParams.w == 0.0f)
                    pixel_size *= length(UnityObjectToViewPos( transformed ).xyz);

                // Thickness.
                output.thickness = thickness * (pixel_size / scale);

                // Transformed vertex.
                output.vertex = UnityObjectToClipPos( transformed );
                
                return output;
            }

            // https://en.wikipedia.org/wiki/Alpha_compositing
            float4 blend_colors(float4 front, float4 back)
            {
                const float3 c_src = front.rgb;
                const float alpha_src = front.a;
                const float3 c_dst = back.rgb;
                const float alpha_dst = back.a;

                float3 c_out = c_src * alpha_src + c_dst * alpha_dst * (1.0 - alpha_src);
                float alpha_out = alpha_src + alpha_dst * (1.0 - alpha_src);
                c_out = c_out / alpha_out;

                return float4(c_out, alpha_out);
            }
            
            fixed4 frag(const fragInput input) : SV_Target
            {
                // Radius in unit quad.
                const float radius = 0.5 * (2.0 - input.length);

                const float2 v1 = float2(-0.5 * input.length, 0);
                const float2 v2 = float2(0.5 * input.length, 0);
                
                // Distance to line segment.
                const float2 e = v2 - v1;
                const float2 w = input.position - v1;
                const float we = dot(w, e);
                const float2 b = w - e * clamp(we / dot(e, e), 0.0, 1.0);
                const float dw = length(b);

                const float thickness = input.thickness;
                if (dw > radius + thickness)
                    discard;

                // If filled, roll the fill alpha down at the border.
                float4 interior = float4(0,0,0,0);
                if (input.drawInterior)
                    interior = float4(input.fillColor.rgb, input.fillColor.a * smoothstep(radius + thickness, radius, dw));

                // Roll the border alpha down from 1 to 0 across the border thickness.
                float4 outline = float4(0,0,0,0);
                if (input.drawOutline)
                {
                    // SDF union of capsule and line segment.
                    const float dc = abs(dw - radius);
                    const float distance = input.drawOrientation ? min(dw, dc) : dc;
                    
                    const float4 outline_color = input.color;
                    outline = float4(outline_color.rgb, outline_color.a * smoothstep(thickness, 0.0f, distance));
                }
                
                return blend_colors(outline, interior);
            }
            
            ENDHLSL
        }
    }
}
