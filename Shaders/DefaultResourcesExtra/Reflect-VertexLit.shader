// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Legacy Shaders/Reflective/VertexLit"
{
    Properties
    {
        _Color("Main Color", Color) = (1,1,1,1)
        _ReflectColor("Reflection Color", Color) = (1,1,1,0.5)
        _MainTex("Base (RGB) RefStrength (A)", 2D) = "white" {}
        _Cube("Reflection Cubemap", Cube) = "_Skybox" {}
    }

    Category
    {
        Tags{ "RenderType" = "Opaque" }
        LOD 150

        SubShader
        {

            // First pass does reflection cubemap
            Pass
            {
                Name "BASE"
                Tags{ "LightMode" = "Always" }

                CGPROGRAM

                #pragma vertex vert
                #pragma fragment frag
                #pragma target 2.0
                #pragma multi_compile_fog
                #include "UnityCG.cginc"

                struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 I : TEXCOORD1;
                UNITY_FOG_COORDS(2)

                UNITY_VERTEX_OUTPUT_STEREO
            };

            uniform float4 _MainTex_ST;

            v2f vert(appdata_tan v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord,_MainTex);

                // calculate world space reflection vector
                float3 viewDir = WorldSpaceViewDir(v.vertex);
                float3 worldN = UnityObjectToWorldNormal(v.normal);
                o.I = reflect(-viewDir, worldN);

                UNITY_TRANSFER_FOG(o,o.pos);
                return o;
            }

            uniform sampler2D _MainTex;
            uniform samplerCUBE _Cube;
            uniform fixed4 _ReflectColor;

            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 texcol = tex2D(_MainTex, i.uv);
                fixed4 reflcol = texCUBE(_Cube, i.I);
                reflcol *= texcol.a;
                fixed4 col = reflcol * _ReflectColor;
                UNITY_APPLY_FOG(i.fogCoord, col);
                UNITY_OPAQUE_ALPHA(col.a);
                return col;
            }

            ENDCG

        }

        // Vertex Lit, emulated in shaders (4 lights max, no specular)
        Pass
        {
            Tags{ "LightMode" = "Vertex" }
            Blend One One ZWrite Off
            Lighting On

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                fixed4 diff : COLOR0;
                float4 pos : SV_POSITION;

                UNITY_VERTEX_OUTPUT_STEREO
            };

            uniform float4 _MainTex_ST;
            uniform float4 _Color;
            uniform fixed4 _ReflectColor;

            v2f vert(appdata_base v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord,_MainTex);
                float4 lighting = float4(ShadeVertexLightsFull(v.vertex, v.normal, 4, true),_ReflectColor.w);
                o.diff = lighting * _Color;
                UNITY_TRANSFER_FOG(o,o.pos);
                return o;
            }

            uniform sampler2D _MainTex;

            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 temp = tex2D(_MainTex, i.uv);
                fixed4 c;
                c.xyz = temp.xyz * i.diff.xyz;
                c.w = temp.w * i.diff.w;
                UNITY_APPLY_FOG_COLOR(i.fogCoord, c, fixed4(0,0,0,0)); // fog towards black due to our blend mode
                UNITY_OPAQUE_ALPHA(c.a);
                return c;
            }

            ENDCG
        }

        // Lightmapped
        Pass
        {
            Tags{ "LightMode" = "VertexLM" }
            Blend One One ZWrite Off
            ColorMask RGB

            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct a2v
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
                UNITY_FOG_COORDS(2)
                float4 pos : SV_POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            uniform float4 _MainTex_ST;
            uniform float4x4 unity_LightmapMatrix;

            v2f vert(a2v v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv,_MainTex);
                o.uv2 = mul(unity_LightmapMatrix, float4(v.uv2,0,1)).xy;
                UNITY_TRANSFER_FOG(o,o.pos);
                return o;
            }

            uniform sampler2D _MainTex;
            uniform fixed4 _Color;

            fixed4 frag(v2f i) : SV_Target
            {
                fixed4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, i.uv2);
                fixed4 lm = fixed4(DecodeLightmap(bakedColorTex), 1);
                lm *= _Color;
                fixed4 c = tex2D(_MainTex, i.uv);
                c.rgb *= lm.rgb;
                UNITY_APPLY_FOG_COLOR(i.fogCoord, c, fixed4(0,0,0,0));
                UNITY_OPAQUE_ALPHA(c.a);
                return c;
            }
            ENDCG
        }
    }
    }

    FallBack "Legacy Shaders/VertexLit"
}
