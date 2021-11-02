// Unity built-in shader source. Copyright (c) 2016 Unity Technologies. MIT license (see license.txt)

using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace UnityEditor
{
    internal class StandardParticlesShaderGUI : ShaderGUI
    {
        public enum BlendMode
        {
            Opaque,
            Cutout,
            Fade,   // Old school alpha-blending mode, fresnel does not affect amount of transparency
            Transparent, // Physically plausible transparency mode, implemented as alpha pre-multiply
            Additive,
            Subtractive,
            Modulate
        }

        public enum FlipbookMode
        {
            Simple,
            Blended
        }

        public enum ColorMode
        {
            Multiply,
            Additive,
            Subtractive,
            Overlay,
            Color,
            Difference
        }

        private static class Styles
        {
            public static GUIContent albedoText = EditorGUIUtility.TrTextContent("Albedo", "Albedo (RGB) and Transparency (A).");
            public static GUIContent alphaCutoffText = EditorGUIUtility.TrTextContent("Alpha Cutoff", "Threshold for alpha cutoff.");
            public static GUIContent metallicMapText = EditorGUIUtility.TrTextContent("Metallic", "Metallic (R) and Smoothness (A).");
            public static GUIContent smoothnessText = EditorGUIUtility.TrTextContent("Smoothness", "Smoothness value.");
            public static GUIContent smoothnessScaleText = EditorGUIUtility.TrTextContent("Smoothness", "Smoothness scale factor.");
            public static GUIContent normalMapText = EditorGUIUtility.TrTextContent("Normal Map", "Normal Map.");
            public static GUIContent emissionText = EditorGUIUtility.TrTextContent("Color", "Emission (RGB).");

            public static GUIContent renderingMode = EditorGUIUtility.TrTextContent("Rendering Mode", "Determines the transparency and blending method for drawing the object to the screen.");
            public static GUIContent[] blendNames = Array.ConvertAll(Enum.GetNames(typeof(BlendMode)), item => new GUIContent(item));

            public static GUIContent colorMode = EditorGUIUtility.TrTextContent("Color Mode", "Determines the blending mode between the particle color and the texture albedo.");
            public static GUIContent[] colorNames = Array.ConvertAll(Enum.GetNames(typeof(ColorMode)), item => new GUIContent(item));

            public static GUIContent flipbookBlending = EditorGUIUtility.TrTextContent("Flip-Book Frame Blending", "Enables blending between the frames of animated texture sheets.");
            public static GUIContent twoSidedEnabled = EditorGUIUtility.TrTextContent("Two Sided", "Render both front and back faces of the particle geometry.");

            public static GUIContent distortionEnabled = EditorGUIUtility.TrTextContent("Distortion", "Use a grab pass and normal map to simulate refraction.");
            public static GUIContent distortionStrengthText = EditorGUIUtility.TrTextContent("Strength", "Distortion Strength.");
            public static GUIContent distortionBlendText = EditorGUIUtility.TrTextContent("Blend", "Weighting between albedo and grab pass.");

            public static GUIContent softParticlesEnabled = EditorGUIUtility.TrTextContent("Soft Particles", "Fade out particle geometry when it gets close to the surface of objects written into the depth buffer.");
            public static GUIContent softParticlesNearFadeDistanceText = EditorGUIUtility.TrTextContent("Near fade", "Soft Particles near fade distance.");
            public static GUIContent softParticlesFarFadeDistanceText = EditorGUIUtility.TrTextContent("Far fade", "Soft Particles far fade distance.");

            public static GUIContent cameraFadingEnabled = EditorGUIUtility.TrTextContent("Camera Fading", "Fade out particle geometry when it gets close to the camera.");
            public static GUIContent cameraNearFadeDistanceText = EditorGUIUtility.TrTextContent("Near fade", "Camera near fade distance.");
            public static GUIContent cameraFarFadeDistanceText = EditorGUIUtility.TrTextContent("Far fade", "Camera far fade distance.");

            public static GUIContent emissionEnabled = EditorGUIUtility.TrTextContent("Emission");

            public static GUIContent blendingOptionsText = EditorGUIUtility.TrTextContent("Blending Options");
            public static GUIContent mainOptionsText = EditorGUIUtility.TrTextContent("Main Options");
            public static GUIContent mapsOptionsText = EditorGUIUtility.TrTextContent("Maps");
            public static GUIContent requiredVertexStreamsText = EditorGUIUtility.TrTextContent("Required Vertex Streams");

            public static GUIContent streamPositionText = EditorGUIUtility.TrTextContent("Position (POSITION.xyz)");
            public static GUIContent streamNormalText = EditorGUIUtility.TrTextContent("Normal (NORMAL.xyz)");
            public static GUIContent streamColorText = EditorGUIUtility.TrTextContent("Color (COLOR.xyzw)");
            public static GUIContent streamColorInstancedText = EditorGUIUtility.TrTextContent("Color (INSTANCED0.xyzw)");
            public static GUIContent streamUVText = EditorGUIUtility.TrTextContent("UV (TEXCOORD0.xy)");
            public static GUIContent streamUV2Text = EditorGUIUtility.TrTextContent("UV2 (TEXCOORD0.zw)");
            public static GUIContent streamAnimBlendText = EditorGUIUtility.TrTextContent("AnimBlend (TEXCOORD1.x)");
            public static GUIContent streamAnimFrameText = EditorGUIUtility.TrTextContent("AnimFrame (INSTANCED1.x)");
            public static GUIContent streamTangentText = EditorGUIUtility.TrTextContent("Tangent (TANGENT.xyzw)");

            public static GUIContent streamApplyToAllSystemsText = EditorGUIUtility.TrTextContent("Apply to Systems", "Apply the vertex stream layout to all Particle Systems using this material");

            public static string undoApplyCustomVertexStreams = L10n.Tr("Apply custom vertex streams from material");
        }

        MaterialProperty blendMode = null;
        MaterialProperty colorMode = null;
        MaterialProperty flipbookMode = null;
        MaterialProperty cullMode = null;
        MaterialProperty distortionEnabled = null;
        MaterialProperty distortionStrength = null;
        MaterialProperty distortionBlend = null;
        MaterialProperty albedoMap = null;
        MaterialProperty albedoColor = null;
        MaterialProperty alphaCutoff = null;
        MaterialProperty metallicMap = null;
        MaterialProperty metallic = null;
        MaterialProperty smoothness = null;
        MaterialProperty bumpScale = null;
        MaterialProperty bumpMap = null;
        MaterialProperty emissionEnabled = null;
        MaterialProperty emissionColorForRendering = null;
        MaterialProperty emissionMap = null;
        MaterialProperty softParticlesEnabled = null;
        MaterialProperty cameraFadingEnabled = null;
        MaterialProperty softParticlesNearFadeDistance = null;
        MaterialProperty softParticlesFarFadeDistance = null;
        MaterialProperty cameraNearFadeDistance = null;
        MaterialProperty cameraFarFadeDistance = null;

        MaterialEditor m_MaterialEditor;

        List<ParticleSystemRenderer> m_RenderersUsingThisMaterial = new List<ParticleSystemRenderer>();

        bool m_FirstTimeApply = true;

        public void FindProperties(MaterialProperty[] props)
        {
            blendMode = FindProperty("_Mode", props);
            colorMode = FindProperty("_ColorMode", props, false);
            flipbookMode = FindProperty("_FlipbookMode", props);
            cullMode = FindProperty("_Cull", props);
            distortionEnabled = FindProperty("_DistortionEnabled", props);
            distortionStrength = FindProperty("_DistortionStrength", props);
            distortionBlend = FindProperty("_DistortionBlend", props);
            albedoMap = FindProperty("_MainTex", props);
            albedoColor = FindProperty("_Color", props);
            alphaCutoff = FindProperty("_Cutoff", props);
            metallicMap = FindProperty("_MetallicGlossMap", props, false);
            metallic = FindProperty("_Metallic", props, false);
            smoothness = FindProperty("_Glossiness", props, false);
            bumpScale = FindProperty("_BumpScale", props);
            bumpMap = FindProperty("_BumpMap", props);
            emissionEnabled = FindProperty("_EmissionEnabled", props);
            emissionColorForRendering = FindProperty("_EmissionColor", props);
            emissionMap = FindProperty("_EmissionMap", props);
            softParticlesEnabled = FindProperty("_SoftParticlesEnabled", props);
            cameraFadingEnabled = FindProperty("_CameraFadingEnabled", props);
            softParticlesNearFadeDistance = FindProperty("_SoftParticlesNearFadeDistance", props);
            softParticlesFarFadeDistance = FindProperty("_SoftParticlesFarFadeDistance", props);
            cameraNearFadeDistance = FindProperty("_CameraNearFadeDistance", props);
            cameraFarFadeDistance = FindProperty("_CameraFarFadeDistance", props);
        }

        public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] props)
        {
            FindProperties(props); // MaterialProperties can be animated so we do not cache them but fetch them every event to ensure animated values are updated correctly
            m_MaterialEditor = materialEditor;
            Material material = materialEditor.target as Material;

            if (m_FirstTimeApply)
            {
                CacheRenderersUsingThisMaterial(material);
                m_FirstTimeApply = false;
            }

            ShaderPropertiesGUI(material);
        }

        public void ShaderPropertiesGUI(Material material)
        {
            // Use default labelWidth
            EditorGUIUtility.labelWidth = 0f;

            {
                GUILayout.Label(Styles.blendingOptionsText, EditorStyles.boldLabel);

                BlendModePopup();
                ColorModePopup();

                EditorGUILayout.Space();
                GUILayout.Label(Styles.mainOptionsText, EditorStyles.boldLabel);

                FlipbookBlendingPopup();
                TwoSidedPopup(material);
                FadingPopup(material);
                DistortionPopup(material);

                EditorGUILayout.Space();
                GUILayout.Label(Styles.mapsOptionsText, EditorStyles.boldLabel);

                DoAlbedoArea(material);
                DoSpecularMetallicArea(material);
                DoNormalMapArea(material);
                DoEmissionArea(material);

                if (!flipbookMode.hasMixedValue && (FlipbookMode)flipbookMode.floatValue != FlipbookMode.Blended)
                {
                    EditorGUI.BeginChangeCheck();
                    m_MaterialEditor.TextureScaleOffsetProperty(albedoMap);
                    if (EditorGUI.EndChangeCheck())
                        emissionMap.textureScaleAndOffset = albedoMap.textureScaleAndOffset; // Apply the main texture scale and offset to the emission texture as well, for Enlighten's sake
                }
            }

            EditorGUILayout.Space();

            GUILayout.Label(Styles.requiredVertexStreamsText, EditorStyles.boldLabel);
            DoVertexStreamsArea(material);
        }

        public override void OnClosed(Material material)
        {
            material.SetShaderPassEnabled("Always", true);
        }

        public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
        {
            // Sync the lighting flag for the unlit shader
            if (newShader.name.Contains("Unlit"))
                material.SetFloat("_LightingEnabled", 0.0f);
            else
                material.SetFloat("_LightingEnabled", 1.0f);

            // _Emission property is lost after assigning Standard shader to the material
            // thus transfer it before assigning the new shader
            if (material.HasProperty("_Emission"))
            {
                material.SetColor("_EmissionColor", material.GetColor("_Emission"));
            }

            base.AssignNewShaderToMaterial(material, oldShader, newShader);

            if (oldShader == null || !oldShader.name.Contains("Legacy Shaders/"))
                return;

            BlendMode blendMode = BlendMode.Opaque;
            if (oldShader.name.Contains("/Transparent/Cutout/"))
            {
                blendMode = BlendMode.Cutout;
            }
            else if (oldShader.name.Contains("/Transparent/"))
            {
                // NOTE: legacy shaders did not provide physically based transparency
                // therefore Fade mode
                blendMode = BlendMode.Fade;
            }
            material.SetFloat("_Mode", (float)blendMode);
        }

        void BlendModePopup()
        {
            EditorGUI.showMixedValue = blendMode.hasMixedValue;
            var mode = (BlendMode)blendMode.floatValue;

            EditorGUI.BeginChangeCheck();
            mode = (BlendMode)EditorGUILayout.Popup(Styles.renderingMode, (int)mode, Styles.blendNames);
            if (EditorGUI.EndChangeCheck())
            {
                m_MaterialEditor.RegisterPropertyChangeUndo("Rendering Mode");
                blendMode.floatValue = (float)mode;
            }

            EditorGUI.showMixedValue = false;
        }

        void ColorModePopup()
        {
            if (colorMode != null)
            {
                EditorGUI.showMixedValue = colorMode.hasMixedValue;
                var mode = (ColorMode)colorMode.floatValue;

                EditorGUI.BeginChangeCheck();
                mode = (ColorMode)EditorGUILayout.Popup(Styles.colorMode, (int)mode, Styles.colorNames);
                if (EditorGUI.EndChangeCheck())
                {
                    m_MaterialEditor.RegisterPropertyChangeUndo("Color Mode");
                    colorMode.floatValue = (float)mode;
                }

                EditorGUI.showMixedValue = false;
            }
        }

        void FlipbookBlendingPopup()
        {
            EditorGUI.showMixedValue = flipbookMode.hasMixedValue;
            var enabled = (flipbookMode.floatValue == (float)FlipbookMode.Blended);

            EditorGUI.BeginChangeCheck();
            enabled = EditorGUILayout.Toggle(Styles.flipbookBlending, enabled);
            if (EditorGUI.EndChangeCheck())
            {
                m_MaterialEditor.RegisterPropertyChangeUndo("Flip-Book Mode");
                flipbookMode.floatValue = enabled ? (float)FlipbookMode.Blended : (float)FlipbookMode.Simple;
            }

            EditorGUI.showMixedValue = false;
        }

        void TwoSidedPopup(Material material)
        {
            EditorGUI.showMixedValue = cullMode.hasMixedValue;
            var enabled = (cullMode.floatValue == (float)UnityEngine.Rendering.CullMode.Off);

            EditorGUI.BeginChangeCheck();
            enabled = EditorGUILayout.Toggle(Styles.twoSidedEnabled, enabled);
            if (EditorGUI.EndChangeCheck())
            {
                m_MaterialEditor.RegisterPropertyChangeUndo("Two Sided Enabled");
                cullMode.floatValue = enabled ? (float)UnityEngine.Rendering.CullMode.Off : (float)UnityEngine.Rendering.CullMode.Back;
            }

            EditorGUI.showMixedValue = false;
        }

        void FadingPopup(Material material)
        {
            // Z write doesn't work with fading
            bool hasZWrite = (material.GetFloat("_ZWrite") > 0.0f);
            if (!hasZWrite)
            {
                // Soft Particles
                {
                    EditorGUI.showMixedValue = softParticlesEnabled.hasMixedValue;
                    var enabled = softParticlesEnabled.floatValue;

                    EditorGUI.BeginChangeCheck();
                    enabled = EditorGUILayout.Toggle(Styles.softParticlesEnabled, enabled != 0.0f) ? 1.0f : 0.0f;
                    if (EditorGUI.EndChangeCheck())
                    {
                        m_MaterialEditor.RegisterPropertyChangeUndo("Soft Particles Enabled");
                        softParticlesEnabled.floatValue = enabled;
                    }

                    if (enabled != 0.0f)
                    {
                        int indentation = 2;
                        m_MaterialEditor.ShaderProperty(softParticlesNearFadeDistance, Styles.softParticlesNearFadeDistanceText, indentation);
                        m_MaterialEditor.ShaderProperty(softParticlesFarFadeDistance, Styles.softParticlesFarFadeDistanceText, indentation);
                    }
                }

                // Camera Fading
                {
                    EditorGUI.showMixedValue = cameraFadingEnabled.hasMixedValue;
                    var enabled = cameraFadingEnabled.floatValue;

                    EditorGUI.BeginChangeCheck();
                    enabled = EditorGUILayout.Toggle(Styles.cameraFadingEnabled, enabled != 0.0f) ? 1.0f : 0.0f;
                    if (EditorGUI.EndChangeCheck())
                    {
                        m_MaterialEditor.RegisterPropertyChangeUndo("Camera Fading Enabled");
                        cameraFadingEnabled.floatValue = enabled;
                    }

                    if (enabled != 0.0f)
                    {
                        int indentation = 2;
                        m_MaterialEditor.ShaderProperty(cameraNearFadeDistance, Styles.cameraNearFadeDistanceText, indentation);
                        m_MaterialEditor.ShaderProperty(cameraFarFadeDistance, Styles.cameraFarFadeDistanceText, indentation);
                    }
                }

                EditorGUI.showMixedValue = false;
            }
        }

        void DistortionPopup(Material material)
        {
            // Z write doesn't work with distortion
            bool hasZWrite = (material.GetFloat("_ZWrite") > 0.0f);
            if (!hasZWrite)
            {
                EditorGUI.showMixedValue = distortionEnabled.hasMixedValue;
                var enabled = (distortionEnabled.floatValue != 0.0f);

                EditorGUI.BeginChangeCheck();
                enabled = EditorGUILayout.Toggle(Styles.distortionEnabled, enabled);
                if (EditorGUI.EndChangeCheck())
                {
                    m_MaterialEditor.RegisterPropertyChangeUndo("Distortion Enabled");
                    distortionEnabled.floatValue = enabled ? 1.0f : 0.0f;
                }

                if (enabled)
                {
                    int indentation = 2;
                    m_MaterialEditor.ShaderProperty(distortionStrength, Styles.distortionStrengthText, indentation);
                    m_MaterialEditor.ShaderProperty(distortionBlend, Styles.distortionBlendText, indentation);
                }

                EditorGUI.showMixedValue = false;
            }
        }

        void DoAlbedoArea(Material material)
        {
            m_MaterialEditor.TexturePropertyWithHDRColor(Styles.albedoText, albedoMap, albedoColor, true);
            if (((BlendMode)material.GetFloat("_Mode") == BlendMode.Cutout))
            {
                m_MaterialEditor.ShaderProperty(alphaCutoff, Styles.alphaCutoffText, MaterialEditor.kMiniTextureFieldLabelIndentLevel);
            }
        }

        void DoEmissionArea(Material material)
        {
            // Emission
            EditorGUI.showMixedValue = emissionEnabled.hasMixedValue;
            var enabled = (emissionEnabled.floatValue != 0.0f);

            EditorGUI.BeginChangeCheck();
            enabled = EditorGUILayout.Toggle(Styles.emissionEnabled, enabled);
            if (EditorGUI.EndChangeCheck())
            {
                m_MaterialEditor.RegisterPropertyChangeUndo("Emission Enabled");
                emissionEnabled.floatValue = enabled ? 1.0f : 0.0f;
            }

            if (enabled)
            {
                bool hadEmissionTexture = emissionMap.textureValue != null;

                // Texture and HDR color controls
                m_MaterialEditor.TexturePropertyWithHDRColor(Styles.emissionText, emissionMap, emissionColorForRendering, false);

                // If texture was assigned and color was black set color to white
                float brightness = emissionColorForRendering.colorValue.maxColorComponent;
                if (emissionMap.textureValue != null && !hadEmissionTexture && brightness <= 0f)
                    emissionColorForRendering.colorValue = Color.white;
            }
        }

        void DoSpecularMetallicArea(Material material)
        {
            if (metallicMap == null)
                return;

            bool useLighting = (material.GetFloat("_LightingEnabled") > 0.0f);
            if (useLighting)
            {
                bool hasGlossMap = metallicMap.textureValue != null;
                m_MaterialEditor.TexturePropertySingleLine(Styles.metallicMapText, metallicMap, hasGlossMap ? null : metallic);

                int indentation = 2; // align with labels of texture properties
                bool showSmoothnessScale = hasGlossMap;
                m_MaterialEditor.ShaderProperty(smoothness, showSmoothnessScale ? Styles.smoothnessScaleText : Styles.smoothnessText, indentation);
            }
        }

        void DoNormalMapArea(Material material)
        {
            bool hasZWrite = (material.GetFloat("_ZWrite") > 0.0f);
            bool useLighting = (material.GetFloat("_LightingEnabled") > 0.0f);
            bool useDistortion = (material.GetFloat("_DistortionEnabled") > 0.0f) && !hasZWrite;
            if (useLighting || useDistortion)
            {
                m_MaterialEditor.TexturePropertySingleLine(Styles.normalMapText, bumpMap, bumpMap.textureValue != null ? bumpScale : null);
            }
        }

        void DoVertexStreamsArea(Material material)
        {
            // Display list of streams required to make this shader work
            bool useLighting = (material.GetFloat("_LightingEnabled") > 0.0f);
            bool useFlipbookBlending = (material.GetFloat("_FlipbookMode") > 0.0f);
            bool useTangents = useLighting && material.GetTexture("_BumpMap");

            bool useGPUInstancing = ShaderUtil.HasProceduralInstancing(material.shader);
            if (useGPUInstancing && m_RenderersUsingThisMaterial.Count > 0)
            {
                if (!m_RenderersUsingThisMaterial[0].enableGPUInstancing || m_RenderersUsingThisMaterial[0].renderMode != ParticleSystemRenderMode.Mesh)
                    useGPUInstancing = false;
            }

            GUILayout.Label(Styles.streamPositionText, EditorStyles.label);

            if (useLighting)
                GUILayout.Label(Styles.streamNormalText, EditorStyles.label);

            GUILayout.Label(useGPUInstancing ? Styles.streamColorInstancedText : Styles.streamColorText, EditorStyles.label);
            GUILayout.Label(Styles.streamUVText, EditorStyles.label);

            if (useTangents)
                GUILayout.Label(Styles.streamTangentText, EditorStyles.label);

            if (useGPUInstancing)
            {
                GUILayout.Label(Styles.streamAnimFrameText, EditorStyles.label);
            }
            else if (useFlipbookBlending && !useGPUInstancing)
            {
                GUILayout.Label(Styles.streamUV2Text, EditorStyles.label);
                GUILayout.Label(Styles.streamAnimBlendText, EditorStyles.label);
            }

            // Build the list of expected vertex streams
            List<ParticleSystemVertexStream> streams = new List<ParticleSystemVertexStream>();
            streams.Add(ParticleSystemVertexStream.Position);

            if (useLighting)
                streams.Add(ParticleSystemVertexStream.Normal);

            streams.Add(ParticleSystemVertexStream.Color);
            streams.Add(ParticleSystemVertexStream.UV);

            if (useTangents)
                streams.Add(ParticleSystemVertexStream.Tangent);

            List<ParticleSystemVertexStream> instancedStreams = new List<ParticleSystemVertexStream>(streams);

            if (useGPUInstancing)
            {
                instancedStreams.Add(ParticleSystemVertexStream.AnimFrame);
            }
            if (useFlipbookBlending)
            {
                streams.Add(ParticleSystemVertexStream.UV2);
                streams.Add(ParticleSystemVertexStream.AnimBlend);
            }

            // Set the streams on all systems using this material
            if (GUILayout.Button(Styles.streamApplyToAllSystemsText, EditorStyles.miniButton, GUILayout.ExpandWidth(false)))
            {
                Undo.RecordObjects(m_RenderersUsingThisMaterial.Where(r => r != null).ToArray(), Styles.undoApplyCustomVertexStreams);

                foreach (ParticleSystemRenderer renderer in m_RenderersUsingThisMaterial)
                {
                    if (renderer != null)
                    {
                        if (useGPUInstancing && renderer.renderMode == ParticleSystemRenderMode.Mesh && renderer.supportsMeshInstancing)
                            renderer.SetActiveVertexStreams(instancedStreams);
                        else
                            renderer.SetActiveVertexStreams(streams);
                    }
                }
            }

            // Display a warning if any renderers have incorrect vertex streams
            string Warnings = "";
            List<ParticleSystemVertexStream> rendererStreams = new List<ParticleSystemVertexStream>();
            foreach (ParticleSystemRenderer renderer in m_RenderersUsingThisMaterial)
            {
                if (renderer != null)
                {
                    renderer.GetActiveVertexStreams(rendererStreams);

                    bool streamsValid;
                    if (useGPUInstancing && renderer.renderMode == ParticleSystemRenderMode.Mesh && renderer.supportsMeshInstancing)
                        streamsValid = CompareVertexStreams(rendererStreams, instancedStreams);
                    else
                        streamsValid = CompareVertexStreams(rendererStreams, streams);

                    if (!streamsValid)
                        Warnings += "  " + renderer.name + "\n";
                }
            }
            if (Warnings != "")
            {
                EditorGUILayout.HelpBox("The following Particle System Renderers are using this material with incorrect Vertex Streams:\n" + Warnings + "Use the Apply to Systems button to fix this", MessageType.Warning, true);
            }

            EditorGUILayout.Space();
        }

        private static bool CompareVertexStreams(IEnumerable<ParticleSystemVertexStream> a, IEnumerable<ParticleSystemVertexStream> b)
        {
            var differenceA = a.Except(b);
            var differenceB = b.Except(a);
            var difference = differenceA.Union(differenceB).Distinct();

            if (!difference.Any())
                return true;

            // If normals are the only difference, ignore them, because the default particle streams include normals, to make it easy for users to switch between lit and unlit
            if (difference.Count() == 1)
            {
                if (difference.First() == ParticleSystemVertexStream.Normal)
                    return true;
            }

            return false;
        }

        public static void SetupMaterialWithBlendMode(Material material, BlendMode blendMode)
        {
            switch (blendMode)
            {
                case BlendMode.Opaque:
                    material.SetOverrideTag("RenderType", "");
                    material.SetFloat("_BlendOp", (float)UnityEngine.Rendering.BlendOp.Add);
                    material.SetFloat("_SrcBlend", (float)UnityEngine.Rendering.BlendMode.One);
                    material.SetFloat("_DstBlend", (float)UnityEngine.Rendering.BlendMode.Zero);
                    material.SetFloat("_ZWrite", 1.0f);
                    material.DisableKeyword("_ALPHATEST_ON");
                    material.DisableKeyword("_ALPHABLEND_ON");
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.DisableKeyword("_ALPHAMODULATE_ON");
                    material.renderQueue = -1;
                    break;
                case BlendMode.Cutout:
                    material.SetOverrideTag("RenderType", "TransparentCutout");
                    material.SetFloat("_BlendOp", (float)UnityEngine.Rendering.BlendOp.Add);
                    material.SetFloat("_SrcBlend", (float)UnityEngine.Rendering.BlendMode.One);
                    material.SetFloat("_DstBlend", (float)UnityEngine.Rendering.BlendMode.Zero);
                    material.SetFloat("_ZWrite", 1.0f);
                    material.EnableKeyword("_ALPHATEST_ON");
                    material.DisableKeyword("_ALPHABLEND_ON");
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.DisableKeyword("_ALPHAMODULATE_ON");
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.AlphaTest;
                    break;
                case BlendMode.Fade:
                    material.SetOverrideTag("RenderType", "Transparent");
                    material.SetFloat("_BlendOp", (float)UnityEngine.Rendering.BlendOp.Add);
                    material.SetFloat("_SrcBlend", (float)UnityEngine.Rendering.BlendMode.SrcAlpha);
                    material.SetFloat("_DstBlend", (float)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                    material.SetFloat("_ZWrite", 0.0f);
                    material.DisableKeyword("_ALPHATEST_ON");
                    material.EnableKeyword("_ALPHABLEND_ON");
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.DisableKeyword("_ALPHAMODULATE_ON");
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    break;
                case BlendMode.Transparent:
                    material.SetOverrideTag("RenderType", "Transparent");
                    material.SetFloat("_BlendOp", (float)UnityEngine.Rendering.BlendOp.Add);
                    material.SetFloat("_SrcBlend", (float)UnityEngine.Rendering.BlendMode.One);
                    material.SetFloat("_DstBlend", (float)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                    material.SetFloat("_ZWrite", 0.0f);
                    material.DisableKeyword("_ALPHATEST_ON");
                    material.DisableKeyword("_ALPHABLEND_ON");
                    material.EnableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.DisableKeyword("_ALPHAMODULATE_ON");
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    break;
                case BlendMode.Additive:
                    material.SetOverrideTag("RenderType", "Transparent");
                    material.SetFloat("_BlendOp", (float)UnityEngine.Rendering.BlendOp.Add);
                    material.SetFloat("_SrcBlend", (float)UnityEngine.Rendering.BlendMode.SrcAlpha);
                    material.SetFloat("_DstBlend", (float)UnityEngine.Rendering.BlendMode.One);
                    material.SetFloat("_ZWrite", 0.0f);
                    material.DisableKeyword("_ALPHATEST_ON");
                    material.EnableKeyword("_ALPHABLEND_ON");
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.DisableKeyword("_ALPHAMODULATE_ON");
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    break;
                case BlendMode.Subtractive:
                    material.SetOverrideTag("RenderType", "Transparent");
                    material.SetFloat("_BlendOp", (float)UnityEngine.Rendering.BlendOp.ReverseSubtract);
                    material.SetFloat("_SrcBlend", (float)UnityEngine.Rendering.BlendMode.SrcAlpha);
                    material.SetFloat("_DstBlend", (float)UnityEngine.Rendering.BlendMode.One);
                    material.SetFloat("_ZWrite", 0.0f);
                    material.DisableKeyword("_ALPHATEST_ON");
                    material.EnableKeyword("_ALPHABLEND_ON");
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.DisableKeyword("_ALPHAMODULATE_ON");
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    break;
                case BlendMode.Modulate:
                    material.SetOverrideTag("RenderType", "Transparent");
                    material.SetFloat("_BlendOp", (float)UnityEngine.Rendering.BlendOp.Add);
                    material.SetFloat("_SrcBlend", (float)UnityEngine.Rendering.BlendMode.DstColor);
                    material.SetFloat("_DstBlend", (float)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                    material.SetFloat("_ZWrite", 0.0f);
                    material.DisableKeyword("_ALPHATEST_ON");
                    material.DisableKeyword("_ALPHABLEND_ON");
                    material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                    material.EnableKeyword("_ALPHAMODULATE_ON");
                    material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
                    break;
            }
        }

        public static void SetupMaterialWithColorMode(Material material, ColorMode colorMode)
        {
            switch (colorMode)
            {
                case ColorMode.Multiply:
                    material.DisableKeyword("_COLOROVERLAY_ON");
                    material.DisableKeyword("_COLORCOLOR_ON");
                    material.DisableKeyword("_COLORADDSUBDIFF_ON");
                    break;
                case ColorMode.Overlay:
                    material.DisableKeyword("_COLORCOLOR_ON");
                    material.DisableKeyword("_COLORADDSUBDIFF_ON");
                    material.EnableKeyword("_COLOROVERLAY_ON");
                    break;
                case ColorMode.Color:
                    material.DisableKeyword("_COLOROVERLAY_ON");
                    material.DisableKeyword("_COLORADDSUBDIFF_ON");
                    material.EnableKeyword("_COLORCOLOR_ON");
                    break;
                case ColorMode.Difference:
                    material.DisableKeyword("_COLOROVERLAY_ON");
                    material.DisableKeyword("_COLORCOLOR_ON");
                    material.EnableKeyword("_COLORADDSUBDIFF_ON");
                    material.SetVector("_ColorAddSubDiff", new Vector4(-1.0f, 1.0f, 0.0f, 0.0f));
                    break;
                case ColorMode.Additive:
                    material.DisableKeyword("_COLOROVERLAY_ON");
                    material.DisableKeyword("_COLORCOLOR_ON");
                    material.EnableKeyword("_COLORADDSUBDIFF_ON");
                    material.SetVector("_ColorAddSubDiff", new Vector4(1.0f, 0.0f, 0.0f, 0.0f));
                    break;
                case ColorMode.Subtractive:
                    material.DisableKeyword("_COLOROVERLAY_ON");
                    material.DisableKeyword("_COLORCOLOR_ON");
                    material.EnableKeyword("_COLORADDSUBDIFF_ON");
                    material.SetVector("_ColorAddSubDiff", new Vector4(-1.0f, 0.0f, 0.0f, 0.0f));
                    break;
            }
        }

        void SetMaterialKeywords(Material material)
        {
            // Z write doesn't work with distortion/fading
            bool hasZWrite = (material.GetFloat("_ZWrite") > 0.0f);

            // Lit shader?
            bool useLighting = (material.GetFloat("_LightingEnabled") > 0.0f);

            // Note: keywords must be based on Material value not on MaterialProperty due to multi-edit & material animation
            // (MaterialProperty value might come from renderer material property block)
            bool useDistortion = !hasZWrite && (material.GetFloat("_DistortionEnabled") > 0.0f);
            SetKeyword(material, "_NORMALMAP", (useLighting || useDistortion) && material.GetTexture("_BumpMap"));
            SetKeyword(material, "_METALLICGLOSSMAP", useLighting && material.GetTexture("_MetallicGlossMap"));

            material.globalIlluminationFlags = MaterialGlobalIlluminationFlags.None;
            SetKeyword(material, "_EMISSION", material.GetFloat("_EmissionEnabled") > 0.0f);

            // Set the define for flipbook blending
            bool useFlipbookBlending = (material.GetFloat("_FlipbookMode") > 0.0f);
            SetKeyword(material, "_REQUIRE_UV2", useFlipbookBlending);

            // Clamp fade distances
            bool useSoftParticles = (material.GetFloat("_SoftParticlesEnabled") > 0.0f);
            bool useCameraFading = (material.GetFloat("_CameraFadingEnabled") > 0.0f);
            float softParticlesNearFadeDistance = material.GetFloat("_SoftParticlesNearFadeDistance");
            float softParticlesFarFadeDistance = material.GetFloat("_SoftParticlesFarFadeDistance");
            float cameraNearFadeDistance = material.GetFloat("_CameraNearFadeDistance");
            float cameraFarFadeDistance = material.GetFloat("_CameraFarFadeDistance");

            if (softParticlesNearFadeDistance < 0.0f)
            {
                softParticlesNearFadeDistance = 0.0f;
                material.SetFloat("_SoftParticlesNearFadeDistance", 0.0f);
            }
            if (softParticlesFarFadeDistance < 0.0f)
            {
                softParticlesFarFadeDistance = 0.0f;
                material.SetFloat("_SoftParticlesFarFadeDistance", 0.0f);
            }
            if (cameraNearFadeDistance < 0.0f)
            {
                cameraNearFadeDistance = 0.0f;
                material.SetFloat("_CameraNearFadeDistance", 0.0f);
            }
            if (cameraFarFadeDistance < 0.0f)
            {
                cameraFarFadeDistance = 0.0f;
                material.SetFloat("_CameraFarFadeDistance", 0.0f);
            }

            // Set the define for fading
            bool useFading = (useSoftParticles || useCameraFading) && !hasZWrite;
            SetKeyword(material, "_FADING_ON", useFading);
            if (useSoftParticles)
                material.SetVector("_SoftParticleFadeParams", new Vector4(softParticlesNearFadeDistance, 1.0f / (softParticlesFarFadeDistance - softParticlesNearFadeDistance), 0.0f, 0.0f));
            else
                material.SetVector("_SoftParticleFadeParams", new Vector4(0.0f, 0.0f, 0.0f, 0.0f));
            if (useCameraFading)
                material.SetVector("_CameraFadeParams", new Vector4(cameraNearFadeDistance, 1.0f / (cameraFarFadeDistance - cameraNearFadeDistance), 0.0f, 0.0f));
            else
                material.SetVector("_CameraFadeParams", new Vector4(0.0f, Mathf.Infinity, 0.0f, 0.0f));

            // Set the define for distortion + grabpass
            SetKeyword(material, "EFFECT_BUMP", useDistortion);
            material.SetShaderPassEnabled("Always", useDistortion);
            if (useDistortion)
                material.SetFloat("_DistortionStrengthScaled", material.GetFloat("_DistortionStrength") * 0.1f);   // more friendly number scale than 1 unit per size of the screen
        }

        override public void ValidateMaterial(Material material)
        {
            SetupMaterialWithBlendMode(material, (BlendMode)material.GetFloat("_Mode"));
            if (material.HasProperty("_ColorMode"))
                SetupMaterialWithColorMode(material, (ColorMode)material.GetFloat("_ColorMode"));
            SetMaterialKeywords(material);
        }

        void CacheRenderersUsingThisMaterial(Material material)
        {
            m_RenderersUsingThisMaterial.Clear();

            ParticleSystemRenderer[] renderers = Resources.FindObjectsOfTypeAll(typeof(ParticleSystemRenderer)) as ParticleSystemRenderer[];
            foreach (ParticleSystemRenderer renderer in renderers)
            {
                var go = renderer.gameObject;
                if (go.hideFlags == HideFlags.NotEditable || go.hideFlags == HideFlags.HideAndDontSave)
                    continue;

                if (renderer.sharedMaterial == material)
                    m_RenderersUsingThisMaterial.Add(renderer);
            }
        }

        static void SetKeyword(Material m, string keyword, bool state)
        {
            if (state)
                m.EnableKeyword(keyword);
            else
                m.DisableKeyword(keyword);
        }
    }
} // namespace UnityEditor
