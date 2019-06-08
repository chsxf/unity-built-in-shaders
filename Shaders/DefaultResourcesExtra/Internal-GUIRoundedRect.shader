// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/Internal-GUIRoundedRect"
{
    Properties {
        _MainTex ("Texture", any) = "white" {}
        _CornerRadius ("Corner Radius", Float) = 0.0
        _BorderWidth ("Border Width", Float) = 0.0
    }

    CGINCLUDE
    #pragma vertex vert
    #pragma fragment frag
    #pragma target 2.5

    #include "UnityCG.cginc"

    struct appdata_t {
        float4 vertex : POSITION;
        fixed4 color : COLOR;
        float2 texcoord : TEXCOORD0;
    };

    struct v2f {
        float4 vertex : SV_POSITION;
        fixed4 color : COLOR;
        float2 texcoord : TEXCOORD0;
        float2 clipUV : TEXCOORD1;
        float4 worldPos : TEXCOORD2;
    };

    sampler2D _MainTex;
    sampler2D _GUIClipTexture;

    uniform float4 _MainTex_ST;
    uniform float4x4 unity_GUIClipTextureMatrix;

    uniform float _CornerRadius;
    uniform float _BorderWidth;
    uniform float _Rect[4];
    uniform float _PixelScale;

    half GetCornerAlpha(float2 p, float2 center, float radius)
    {
        float outsideRadius = radius;
        float2 dir = normalize(p-center);
        float pixelCenterDist = length(p-center);
        float outerDist = (pixelCenterDist - outsideRadius)*_PixelScale;
        half outerDistAlpha = saturate(0.5f + outerDist);

        float insideRadius = radius - _BorderWidth;
        float innerDist = (pixelCenterDist - insideRadius)*_PixelScale;
        half innerDistAlpha = (_BorderWidth > 0) ? saturate(0.5f + innerDist) : 1.0f;

        return (outerDistAlpha == 0.0f) ? innerDistAlpha : (1.0f - outerDistAlpha);
    }

    bool IsPointInside(float2 p, float2 lowerLeft, float2 upperRight)
    {
        return p.x > lowerLeft.x && p.x < upperRight.x && p.y > lowerLeft.y && p.y < upperRight.y;
    }

    v2f vert (appdata_t v)
    {
        float3 eyePos = UnityObjectToViewPos(v.vertex);
        v2f o;
        o.vertex = UnityObjectToClipPos(v.vertex);
        o.color = v.color;
        o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
        o.clipUV = mul(unity_GUIClipTextureMatrix, float4(eyePos.xy, 0, 1.0));
        o.worldPos = v.vertex;
        return o;
    }

    fixed4 frag (v2f i) : SV_Target
    {
        half4 col = tex2D(_MainTex, i.texcoord) * i.color;
        float2 p = i.worldPos.xy;

        // top-left
        float2 center = float2(_Rect[0]+_CornerRadius, _Rect[1]+_CornerRadius);
        col.a *= (p.x < center.x && p.y < center.y) ? GetCornerAlpha(p, center, _CornerRadius) : 1.0f;

        // top-right
        center = float2(_Rect[0]+_Rect[2]-_CornerRadius, _Rect[1]+_CornerRadius);
        col.a *= (p.x > center.x && p.y < center.y) ? GetCornerAlpha(p, center, _CornerRadius) : 1.0f;

        // bottom-left
        center = float2(_Rect[0]+_CornerRadius, _Rect[1]+_Rect[3]-_CornerRadius);
        col.a *= (p.x < center.x && p.y > center.y) ? GetCornerAlpha(p, center, _CornerRadius) : 1.0f;

        // bottom-right
        center = float2(_Rect[0]+_Rect[2]-_CornerRadius, _Rect[1]+_Rect[3]-_CornerRadius);
        col.a *= (p.x > center.x && p.y > center.y) ? GetCornerAlpha(p, center, _CornerRadius) : 1.0f;

        // Cut inside if there's a border
        float bw = _BorderWidth;
        float cr = _CornerRadius;
        bool isPointInMiddle = IsPointInside(p, float2(_Rect[0]+cr+bw, _Rect[1]+cr+bw), float2(_Rect[0]+_Rect[2]-cr-bw, _Rect[1]+_Rect[3]-cr-bw));
        bool isPointInMargin = IsPointInside(p, float2(_Rect[0]+cr+bw, _Rect[1]+cr+bw), float2(_Rect[0]+_Rect[2]-cr-bw, _Rect[1]+_Rect[3]-cr-bw)) ||
                               IsPointInside(p, float2(_Rect[0]+bw, _Rect[1]+cr), float2(_Rect[0]+_Rect[2]-bw, _Rect[1]+_Rect[3]-cr)) ||
                               IsPointInside(p, float2(_Rect[0]+_Rect[2]-cr, _Rect[1]+cr), float2(_Rect[0]+_Rect[2]-cr, _Rect[1]+_Rect[3]-cr)) ||
                               IsPointInside(p, float2(_Rect[0]+cr, _Rect[1]+bw), float2(_Rect[0]+_Rect[2]-cr, _Rect[1]+_Rect[3]-bw)) ||
                               IsPointInside(p, float2(_Rect[0]+cr, _Rect[1]+_Rect[3]-cr), float2(_Rect[0]+_Rect[2]-cr, _Rect[1]+_Rect[3]-bw));
        half middleAlpha = isPointInMiddle ? 0.0f : col.a;
        half marginAlpha = isPointInMargin ? 0.0f : col.a;
        half insideAlpha = (cr < bw) ? middleAlpha : marginAlpha;
        col.a = (_BorderWidth > 0.0f) ? insideAlpha : col.a;

        col.a *= tex2D(_GUIClipTexture, i.clipUV).a;

        return col;
    }
    ENDCG

    SubShader {
        Blend SrcAlpha OneMinusSrcAlpha, One One
        Cull Off
        ZWrite Off
        ZTest Always

        Pass {
            CGPROGRAM
            ENDCG
        }
    }

    SubShader {
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        ZWrite Off
        ZTest Always

        Pass {
            CGPROGRAM
            ENDCG
        }
    }

FallBack "Hidden/Internal-GUITextureClip"
}
