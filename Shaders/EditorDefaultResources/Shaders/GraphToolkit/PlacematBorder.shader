// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/GTF/PlacematBorder"
{
    Properties
    {
        _Border("Border",float) = 1
        _Radius("Radius",float) = 1
        _Size("Size",Vector) = (100,100,0,0)
        _ColorLight("ColorLight",Color) = (1,1,0,1)
        _ColorDark("ColorDark", Color) = (0,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        LOD 100
        Cull Front
        ZWrite Off
        ZTest Always
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // For U7
            // #include "UnityCG.hlsl"
            // For U6
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
                float4 pos : TEXCOORD2;
                float2 clipUV : TEXCOORD1;
                float height : TEXCOORD3;
            };

            float _Border;
            float _Radius;
            float2 _Size;
            fixed4 _ColorLight;
            fixed4 _ColorDark;

            uniform float4x4 unity_GUIClipTextureMatrix;
            sampler2D _GUIClipTexture;


            v2f vert (appdata v)
            {
                v2f o;

                float2 size = _Size;
                const float minZoom = 0.1f;

                const float extents = max(_Border, 1 / minZoom);

                o.pos = float4(v.vertex.xy * size + v.vertex.xy * v.uv * extents, 0, 0);
                o.height = (v.vertex.y + 1) * 0.5;
                o.vertex = UnityObjectToClipPos(o.pos);
                o.uv = v.uv * extents; // uvs in pixels
                float3 eyePos = UnityObjectToViewPos(o.pos);
                o.clipUV = mul(unity_GUIClipTextureMatrix, float4(eyePos.xy, 0, 1.0));
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float pixelScale = abs(ddx(i.pos.x));
                float border = _Border;

                bool roundedCorners = true;
                //make border at least 1 pixel.
                if (border / pixelScale < 1)
                {
                    border = pixelScale;
                    roundedCorners = false;
                }
                if (abs(i.uv.x) > border || abs(i.uv.y) > border)
                    discard;

                // Excluding pixels
                float2 pos = abs(i.pos);
                float2 distanceToCorner = (_Size + float2(border,border) - pos);
                float halfBorder = border * 0.5f;
                float radiusPlusHalfBorder = halfBorder + _Radius;
                float radiusMinusHalfBorder = _Radius - halfBorder;
                float2 distanceToRadius = -(distanceToCorner - radiusPlusHalfBorder);

                float alpha = 1;
                if (!roundedCorners)
                {
                    if (i.uv.x < 0 || i.uv.y < 0)
                      discard;
                }
                else
                {
                    if (radiusMinusHalfBorder <= border)
                    {
                        bool inBadCorners = (distanceToRadius.x < 0 || distanceToRadius.y < 0) && i.uv.x < 0 && i.uv.y < 0;

                        if (inBadCorners)
                            discard;
                    }

                    float pixelRadius = abs(length(distanceToRadius) - _Radius);

                    if (pos.x > _Size.x - radiusMinusHalfBorder && pos.y > _Size.y - radiusMinusHalfBorder)
                    {
                        if (pixelRadius > halfBorder - pixelScale* 0.5f)
                        {
                            float delta = pixelRadius - (halfBorder - pixelScale * 0.5f);

                            if (delta < pixelScale)
                            {
                                alpha = (pixelScale - delta) / pixelScale;
                            }
                            else
                            {
                                discard;
                            }
                        }
                    }
                }

                //Computing gradient.
                fixed4 color;
                const float gradientStart = 0.86f;
                const float gradientEnd = 0.93f;

                if (i.height < gradientStart)
                    color = _ColorLight;
                else if (i.height < gradientEnd)
                    color = lerp(_ColorLight,_ColorDark, (i.height - gradientStart) / (gradientEnd - gradientStart));
                else
                    color = _ColorDark;

                float clipA = tex2D(_GUIClipTexture, i.clipUV).a;
                return float4(color.rgb,alpha * clipA);
            }
            ENDCG
        }
    }
}
