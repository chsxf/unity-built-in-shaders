// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/Internal-UIE-ColorConversionBlit"
{

    // This shader is used when VisualElement render into a temporary RenderTexture and we need to copy that render texture to the original one higer in the hierarchy.
    // The resulting texture is premultiplied alpha, but we cannot use regular blend options as we need to to do some special conversion in the fragment shader to obtain the right color.
    //
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _ColorConversion("Color Conversion (0 = none, 1 = linear to gamma, -1 = gamma to linear)", Float ) = 0.0
    }
    SubShader
    {
        Blend SrcAlpha OneMinusSrcAlpha, One OneMinusSrcAlpha


        // Users pass depth between [Near,Far] = [-1,1]. This gets stored on the depth buffer in [Near,Far] [0,1] regardless of the underlying graphics API.
        Cull Off    // Two sided rendering is crucial for immediate clipping
        ZWrite Off

        // The stencil is copied form the regular shader to be used as a blit when coping back from a renderTexture while respecting the clipping area
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

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            half _ColorConversion;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);



                if (col.a <= 0.001) // Using this instead of clip because clip doesnt discard when alpha=0 (clip = if(col.a<0) discard;)
                    discard;

                // Because we have been blening on a black bacground, some of the original black color will stay there if we only added partailly transparent material.
                // We divde the color with the sum of all alpha write as the maximum color is = to alpha.
                //
                // When alpha is opaque (1) this has no effect
                // When alpha is 0, there is nothing to blend and we discard.
                // When alpha is really small, we may have some resolution error compared with the original color, it does not matter as the value will be multiplied back later and result in a small error.
                col.rgb /= col.a;


                // Removing the line above and setting the blend factors to "Blend One OneMinusSrcAlpha ... " like premultiplied transparency
                // changes the results as the color space conversion will happen on a darker color.
                // Color close to the extremes (near 0) will have less 'adjustement' than what they would have if they were were not premultiplied.
                // Because of this, we need to invert the premultiplication and apply the conversion function on the original color.


                if (_ColorConversion == 1)
                    return fixed4(LinearToGammaSpace(col.rgb), col.a);
                if(_ColorConversion == -1)
                    return fixed4(GammaToLinearSpace(col.rgb), col.a);
                return col;
            }
            ENDCG
        }
    }
}
