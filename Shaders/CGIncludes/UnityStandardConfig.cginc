#ifndef UNITY_STANDARD_CONFIG_INCLUDED
#define UNITY_STANDARD_CONFIG_INCLUDED

// Define Specular cubemap constants
#ifndef UNITY_SPECCUBE_LOD_EXPONENT
#define UNITY_SPECCUBE_LOD_EXPONENT (1.5)
#endif
#ifndef UNITY_SPECCUBE_LOD_STEPS
#define UNITY_SPECCUBE_LOD_STEPS (7) // TODO: proper fix for different cubemap resolution needed. My assumptions were actually wrong!
#endif

// Energy conservation for Specular workflow is Monochrome. For instance: Red metal will make diffuse Black not Cyan
#ifndef UNITY_CONSERVE_ENERGY
#define UNITY_CONSERVE_ENERGY 1
#endif
#ifndef UNITY_CONSERVE_ENERGY_MONOCHROME
#define UNITY_CONSERVE_ENERGY_MONOCHROME 1
#endif

// High end platforms support Box Projection and Blending
#ifndef UNITY_SPECCUBE_BOX_PROJECTION
#define UNITY_SPECCUBE_BOX_PROJECTION ( !defined(SHADER_API_MOBILE) && (SHADER_TARGET >= 30) )
#endif
#ifndef UNITY_SPECCUBE_BLENDING
#define UNITY_SPECCUBE_BLENDING ( !defined(SHADER_API_MOBILE) && (SHADER_TARGET >= 30) )
#endif

#ifndef UNITY_SAMPLE_FULL_SH_PER_PIXEL
#define UNITY_SAMPLE_FULL_SH_PER_PIXEL 0
#endif

#ifndef UNITY_GLOSS_MATCHES_MARMOSET_TOOLBAG2
#define UNITY_GLOSS_MATCHES_MARMOSET_TOOLBAG2 1
#endif
#ifndef UNITY_BRDF_GGX
#define UNITY_BRDF_GGX 0
#endif

// Orthnormalize Tangent Space basis per-pixel
// Necessary to support high-quality normal-maps. Compatible with Maya and Marmoset.
// However xNormal expects oldschool non-orthnormalized basis - essentially preventing good looking normal-maps :(
// Due to the fact that xNormal is probably _the most used tool to bake out normal-maps today_ we have to stick to old ways for now.
// 
// Disabled by default, until xNormal has an option to bake proper normal-maps.
#ifndef UNITY_TANGENT_ORTHONORMALIZE
#define UNITY_TANGENT_ORTHONORMALIZE 0
#endif

#ifndef UNITY_ENABLE_REFLECTION_BUFFERS
#define UNITY_ENABLE_REFLECTION_BUFFERS 1
#endif

// Some extra optimizations

// On PVR GPU there is an extra cost for dependent texture readback, especially hitting texCUBElod
// These defines should be set as keywords or smth (at runtime depending on GPU).
// for now we keep the code but disable it, as we want more optimization/cleanup passes

#ifndef UNITY_OPTIMIZE_TEXCUBELOD
	#define UNITY_OPTIMIZE_TEXCUBELOD 0
#endif

// Simplified Standard Shader is off by default and should not be used for Legacy Shaders
#ifndef UNITY_STANDARD_SIMPLE
	#define UNITY_STANDARD_SIMPLE 0
#endif



#endif // UNITY_STANDARD_CONFIG_INCLUDED
