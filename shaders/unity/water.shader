
Shader "Water" {
	Properties{
		[Header(Features)]
		[Toggle(_PARALLAXMAP)] _UseDisplacement("Displacement", Float) = 0
		[Toggle(_SPECGLOSSMAP)] _UseMeanSky("Mean sky radiance", Float) = 0
		[Toggle(GRAIN)] _UseReflection("Reflections", Float) = 0
		[Toggle(FXAA)] _UseFoam("Foam", Float) = 0
		[Toggle(BLOOM)] _UsePhong("Blinn Phong", Float) = 0

		[Header(Basic settings)]
		_AmbientDensity("Ambient Intensity",  Range(0, 1)) = 0.15
		_DiffuseDensity("Diffuse Intensity",  Range(0, 1)) = 0.1
		_SurfaceColor("Surface Color", Color) = (0.0078, 0.5176, 0.7)
		_ShoreColor("Shore Tint Color", Color) = (0.0078, 0.5176, 0.7)
		_DepthColor("Deep Color", Color) = (0.0039, 0.00196, 0.145)
		[NoScaleOffset]_NormalTexture("Normal Texture", 2D) = "white" {}
		_NormalIntensity("Normal Intensity",  Range(0, 1)) = 0.5
		_TextureTiling("Texture Tiling", Float) = 1
		_WindDirection("Wind Direction", Vector) = (3,5,0)

		[Header(Displacement settings)]
		[NoScaleOffset]_HeightTexture("Height Texture", 2D) = "white" {}
		_HeightIntensity("Height Intensity",  Range(0, 1)) = 0.5
		_WaveTiling("Wave Tiling", Float) = 1
		_WaveAmplitudeFactor("Wave Amplitude Factor",Float) = 1.0
		_WaveSteepness("Wave Steepness", Range(0, 1)) = 0.5
		_WaveAmplitude("Waves Amplitude", Vector) = (0.05, 0.1, 0.2, 0.3)
		_WavesIntensity("Waves Intensity", Vector) = (3, 2, 2, 10)
		_WavesNoise("Waves Noise", Vector) = (0.05, 0.15, 0.03, 0.05)

		[Header(Refraction settings)]
		_WaterClarity("Water Clarity",  Range(0, 3)) = 0.75
		_WaterTransparency("Water Transparency",  Range(0, 30)) = 10.0
		_HorizontalExtinction("Horizontal Extinction", Vector) = (3.0, 10.0, 12.0)
		_RefractionValues("Refraction/Reflection", Vector) = (0.3, 0.01, 1.0)
		_RefractionScale("Refraction Scale",  Range(0, 0.03)) = 0.005

		[Header(Reflection settings)]
		_Shininess("Shininess",  Range(0, 3)) = 0.5
		_SpecularValues("Specular Intensity", Vector) = (12, 768, 0.15)
		_Distortion("Distortion", Range(0, 0.15)) = 0.05
		_RadianceFactor("Radiance Factor", Range(0, 1.0)) = 1.0
		_EdgeFade("Reflection Edge Fade", Range(0,1)) = 0.1
		[HideInInspector]_ReflectionTexture("Reflection Texture", 2D) = "white" {}

		[Header(Foam settings)]
		[NoScaleOffset]_FoamTexture("Foam Texture", 2D) = "black" {}
		[NoScaleOffset]_ShoreTexture("Shore Texture", 2D) = "black" {}
		_FoamTiling("Foam Tiling", Vector) = (2.0, 0.5, 0.0)
		_FoamRanges("Foam Ranges", Vector) = (2.0, 3.0, 100.0)
		_FoamNoise("Foam Noise", Vector) = (0.1, 0.3, 0.1, 0.3)
		_FoamSpeed("Foam Speed", Float) = 10
		_FoamIntensity("Foam Intensity", Range(0, 1)) = 0.5
		_ShoreFade("Shore Fade",  Range(0.1, 3)) = 0.3
		[HideInInspector][NonModifiableTextureData]_NoiseTexSSR("SSR Noise Texture", 2D) = "black" {}
	}
		SubShader{
		Tags{
		"IgnoreProjector" = "True"
		"Queue" = "Transparent"
		"RenderType" = "Transparent"
		}
		GrabPass{ "_RefractionTexture" }
		Pass{
		Name "Base"
		Tags{ "LightMode" = "ForwardBase" }
		Blend SrcAlpha OneMinusSrcAlpha
		Cull Off
		ZWrite Off

		CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag

		// Keyword shuffling to save global keywords
		
		#pragma shader_feature _PARALLAXMAP
		#pragma shader_feature _SPECGLOSSMAP
		#pragma shader_feature GRAIN
		#pragma shader_feature FXAA
		#pragma shader_feature BLOOM
		#pragma exclude_renderers d3d11_9x 
		#pragma target 3.0

		#define USE_REFLECTION defined(GRAIN)
		#define USE_MEAN_SKY_RADIANCE defined(_SPECGLOSSMAP)
		#define USE_DISPLACEMENT defined(_PARALLAXMAP)
		#define USE_FOAM defined(FXAA)
		#define BLINN_PHONG defined(BLOOM)

		#include "UnityCG.cginc"

		#include "UnityLightingCommon.cginc"
		#include "UnityPBSLighting.cginc"
		#include "UnityGlobalIllumination.cginc"

		#include "conversion.cginc"
		#include "hlsl/snoise.cginc"
		#include "hlsl/normals.cginc"
		#include "hlsl/water/displacement.cginc"
		#include "hlsl/water/meansky.cginc"
		#include "hlsl/water/radiance.cginc"
		#include "hlsl/water/depth.cginc"
		#include "hlsl/water/foam.cginc"

		#pragma multi_compile_fog

		UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture); float4 _CameraDepthTexture_TexelSize;
		uniform sampler2D _HeightTexture;
		uniform sampler2D _NormalTexture;
		uniform sampler2D _FoamTexture;
		uniform sampler2D _ShoreTexture;
		uniform sampler2D _RefractionTexture; uniform float4 _RefractionTexture_TexelSize;

		uniform sampler2D _NoiseTexSSR; uniform float4 _NoiseTexSSR_TexelSize;

		uniform float4x4 _ViewProjectInverse;

		uniform float4 _TimeEditor;
		uniform float _AmbientDensity;
		uniform float _DiffuseDensity;
		uniform float _HeightIntensity;
		uniform float _NormalIntensity;
		uniform float _TextureTiling;
		uniform float _EdgeFade;

		//uniform float4 _LightColor0;
		uniform float3 _SurfaceColor;
		uniform float3 _ShoreColor;
		uniform float3 _DepthColor;
		// Wind direction in world coordinates, amplitude encoded as the length of the vector
		uniform float2 _WindDirection;
		uniform float _WaveTiling;
		uniform float _WaveSteepness;
		uniform float _WaveAmplitudeFactor;
		// Displacement amplitude of multiple waves, x = smallest waves, w = largest waves
		uniform float4 _WaveAmplitude;
		// Intensity of multiple waves, affects the frequency of specific waves, x = smallest waves, w = largest waves
		uniform float4 _WavesIntensity;
		// Noise of multiple waves, x = smallest waves, w = largest waves
		uniform float4 _WavesNoise;
		// Affects how fast the colors will fade out, thus, use smaller values (eg. 0.05f).
		// to have crystal clear water and bigger to achieve "muddy" water.
		uniform float _WaterClarity;
		// Water transparency along eye vector
		uniform float _WaterTransparency;
		// Horizontal extinction of the RGB channels, in world coordinates. 
		// Red wavelengths dissapear(get absorbed) at around 5m, followed by green(75m) and blue(300m).
		uniform float3 _HorizontalExtinction;
		uniform float _Shininess;
		// xy = Specular intensity values, z = shininess exponential factor.
		uniform float3 _SpecularValues;
		// x = index of refraction constant, y = refraction intensity
		// if you want to empasize reflections use values smaller than 0 for refraction intensity.
		uniform float2 _RefractionValues;
		// Amount of wave refraction, of zero then no refraction. 
		uniform float _RefractionScale;
		// Reflective radiance factor.
		uniform float _RadianceFactor;
		// Reflection distortion, the higher the more distortion.
		uniform float _Distortion;
		// x = range for shore foam, y = range for near shore foam, z = threshold for wave foam
		uniform float3 _FoamRanges;
		// x = noise for shore, y = noise for outer
		// z = speed of the noise for shore, y = speed of the noise for outer, not that speed can be negative
		uniform float4 _FoamNoise;
		uniform float2 _FoamTiling;
		// Extra speed applied to the wind speed near the shore
		uniform float _FoamSpeed;
		uniform float _FoamIntensity;
		uniform float _ShoreFade;
		
		#include "ssr.cginc"

		inline void InitialiseUnityGI(out UnityGIInput d, half3 worldPos, half3 eyeVec) 
		{
			d = (UnityGIInput)0;
		    d.worldPos = worldPos;
		    d.worldViewDir = eyeVec;

		    d.probeHDR[0] = unity_SpecCube0_HDR;
		    d.probeHDR[1] = unity_SpecCube1_HDR;
		    #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
		      d.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
		    #endif
		    #ifdef UNITY_SPECCUBE_BOX_PROJECTION
		      d.boxMax[0] = unity_SpecCube0_BoxMax;
		      d.probePosition[0] = unity_SpecCube0_ProbePosition;
		      d.boxMax[1] = unity_SpecCube1_BoxMax;
		      d.boxMin[1] = unity_SpecCube1_BoxMin;
		      d.probePosition[1] = unity_SpecCube1_ProbePosition;
		    #endif
		}

		// Oblique projection fix for mirrors.
		// See https://github.com/lukis101/VRCUnityStuffs/blob/master/Shaders/DJL/Overlays/WorldPosOblique.shader
		#define PM UNITY_MATRIX_P

		inline float4 CalculateFrustumCorrection()
		{
			float x1 = -PM._31/(PM._11*PM._34);
			float x2 = -PM._32/(PM._22*PM._34);
			return float4(x1, x2, 0, PM._33/PM._34 + x1*PM._13 + x2*PM._23);
		}
		inline float CorrectedLinearEyeDepth(float z, float B)
		{
			// default Unity is
			// return 1.0 / (_ZBufferParams.z * z + _ZBufferParams.w);
			return 1.0 / (z/PM._34 + B);
		}
		#undef PM

		struct VertexInput {
			float4 vertex : POSITION;
		};
		struct VertexOutput {
			float4 pos : SV_POSITION;
			float4 uvPackData : TEXCOORD0;
			float3 normal : TEXCOORD1;  // world normal
			float3 tangent : TEXCOORD2;
			float3 bitangent : TEXCOORD3;
			float3 worldPos : TEXCOORD4;
			float4 projPos : TEXCOORD5;
			float4 wind : TEXCOORD6; // xy = normalized wind, zw = wind multiplied with timer
			UNITY_FOG_COORDS(8)
		};

		VertexOutput vert(VertexInput v)
		{
			VertexOutput o = (VertexOutput)0;

			float2 windDir = _WindDirection;
			float windSpeed = length(_WindDirection);
			windDir /= windSpeed;
			float timer = (_Time + _TimeEditor) * windSpeed * 10;

			float4 modelPos = v.vertex;
			float3 worldPos = mul(unity_ObjectToWorld, float4(modelPos.xyz, 1));
			half3 normal = half3(0, 1, 0);

#if USE_DISPLACEMENT
			float cameraDistance = length(_WorldSpaceCameraPos.xyz - worldPos);
			float2 noise = GetNoise(worldPos.xz, timer * windDir * 0.5);

			half3 tangent;
			float4 waveSettings = float4(windDir, _WaveSteepness, _WaveTiling);
			float4 waveAmplitudes = _WaveAmplitude * _WaveAmplitudeFactor;
			worldPos = ComputeDisplacement(worldPos, cameraDistance, noise, timer,
				waveSettings, waveAmplitudes, _WavesIntensity, _WavesNoise,
				normal, tangent);

			// add extra noise height from a heightmap
			float heightIntensity = _HeightIntensity * (1.0 - cameraDistance / 100.0) * _WaveAmplitude;
			float2 texCoord = worldPos.xz * 0.05 *_TextureTiling;
			if (heightIntensity > 0.02)
			{
				float height = ComputeNoiseHeight(_HeightTexture, _WavesIntensity, _WavesNoise,
					texCoord, noise, timer);
				worldPos.y += height * heightIntensity;
			}

			modelPos = mul(unity_WorldToObject, float4(worldPos, 1));
			o.tangent = tangent;
			o.bitangent = cross(normal, tangent);
#endif
			float2 uv = worldPos.xz;

			o.uvPackData.w = timer;
			o.wind.xy = windDir;
			o.wind.zw = windDir * timer;

			o.uvPackData.xy = uv  * 0.05 * _TextureTiling;
			o.pos = UnityObjectToClipPos(modelPos);
			o.uvPackData.z = dot(o.pos,CalculateFrustumCorrection());

        #if defined(UNITY_REVERSED_Z)
        // when using reversed-Z, make the Z be just a tiny
        // bit above 0.0
        //o.pos.z = 1.0e-9f;
        o.pos.z = max(o.pos.z, 1.0e-8f);
        #else
        // when not using reversed-Z, make Z/W be just a tiny
        // bit below 1.0
        //o.pos.z = o.pos.w - 1.0e-6f;
        o.pos.z = min(o.pos.z, o.pos.w - 1.0e-5f);
        #endif

			o.worldPos = worldPos;
			o.projPos = ComputeScreenPos(o.pos);
			o.normal = normal;

			o.projPos.z = -mul(UNITY_MATRIX_V, float4(o.worldPos, 1.0)).z;

			UNITY_TRANSFER_FOG(o, o.pos);

			return o;
		}

		void farDepthReverseFix(inout float bgDepth)
		{
			#if UNITY_REVERSED_Z
				if (bgDepth == 0)
			#else
				if (bgDepth == 1)
			#endif
				bgDepth = 0.0;
		}
		float2 AlignWithGrabTexel (float2 uv) 
		{		
			return
				(floor(uv * _CameraDepthTexture_TexelSize.zw) + 0.5) *
				abs(_CameraDepthTexture_TexelSize.xy);
		}

		float4 frag(VertexOutput fs_in, float facing : VFACE) : COLOR
		{
			float timer = fs_in.uvPackData.w;
			float2 windDir = fs_in.wind.xy;
			float2 timedWindDir = fs_in.wind.zw;
			float2 ndcPos = float2(fs_in.projPos.xy / fs_in.projPos.w);
			float3 eyeDir = normalize(_WorldSpaceCameraPos.xyz - fs_in.worldPos);
			float3 surfacePosition = fs_in.worldPos;
			half3 lightColor = _LightColor0.rgb;

			half3 indirectColor = float3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);

			//wave normal
#if USE_DISPLACEMENT
			half3 normal = ComputeNormal(_NormalTexture, surfacePosition.xz, fs_in.uvPackData.xy,
				fs_in.normal, fs_in.tangent, fs_in.bitangent, _WavesNoise, _WavesIntensity, timedWindDir);
#else
			half3 normal = ComputeNormal(_NormalTexture, surfacePosition.xz, fs_in.uvPackData.xy,
				fs_in.normal, 0, 0, _WavesNoise, _WavesIntensity, timedWindDir);
#endif
			normal = normalize(lerp(fs_in.normal, normalize(normal), _NormalIntensity));

			// compute refracted color
			float depth = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(fs_in.projPos.xyww));
    		float sceneZ = CorrectedLinearEyeDepth(
    			SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(fs_in.projPos)),
    			fs_in.uvPackData.z/fs_in.projPos.w );
    		farDepthReverseFix(sceneZ);
			float3 depthPosition = -facing * (sceneZ * (_WorldSpaceCameraPos.xyz - fs_in.worldPos) / fs_in.projPos.z - _WorldSpaceCameraPos.xyz);

			float waterDepth = surfacePosition.y - depthPosition.y; // horizontal water depth
			float viewWaterDepth = length(surfacePosition - depthPosition); // water depth from the view direction(water accumulation)
			
			float2 dudv = ndcPos;
			
			// refraction based on water depth
			float refractionScale = _RefractionScale * min(waterDepth+1.0f, 1.0f);
			float2 delta = float2(sin(timer + 3.0f * abs(depthPosition.y)),
								  sin(timer + 5.0f * abs(depthPosition.y)));
			// Added / fs_in.projPos.w to dampen refraction at distances
			dudv += windDir * delta * refractionScale * !IsInMirror() / fs_in.projPos.w;

			// compute refracted depth
			float4 offset = float4((windDir * delta * refractionScale * !IsInMirror() / fs_in.projPos.w), 0, 0);

			half3 pureRefractionColor = tex2D(_RefractionTexture, AlignWithGrabTexel(dudv)).rgb;
			{
				// recalculate waterDepth
				float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, (fs_in.projPos.xy / fs_in.projPos.w)+offset);
	    		float sceneZ = CorrectedLinearEyeDepth(depth,
	    			fs_in.uvPackData.z/fs_in.projPos.w );
	    		farDepthReverseFix(sceneZ);
				float3 depthPosition = -facing * (sceneZ * (_WorldSpaceCameraPos.xyz - fs_in.worldPos) / fs_in.projPos.z - _WorldSpaceCameraPos.xyz);

				waterDepth = surfacePosition.y - depthPosition.y; 
				viewWaterDepth = length(surfacePosition - depthPosition); 
			}
			{
				// reverse existing applied fog for correct shore color
				INVERSE_FOG_COLOR(fs_in.fogCoord, pureRefractionColor);
			}
			float2 waterTransparency = float2(_WaterClarity, _WaterTransparency);
			float2 waterDepthValues = float2(waterDepth, viewWaterDepth);
			float shoreRange = max(_FoamRanges.x, _FoamRanges.y) * 2.0;
			half3 refractionColor = DepthRefraction(waterTransparency, waterDepthValues, shoreRange, _HorizontalExtinction,
													pureRefractionColor, _ShoreColor, _SurfaceColor, _DepthColor);

			// compute ligths's reflected radiance
			float3 lightDir = normalize(_WorldSpaceLightPos0);
			half fresnel = FresnelValue(_RefractionValues, normal, eyeDir);
			half3 specularColor = ReflectedRadiance(_Shininess, _SpecularValues, lightColor, lightDir, eyeDir, normal, fresnel);

			// compute sky's reflected radiance
#if USE_MEAN_SKY_RADIANCE
			UnityGIInput unity_gi;
			InitialiseUnityGI(unity_gi, fs_in.worldPos, eyeDir);
			half3 reflectColor = fresnel * MeanSkyRadiance(unity_gi, normal) * _RadianceFactor;
#else
			half3 reflectColor = 0;
#endif // #ifndef USE_MEAN_SKY_RADIANCE

			// compute reflected color
			dudv = ndcPos + _Distortion * normal.xz;

			float2 screenUVs = 0;
			float4 screenPos = 0;
		#if USE_REFLECTION
			screenUVs = fs_in.projPos.xy / (fs_in.projPos.w+0.0000000001);
			#if UNITY_SINGLE_PASS_STEREO
				screenUVs.x *= 2;
			#endif
			screenPos = fs_in.projPos;

			half4 ssrCol = GetSSR(_RefractionTexture, _RefractionTexture_TexelSize, 
				surfacePosition, eyeDir, reflect(-eyeDir, normal), normal, 
				1.0,screenUVs, screenPos, _EdgeFade);
			//ssrCol.rgb *= _SSRStrength;
			specularColor *= (1-smoothstep(0, 0.1, ssrCol.a));
			reflectColor *= (1-smoothstep(0, 0.1, ssrCol.a));
			reflectColor = lerp(reflectColor, ssrCol.rgb, ssrCol.a);
			//reflectColor += ssrCol.rgb;
		#endif

			// shore foam
#if USE_FOAM
			float maxAmplitude = max(max(_WaveAmplitude.x, _WaveAmplitude.y), _WaveAmplitude.z);
			half foam = FoamValue(_ShoreTexture, _FoamTexture, _FoamTiling,
				_FoamNoise, _FoamSpeed * windDir, _FoamRanges, maxAmplitude,
				surfacePosition, depthPosition, eyeDir, waterDepth, timedWindDir, timer);
			foam *= _FoamIntensity;
#else
			half foam = 0;
#endif // #ifdef USE_FOAM

			half  shoreFade = saturate(waterDepth * _ShoreFade);
			// ambient + diffuse
			half3 ambientColor = indirectColor.rgb * _AmbientDensity + saturate(dot(normal, lightDir)) * _DiffuseDensity;
			// refraction color with depth based color
			pureRefractionColor = lerp(pureRefractionColor, reflectColor, fresnel * saturate(waterDepth / (_FoamRanges.x * 0.4)));
			pureRefractionColor = lerp(pureRefractionColor, _ShoreColor, 0.30 * shoreFade);
			// compute final color
			half3 color = lerp(refractionColor, reflectColor, fresnel);
			color = (ambientColor + color + max(specularColor, foam * lightColor));
			color = lerp(pureRefractionColor + specularColor * shoreFade, color, shoreFade);
			UNITY_APPLY_FOG(fs_in.fogCoord, color);

#if DEBUG_NORMALS
			color.rgb = 0.5 + 2 * ambientColor + specularColor + clamp(dot(normal, lightDir), 0, 1) * 0.5;
#endif

			return float4(color, 1.0);
		}
		ENDCG
		}
		}
			CustomEditor "WaterShaderGUI"
}
