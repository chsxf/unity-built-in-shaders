Shader "uGUI/Lit/Detail"
{
	Properties
	{
		_Color ("Main Color", Color) = (1,1,1,1)
		_Specular ("Specular Color", Color) = (0,0,0,0)
		_MainTex ("Diffuse (RGB), Alpha (A)", 2D) = "white" {}
		_MainBump ("Diffuse Bump Map", 2D) = "bump" {}
		_DetailTex ("Detail (RGB)", 2D) = "white" {}
		_DetailBump ("Detail Bump Map", 2D) = "bump" {}
		_Strength ("Detail Strength", Range(0.0, 1.0)) = 0.2
		_Shininess ("Shininess", Range(0.01, 1.0)) = 0.2
		
		_StencilComp ("Stencil Comparison", Float) = 8
		_Stencil ("Stencil ID", Float) = 0
		_StencilOp ("Stencil Operation", Float) = 0
		_ColorMask ("Color Mask", Float) = 15
	}
	
	// SM 3.0
	SubShader
	{
		LOD 100

		Tags
		{
			"Queue" = "Transparent"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
		}

		Stencil
		{
			Ref [_Stencil]
			Comp [_StencilComp]
			Pass [_StencilOp]
		}
		
		Cull Off
		Lighting Off
		ZWrite Off
		ZTest [unity_GUIZTestMode]
		Fog { Mode Off }
		Offset -1, -1
		Blend SrcAlpha OneMinusSrcAlpha
		ColorMask [_ColorMask]

		CGPROGRAM
			#pragma target 3.0
			#pragma surface surf PPL alpha vertex:vert
				
			#include "UnityCG.cginc"
	
			struct appdata_t
			{
				float4 vertex : POSITION;
				float2 texcoord1 : TEXCOORD0;
				float2 texcoord2 : TEXCOORD1;
				fixed4 color : COLOR;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};
	
			struct Input
			{
				float4 vertex : SV_POSITION;
				half4 tc0 : TEXCOORD0;
				half4 tc1 : TEXCOORD1;
				fixed4 color : COLOR;
			};

			sampler2D _MainTex;
			sampler2D _MainBump;
			sampler2D _DetailTex;
			sampler2D _DetailBump;

			float4 _MainTex_ST;
			float4 _MainBump_ST;
			float4 _DetailTex_ST;
			float4 _DetailBump_ST;
			float4 _DetailTex_TexelSize;
			float4 _DetailBump_TexelSize;
			fixed4 _Color;
			fixed4 _Specular;
			half _Strength;
			half _Shininess;
				
			void vert (inout appdata_t v, out Input o)
			{
				o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
				o.tc0.xy = TRANSFORM_TEX(v.texcoord1, _MainTex);
				o.tc0.zw = TRANSFORM_TEX(v.texcoord1, _MainBump);
				o.tc1.xy = TRANSFORM_TEX(v.texcoord2 * _DetailTex_TexelSize.xy, _DetailTex);
				o.tc1.zw = TRANSFORM_TEX(v.texcoord2 * _DetailBump_TexelSize.xy, _DetailBump);
				o.color = v.color;
			}
				
			void surf (Input IN, inout SurfaceOutput o)
			{
				fixed4 col = tex2D(_MainTex, IN.tc0.xy);
				fixed4 detail = tex2D(_DetailTex, IN.tc1.xy);
				half3 normal = UnpackNormal(tex2D(_MainBump, IN.tc0.zw)) +
							   UnpackNormal(tex2D(_DetailBump, IN.tc1.zw));

				col.rgb = lerp(col.rgb, col.rgb * detail.rgb, detail.a * _Strength);
				col *= _Color * IN.color;
					
				o.Albedo = col.rgb;
				o.Normal = normalize(normal);
				o.Specular = _Specular.a;
				o.Gloss = _Shininess;
				o.Alpha = col.a;
			}

			half4 LightingPPL (SurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
			{
				half3 nNormal = normalize(s.Normal);
				half shininess = s.Gloss * 250.0 + 4.0;

			#ifndef USING_DIRECTIONAL_LIGHT
				lightDir = normalize(lightDir);
			#endif

				// Phong shading model
				half reflectiveFactor = max(0.0, dot(-viewDir, reflect(lightDir, nNormal)));

				// Blinn-Phong shading model
				//half reflectiveFactor = max(0.0, dot(nNormal, normalize(lightDir + viewDir)));
				
				half diffuseFactor = max(0.0, dot(nNormal, lightDir));
				half specularFactor = pow(reflectiveFactor, shininess) * s.Specular;

				half4 c;
				c.rgb = (s.Albedo * diffuseFactor + _Specular.rgb * specularFactor) * _LightColor0.rgb;
				c.rgb *= (atten * 2.0);
				c.a = s.Alpha;
				clip (c.a - 0.01);
				return c;
			}
		ENDCG
	}

	// SM 2.0
	SubShader
	{
		LOD 100

		Tags
		{
			"Queue" = "Transparent"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
		}
		
		Cull Off
		Lighting Off
		ZWrite Off
		Fog { Mode Off }
		Offset -1, -1
		Blend SrcAlpha OneMinusSrcAlpha

		CGPROGRAM
			#pragma surface surf PPL alpha vertex:vert
				
			#include "UnityCG.cginc"
	
			struct appdata_t
			{
				float4 vertex : POSITION;
				float2 texcoord1 : TEXCOORD0;
				float2 texcoord2 : TEXCOORD1;
				fixed4 color : COLOR;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};
	
			struct Input
			{
				float4 vertex : SV_POSITION;
				half2 tc0 : TEXCOORD0;
				half2 tc1 : TEXCOORD1;
				fixed4 color : COLOR;
			};

			sampler2D _MainTex;
			sampler2D _MainBump;
			sampler2D _DetailTex;
			sampler2D _DetailBump;

			float4 _MainTex_ST;
			float4 _DetailTex_ST;
			float4 _DetailTex_TexelSize;
			fixed4 _Color;
			fixed4 _Specular;
			half _Strength;
			half _Shininess;
				
			void vert (inout appdata_t v, out Input o)
			{
				o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
				o.tc0 = TRANSFORM_TEX(v.texcoord1, _MainTex);
				o.tc1 = TRANSFORM_TEX(v.texcoord2 * _DetailTex_TexelSize.xy, _DetailTex);
				o.color = v.color;
			}
				
			void surf (Input IN, inout SurfaceOutput o)
			{
				fixed4 col = tex2D(_MainTex, IN.tc0) * IN.color;
				fixed4 detail = tex2D(_DetailTex, IN.tc1) * _Color;
				half3 normal = UnpackNormal(tex2D(_MainBump, IN.tc0)) +
							   UnpackNormal(tex2D(_DetailBump, IN.tc1));

				col.rgb = lerp(col.rgb, col.rgb * detail.rgb, detail.a * _Strength);
					
				o.Albedo = col.rgb;
				o.Normal = normalize(normal);
				o.Specular = _Specular.a;
				o.Gloss = _Shininess;
				o.Alpha = col.a;
			}

			half4 LightingPPL (SurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
			{
				half3 nNormal = normalize(s.Normal);
				half shininess = s.Gloss * 250.0 + 4.0;

			#ifndef USING_DIRECTIONAL_LIGHT
				lightDir = normalize(lightDir);
			#endif

				// Phong shading model
				half reflectiveFactor = max(0.0, dot(-viewDir, reflect(lightDir, nNormal)));

				// Blinn-Phong shading model
				//half reflectiveFactor = max(0.0, dot(nNormal, normalize(lightDir + viewDir)));
				
				half diffuseFactor = max(0.0, dot(nNormal, lightDir));
				half specularFactor = pow(reflectiveFactor, shininess) * s.Specular;

				half4 c;
				c.rgb = (s.Albedo * diffuseFactor + _Specular.rgb * specularFactor) * _LightColor0.rgb;
				c.rgb *= (atten * 2.0);
				c.a = s.Alpha;
				return c;
			}
		ENDCG
	}
}
