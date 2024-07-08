// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/Internal-GUITextureClipInactive"
{
    Properties { _MainTex ("Texture", Any) = "white" {} }

    SubShader {

        Tags { "ForceSupported" = "True" }

        Lighting Off
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        ZWrite Off
        ZTest Always

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0

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
                float2 texgencoord : TEXCOORD1;
            };

            sampler2D _MainTex;
            sampler2D _GUIClipTexture;

            uniform float4 _MainTex_ST;
            uniform fixed4 _Color;
            uniform float4x4 unity_GUIClipTextureMatrix;

            v2f vert (appdata_t v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                float3 texgen = UnityObjectToViewPos(v.vertex);
                o.texgencoord = mul(unity_GUIClipTextureMatrix, float4(texgen.xy, 0, 1.0));
                o.color = v.color;
                o.texcoord = TRANSFORM_TEX(v.texcoord,_MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.texcoord);
                col.rgb = dot(col.rgb, fixed3(0.22, 0.707, 0.071));
                col.a *= tex2D(_GUIClipTexture, i.texgencoord).a;
                col.a *= 0.5;
                return col;
            }
            ENDCG
        }
    }
}
