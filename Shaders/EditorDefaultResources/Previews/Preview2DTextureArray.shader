// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

Shader "Hidden/Preview 2D Texture Array"
{
    Properties
    {
        _MainTex ("Texture", 2DArray) = "" {}
        _SliceIndex ("Slice", Int) = 0
        _Mip ("Mip level", Int) = 0
    }
    Subshader {
        Pass
        {

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.5
            #include "UnityCG.cginc"
            struct v2f {
                float4 vertex : SV_POSITION;
                float3 uv : TEXCOORD0;
            };
            uniform int _SliceIndex;
            uniform int _Mip;
            uniform bool _AlphaOnly;
            v2f vert (float4 v : POSITION, float2 t : TEXCOORD0)
            {
                v2f o;
                o.uv = float3(t, _SliceIndex);
                o.vertex = UnityObjectToClipPos(v);
                return o;
            }
            uniform bool _ManualTex2SRGB;
            UNITY_DECLARE_TEX2DARRAY(_MainTex);
            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = UNITY_SAMPLE_TEX2DARRAY_LOD(_MainTex, i.uv, _Mip);
                if (_ManualTex2SRGB)
                    col.rgb = LinearToGammaSpace(col.rgb);

                return _AlphaOnly ? col.aaaa : col;
            }
            ENDCG
        }
    }
}
