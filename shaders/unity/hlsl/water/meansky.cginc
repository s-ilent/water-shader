//
// Description : Mean sky radiance
//
// based on Real-time Realistic Ocean Lighting using Seamless Transitions from Geometry to BRDF by Eric Bruneton
//

#if USE_MEAN_SKY_RADIANCE

// V, N, Tx, Ty in world space
float2 U(float2 zeta, float3 V, float3 N, float3 Tx, float3 Ty)
{
	float3 f = normalize(float3(-zeta, 1.0)); // tangent space
	float3 F = f.x * Tx + f.y * Ty + f.z * N; // world space
	float3 R = 2.0 * dot(F, V) * F - V;
	return  dot(F, V);
}

// V, N, Tx, Ty in world space
float3 U3(float2 zeta, float3 V, float3 N, float3 Tx, float3 Ty)
{
	float3 f = normalize(float3(-zeta, 1.0)); // tangent space
	float3 F = f.x * Tx + f.y * Ty + f.z * N; // world space
	float3 R = 2.0 * dot(F, V) * F - V;
	return R;
}

// viewDir and normal in world space
half3 MeanSkyRadiance(samplerCUBE skyTexture, float3 viewDir, half3 normal)
{
	if (dot(viewDir, normal) < 0.0)
	{
		normal = reflect(normal, viewDir);
	}
	float3 ty = normalize(float3(0.0, normal.z, -normal.y));
	float3 tx = cross(ty, normal);

	const float eps = 0.001;
	float2 u0 = U(float2(0, 0), viewDir, normal, tx, ty) * 0.05;
	float2 dux = 2.0 * (float2(eps, 0.0) - u0) / eps;
	float2 duy = 2.0 * (float2(0, eps) - u0) / eps;
	return texCUBE(skyTexture, float3(u0.xy, 1.0)).rgb; //TODO: transform hemispherical cordinates to cube or use a 2d texture
}

// Variant that uses the reflection probe type
half3 MeanSkyRadiance(UNITY_ARGS_TEXCUBE(tex), float3 viewDir, half3 normal)
{
	if (dot(viewDir, normal) < 0.0)
	{
		normal = reflect(normal, viewDir);
	}
	float3 ty = normalize(float3(0.0, normal.z, -normal.y));
	float3 tx = cross(ty, normal);

	const float eps = 0.001;
	float3 u0 = U3(float2(0, 0), viewDir, normal, tx, ty);
	float2 dux = 2.0 * (float2(eps, 0.0) - u0) / eps;
	float2 duy = 2.0 * (float2(0, eps) - u0) / eps;
	return UNITY_SAMPLE_TEXCUBE_LOD(tex, u0, 0).rgb;
}

// Variant that uses the Unity GI
half3 MeanSkyRadiance(UnityGIInput gi, half3 normal)
{
	Unity_GlossyEnvironmentData ge = (Unity_GlossyEnvironmentData) 0;
	if (dot(gi.worldViewDir, normal) < 0.0)
	{
		normal = reflect(normal, gi.worldViewDir);
	}
	float3 ty = normalize(float3(0.0, normal.z, -normal.y));
	float3 tx = cross(ty, normal);

	const float eps = 0.001;
	float3 u0 = U3(float2(0, 0), gi.worldViewDir, normal, tx, ty);
	float2 dux = 2.0 * (float2(eps, 0.0) - u0) / eps;
	float2 duy = 2.0 * (float2(0, eps) - u0) / eps;
	ge.reflUVW = u0;
	return UnityGI_IndirectSpecular(gi, 1.0, ge);
}

#endif // #ifdef USE_MEAN_SKY_RADIANCE
