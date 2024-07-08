struct MyBRDFData
{
    float3 albedo;
    float3 normal;
    float3 emission;
    float metallic;
    float roughness;
    float roughness2;
    float AO;
    
    float3 F0;
    float3 radiance;

    float3 halfVector;
    float NoV;
    float NoH;
    float NoL;
    float HoV;
    float HoL;
    float HoX;
    float HoY;
};
struct MyLightData
{
    half3 tangentWS;
    half3 bitTangentWS;
    half3 normalWS;
    half3 viewDirWS;
    float4 shadowUV;

    half3x3 TBN;
};

float Pow5(float x)
{
    return x * x * x * x; 
}

float Pow2(float x)
{
    return x * x;
}


#pragma region Diffuse
float3 Diffuse_Lambert(float3 DiffuseColor)
{
    return DiffuseColor * (1 / PI);
}

// [Burley 2012, "Physically-Based Shading at Disney"]
// Lambert漫反射模型在边缘上通常太暗，而通过尝试添加菲涅尔因子以使其在物理上更合理，但会导致其更暗
// 根据对Merl 100材质库的观察，Disney开发了一种用于漫反射的新的经验模型，以在光滑表面的漫反射菲涅尔阴影和粗糙表面之间进行平滑过渡
// Disney使用了Schlick Fresnel近似，并修改掠射逆反射（grazing retroreflection response）以达到其特定值由粗糙度值确定，而不是简单为0
float3 Diffuse_Burley( float3 DiffuseColor, float Roughness, float NoV, float NoL, float VoH )
{
    float FD90 = 0.5 + 2 * VoH * VoH * Roughness;
    float FdV = 1 + (FD90 - 1) * Pow5( 1 - NoV );
    float FdL = 1 + (FD90 - 1) * Pow5( 1 - NoL );
    return DiffuseColor * ( (1 / PI) * FdV * FdL );
}

// [Gotanda 2012, "Beyond a Simple Physically Based Blinn-Phong Model in Real-Time"]
float3 Diffuse_OrenNayar( float3 DiffuseColor, float Roughness, float NoV, float NoL, float VoH )
{
    float a = Roughness * Roughness;
    float s = a;// / ( 1.29 + 0.5 * a );
    float s2 = s * s;
    float VoL = 2 * VoH * VoH - 1;		// double angle identity
    float Cosri = VoL - NoV * NoL;
    float C1 = 1 - 0.5 * s2 / (s2 + 0.33);
    float C2 = 0.45 * s2 / (s2 + 0.09) * Cosri * ( Cosri >= 0 ? rcp( max( NoL, NoV ) ) : 1 );
    return DiffuseColor / PI * ( C1 + C2 ) * ( 1 + Roughness * 0.5 );
}

#pragma endregion 

#pragma region NDF
// [Blinn 1977, "Models of light reflection for computer synthesized pictures"]
float NDF_Blinn( float roughness2, float NoH )
{
    float a2 = Pow2(roughness2);
    float n = 2 / a2 - 2;
    return (n+2) / (2*PI) * pow( NoH, n );
}

// [Beckmann 1963, "The scattering of electromagnetic waves from rough surfaces"]
// Beckmann分布在某些方面与Phong分布非常相似
float D_Beckmann( float roughness2, float NoH )
{
    float a2 = Pow2(roughness2);
    float NoH2 = NoH * NoH;
    return exp( (NoH2 - 1) / (a2 * NoH2) ) / ( PI * a2 * NoH2 * NoH2 );
}

// GGX / Trowbridge-Reitz
// [Walter et al. 2007, "Microfacet models for refraction through rough surfaces"]
// 在流行的模型中，GGX拥有最长的尾部。而GGX其实与Blinn (1977)推崇的Trowbridge-Reitz（TR）（1975）分布等同。然而，对于许多材质而言，即便是GGX分布，仍然没有足够长的尾部
float NDF_GGX( float roughness2, float NoH )
{
    float a2 = Pow2(roughness2);
    float d = ( NoH * a2 - NoH ) * NoH + 1;	// 2 mad
    return a2 / ( PI*d*d );					// 4 mul, 1 rcp
}

// Berry(1923)
// 类似 Trowbridge-Reitz,但指数为1而不是2，从而导致了更长的尾部
float NDF_Berry( float roughness2, float NoH )
{
    float a2 = Pow2(roughness2);
    float d = ( NoH * a2 - NoH ) * NoH + 1;	// 2 mad
    return a2 / ( PI*d );					
}

// Disney发现GGX 和 Berry有相似的形式，只是幂次不同，于是，Disney将Trowbridge-Reitz进行了N次幂的推广，并将其取名为GTR
// 基本形式是：c/pow((a^2*cos(NdotH)^2 + sin(NdotH)^2),b) . c为放缩常数，a为粗糙度
// Disney的BRDF使用两个specular lobe
// b=1为次级波瓣，用来表达清漆层
// b=2为主波瓣，用来表达基础材质
float D_GTR1(float NoH, float roughness)
{
    //考虑到粗糙度a在等于1的情况下，公式返回值无意义，因此固定返回1/pi，
    //说明在完全粗糙的情况下，各个方向的法线分布均匀，且积分后得1
    if (roughness >= 1) return 1/PI;
    
    float a2 = roughness * roughness;
    float cos2th = NoH * NoH;
    float den = (1.0 + (a2 - 1.0) * cos2th);
    
    return (a2 - 1.0) / (PI * log(a2) * den);
}

float D_GTR2(float roughness2, float NoH)
{
    float a2 = roughness2 * roughness2;
    float cos2th = NoH * NoH;
    float den = (1.0 + (a2 - 1.0) * cos2th);

    return a2 / (PI * den * den);
}

//主波瓣 各项异性
// VoX：Dot(H, 物体表面的切线向量)
// HdotY：为半角点乘切线空间中的副切线向量 
// ax 和 ay 分别是x、y2个方向上的可感粗糙度，范围是0~1
float GTR2_aniso(float NoH, float HoX, float HoY, float ax, float ay)
{
    return rcp(PI * ax*ay * Pow2( Pow2(HoX / ax) + Pow2(HoY / ay) + Pow2(NoH) ));
}
#pragma endregion

#pragma region Fresnel
float SchlickFresnel(float u)
{
    float m = clamp(1-u, 0, 1);
    float m2 = m * m;
    return m2 * m2 * m;
}

// [Schlick 1994, "An Inexpensive BRDF Model for Physically-Based Rendering"]
float3 F_Schlick(float HoV, float3 F0)
{
    return F0 + (1 - F0) * pow(1 - HoV , 5.0);
}

float3 F_Schlick(float3 F0, float3 F90, float VoH)
{
    float Fc = Pow5(1 - VoH);
    return F90 * Fc + (1 - Fc) * F0;
}

float3 FresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
{
    return F0 + (max(float3(1.0 - roughness, 1.0 - roughness, 1.0 - roughness), F0) - F0) * Pow5(1.0 - cosTheta);
}
#pragma endregion 

#pragma region Geometry
// 清漆层 次级波瓣
// 2012版disney,本质是Smith联合遮蔽阴影函数中的“分离的遮蔽阴影型”
// NoV视情况也可替换为NdotL，用于计算阴影相关的G1
// alphag被disney定义为0.25f
float G_GGX(float NoV, float alphag)
{
    float a = alphag * alphag;
    float b = NoV * NoV;
    return 1.0 / (NoV + sqrt(a + b - a * b));
}

// 各向异性
float smithG_GGX_aniso(float NoV, float VoX, float VoY, float ax, float ay)
{
    return 1 / (NoV + sqrt( Pow2(VoX*ax) + Pow2(VoY*ay) + Pow2(NoV) ));
}
#pragma endregion 

