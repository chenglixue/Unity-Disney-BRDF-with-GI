#pragma once
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
#include "BRDF.hlsl"

#pragma region Variable
#define PI 3.141592654
#define Eplison 0.001

CBUFFER_START(UnityPerMaterial)
int     _Enable_Albedo;
int     _Enable_Normal;
int     _Enable_Metallic;
int     _Enable_Roughness;
int     _Enable_AO;
int     _Enable_Emission;

float4  _Albedo;
half    _Cutoff;
half4   _Emission;
half3   _Normal;
half    _NormalIntensity;

float   _Metallic;
float   _Roughness;
float   _Subsurface;
float   _Specular;
float   _SpecularTint;
float   _Anisotropic;
float   _Sheen;
float   _SheenTint;
float   _Clearcoat;
float   _ClearcoatGloss;
float   _AO;

half    _AlbedoTexTiling;

half4   _AlbedoTint;

half4   _AlbedoTex_TexelSize;
CBUFFER_END

SamplerState sampler_LinearClamp;
SamplerState sampler_PointClamp;

TEXTURE2D(_AlbedoTex);
TEXTURE2D(_EmissionTex);
TEXTURE2D(_NormalTex);

TEXTURE2D(_MetallicTex);
TEXTURE2D(_RoughnessTex);

TEXTURECUBE(_IrradianceTex);    SAMPLER(sampler_IrradianceTex);
TEXTURE2D(_LUTTex);             SAMPLER(sampler_LUTTex);
TEXTURECUBE(_PrefilterTex);     SAMPLER(sampler_PrefilterTex);
TEXTURE2D(_AOTex);              SAMPLER(sampler_AOTex);

struct VSInput
{
    float3      posOS        : POSITION;

    float3       normalOS      : NORMAL;
    float4       tangentOS     : TANGENT;

    float2      uv           : TEXCOORD0;
    float2      lightmapUV   : TEXCOORD1;

    UNITY_VERTEX_INPUT_INSTANCE_ID 
};

struct PSInput
{
    float2      uv              : TEXCOORD0;
    float2      lightmapUV      : TEXCOORD1;

    float3      posWS           : TEXCOORD2;
    float4      posCS           : SV_POSITION;

    float3       normalWS        : NORMAL;
    float3       tangentWS       : TANGENT;
    float3       bitTangentWS    : TEXCOORD3;
    
    UNITY_VERTEX_INPUT_INSTANCE_ID
};
#pragma endregion 

PSInput PBRVS(VSInput i)
{
    UNITY_SETUP_INSTANCE_ID(i);                         //装配 InstancingID
    UNITY_TRANSFER_INSTANCE_ID(i, o);                   //输入到结构中传给片元着色器
    
    PSInput o;

    const VertexPositionInputs vertexPosData = GetVertexPositionInputs(i.posOS);
    o.posWS = vertexPosData.positionWS;
    o.posCS = vertexPosData.positionCS;

    const VertexNormalInputs vertexNormalData = GetVertexNormalInputs(i.normalOS, i.tangentOS);
    o.normalWS = vertexNormalData.normalWS;
    o.tangentWS = vertexNormalData.tangentWS;
    o.bitTangentWS = vertexNormalData.bitangentWS;

    o.uv = i.uv;
    o.lightmapUV = i.lightmapUV;

    #if defined(UNITY_UV_STARTS_AT_TOP)
    if(_AlbedoTex_TexelSize.y < 0.f)
    {
        o.uv.y = 1 - o.uv.y;
        o.lightmapUV.y = 1 - o.lightmapUV.y;
    }
    #endif

    return o;
}

MyBRDFData SetBRDFData(float2 uv, Light light, MyLightData lightData)
{
    half4 albedoValue = _AlbedoTex.SampleLevel(sampler_LinearClamp, uv, 0);
    float3 normalValue = UnpackNormalScale(_NormalTex.SampleLevel(sampler_LinearClamp, uv, 0), _NormalIntensity);
    half3 emissionValue = _EmissionTex.SampleLevel(sampler_LinearClamp, uv, 0).rgb;
    half metallicValue = _MetallicTex.SampleLevel(sampler_LinearClamp, uv, 0).r;
    half roughnessValue = _RoughnessTex.SampleLevel(sampler_LinearClamp, uv, 0).r;
    half AOValue = _AOTex.SampleLevel(sampler_LinearClamp, uv, 0).r;
    if(_Enable_Albedo) albedoValue = _Albedo;
    if(_Enable_Normal) normalValue = _Normal;
    if(_Enable_Emission) emissionValue = _Emission;
    if(_Enable_Metallic) metallicValue = _Metallic;
    if(_Enable_Roughness) roughnessValue = _Roughness;
    if(_Enable_AO) AOValue = _AO;

    half3 FO = lerp(0.04, albedoValue, metallicValue);
    half3 radiance = light.color;

    MyBRDFData o;
    o.albedo = albedoValue;
    o.normal = SafeNormalize(mul(normalValue, lightData.TBN));
    o.emission = emissionValue;
    o.metallic = metallicValue;
    o.roughness = roughnessValue;
    o.roughness2 = Pow2(roughnessValue);
    o.AO = AOValue;
    o.F0 = FO;
    o.radiance = radiance;

    float3 lightDir = SafeNormalize(light.direction);
    float3 halfVector = SafeNormalize(lightData.viewDirWS + lightDir);
    o.halfVector = halfVector;
    o.NoL = max(dot(o.normal, lightDir), 0.001f);
    o.NoV = max(dot(o.normal, lightData.viewDirWS), 0.001f);
    o.NoH = max(dot(o.normal, halfVector), 0.001f);
    o.HoV = max(dot(halfVector, lightData.viewDirWS), 0.001f);
    o.HoL = max(dot(halfVector, lightDir), 0.001f);
    o.HoX = max(dot(halfVector, lightData.tangentWS), 0.001f);
    o.HoY = max(dot(halfVector, lightData.bitTangentWS), 0.001f);

    return o;
}
MyLightData SetLightData(PSInput i)
{
    MyLightData lightData;
    
    lightData.viewDirWS = SafeNormalize(GetCameraPositionWS() - i.posWS);
    lightData.tangentWS = SafeNormalize(i.tangentWS);
    lightData.bitTangentWS = SafeNormalize(i.bitTangentWS);
    lightData.normalWS = SafeNormalize(i.normalWS);
    lightData.TBN = half3x3(lightData.tangentWS, lightData.bitTangentWS, lightData.normalWS);

    lightData.shadowUV = TransformWorldToShadowCoord(i.posWS);
    return lightData;
}

half4 PBRPS(PSInput i) : SV_TARGET
{
    UNITY_SETUP_INSTANCE_ID(i);
    
    MyLightData lightData;
    MyBRDFData  brdfData;

    lightData       = SetLightData(i);
    Light mainLight = GetMainLight();
    brdfData        = SetBRDFData(i.uv, mainLight, lightData);

    float luminance      = Luminance(brdfData.albedo);                                                                          // rgb转换成luminance
    float3 colorTint     = luminance > 0.f ? brdfData.albedo * rcp(luminance) : float3(1, 1, 1);                                  // 对baseColor按亮度归一化，从而独立出色调和饱和度，可以认为Ctint是与亮度无关的固有色调
    float3 colorSpecular = lerp(_Specular * 0.08f * lerp(1.f, colorTint, _SpecularTint), brdfData.albedo, brdfData.metallic);   // 高光底色
    float3 colorSheen    = lerp(1.f, colorTint, _SheenTint);                                                                    // 光泽颜色.光泽度用于补偿布料等材质在FresnelPeak处的额外光能，光泽颜色则从白色开始，按照输入的sheenTint插值

    // -----------------
    // Diffuse
    // -----------------
    float FNoL = SchlickFresnel(brdfData.NoL);                          // 返回(1-cosθ)^5
    float FNoV = SchlickFresnel(brdfData.NoV);                          // 返回(1-cosθ)^5
    float Fd90 = 0.5f + 2 * Pow2(brdfData.HoL) * brdfData.roughness;    // 使用roughness计算diffuse
    float Fd   = lerp(1.f, Fd90, FNoL) * lerp(1.f, Fd90, FNoV);         // 还未乘上baseColor/pi，会在最后进行

    // -----------------
    // Subsurface
    // -----------------
    // 基于各向同性bssrdf的Hanrahan-Krueger brdf逼近
    // 1.25用于保留反照率
    float Fss90 = Pow2(brdfData.HoL) * brdfData.roughness;              // 垂直于次表面的菲涅尔系数
    float Fss = lerp(1.f, Fss90, FNoL) * lerp(1.f, Fss90, FNoV);
    float ss = 1.25f * (Fss * (rcp(brdfData.NoL + brdfData.NoV) - 0.5f) + 0.5f);     // 还未乘上baseColor/pi，会在最后进行

    // -----------------
    // Specular
    // -----------------
    float aspect = sqrt(1.f - _Anisotropic * 0.9f);                                // aspect将anisotropic参数重映射到[0.1,1]空间，确保aspect不为0
    float ax = max(.001f, Pow2(brdfData.roughness) / aspect);                      // ax随参数anisotropic的增加而增加
    float ay = max(.001f, Pow2(brdfData.roughness) * aspect);                      // ay随着参数anisotropic的增加而减少，ax和ay在anisotropic值为0时相等
    float Ds = GTR2_aniso(brdfData.NoH, dot(brdfData.halfVector, lightData.tangentWS), dot(brdfData.halfVector, lightData.bitTangentWS), ax, ay);       // NDF:主波瓣 各项异性GTR2
    float FH = SchlickFresnel(brdfData.HoL);                                       // pow(1-cosθd,5)
    float3 Fs = lerp(colorSpecular, 1.f, FH);                                      // Fresnel:colorSpecular作为F0，模拟金属的菲涅尔色 
    float Gs;
    Gs  = smithG_GGX_aniso(brdfData.NoL, dot(mainLight.direction, lightData.tangentWS), dot(mainLight.direction, lightData.bitTangentWS), ax, ay);  // 遮蔽的几何项
    Gs *= smithG_GGX_aniso(brdfData.NoV, dot(lightData.viewDirWS, lightData.tangentWS), dot(lightData.viewDirWS, lightData.bitTangentWS), ax, ay);      // 阴影关联的几何项

    // -----------------
    // Sheen 作为边缘处漫反射的补偿
    // -----------------
    float3 Fsheen = FH * _Sheen * colorSheen;

    // -----------------
    // clearcoat (ior = 1.5 -> F0 = 0.04)
    // -----------------
    // 清漆层没有漫反射，只有镜面反射，使用独立的D,F和G项 
    // GTR1（berry）分布函数获取法线强度，第二个参数a（粗糙度）
    float Dr = D_GTR1(brdfData.NoH, lerp(0.1f, 0.001f, _ClearcoatGloss)); 
    float Fr = lerp(0.04f, 1.f, FH);                                                      // Fresnel最低值至0.04 
    float Gr = G_GGX(brdfData.NoL, 0.25f) * G_GGX(brdfData.NoV, .25);    // 几何项使用各项同性的smithG_GGX计算，a固定给0.25 

    float3 result = (rcp(PI) * lerp(Fd, ss, _Subsurface) * brdfData.albedo + Fsheen) * (1 - brdfData.metallic);
    result        += Ds * Fs * Gs;
    result        += 0.25f * _Clearcoat * Dr * Fr * Gr;

    float3 directLight = result * mainLight.color * brdfData.NoL;
    directLight        *= mainLight.shadowAttenuation;
    result             += directLight;

    // -----------------
    //GI Diffuse
    // -----------------
    float F0          = lerp(0.04f, brdfData.albedo, brdfData.metallic);
    float3 F_IBL      = FresnelSchlickRoughness(brdfData.NoV, F0, brdfData.roughness);
    float KD_IBL      = (1 - F_IBL.r) * (1 - brdfData.metallic);
    float3 irradiance = SAMPLE_TEXTURECUBE_LOD(_IrradianceTex, sampler_IrradianceTex, lightData.normalWS, 0).rgb;
    float3 inDiffuse  = KD_IBL * brdfData.albedo * irradiance;
    //result            += inDiffuse;

    // -----------------
    //GI Specular
    // -----------------
    float3 reflectDir     = reflect(-lightData.viewDirWS, lightData.normalWS);
    float3 preFilterValue = SAMPLE_TEXTURECUBE_LOD(_PrefilterTex, sampler_PrefilterTex, reflectDir, 0).rgb;
    float2 envBRDF        = _LUTTex.SampleLevel(sampler_LinearClamp, float2(lerp(0.f, 0.99f, brdfData.NoV), lerp(0.f, 0.99f, brdfData.roughness)), 0).rg;
    float3 inSpecular     = preFilterValue * (envBRDF.r * F_IBL + envBRDF.g);
    //result                += inSpecular;
    
    result += (inDiffuse + inSpecular) * brdfData.AO;
    
    //return float4(brdfData.normal, 1);
    return float4(result, 1.f);
}