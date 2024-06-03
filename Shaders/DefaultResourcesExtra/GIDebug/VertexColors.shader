// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/GIDebug/VertexColors" {
    Properties {
        _MainTex ("Base (RGB)", 2D) = "white" {}
    }
    SubShader {
        Pass {
            Tags { "RenderType"="Opaque" }
            LOD 200

            CGPROGRAM
            #pragma vertex vert_surf
            #pragma fragment frag_surf
            #include "UnityCG.cginc"

            struct v2f_surf
            {
                float4 pos      : SV_POSITION;
                float3 normal   : NORMAL;
                float3 posWorld : TEXCOORD1;
                fixed4 color    : COLOR;
            };

            float _Lit;

            v2f_surf vert_surf (appdata_full v)
            {
                v2f_surf o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.posWorld = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.color = v.color;
                return o;
            }

            float4 frag_surf(v2f_surf IN) : SV_Target
            {
                float4 result = IN.color;

                if (_Lit)
                {
                    float3 viewDir = normalize(IN.posWorld - _WorldSpaceCameraPos);
                    float rimLight = clamp(dot(IN.normal, -viewDir), 0.2, 1);
                    result.rgb *= rimLight;
                }

                return result;
            }
            ENDCG
        }
    }
}
