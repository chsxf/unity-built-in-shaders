// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/Highlight Backfaces"
{
    Subshader
    {
        Tags { "ForceSupported" = "True" "Queue" = "Overlay" "IgnoreProjector" = "True" }
        Blend Off
        Fog { Mode Off }

        // First pass just fills the stencil buffer with a known value where there are front faces.
        // It does not write depth or color.
        Pass
        {
            Stencil
            {
                Ref 2
                Comp Always
                Pass Replace
            }

            ColorMask 0
            ZWrite Off
            Cull Back
        }

        // Second pass renders only back faces with an unlit color. It checks whether the backfaces
        // are occluded by comparing the values previously written to the stencil buffer.
        Pass
        {
            Stencil
            {
                Ref 2
                Comp NotEqual
            }

            ColorMask RGBA
            ZWrite On
            Cull Front

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
	        #pragma multi_compile_instancing
            #pragma target 2.0
            #include "UnityCG.cginc"

	        struct appdata
            {
                float4 vertex : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

	        struct v2f
            {
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            v2f vert (appdata v)
            {
                v2f o;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                o.vertex = UnityObjectToClipPos(v.vertex);
                return o;
            }

            float4 unity_BackfaceHighlightsColor;

            float4 frag () : SV_Target
            {
                return float4(unity_BackfaceHighlightsColor.rgb, 1.0);
            }
            ENDCG
        }
    }
}
