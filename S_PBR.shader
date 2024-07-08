Shader "S_PBR"
{
    Properties
    {
        [Header(Rendering Setting)]
        [Space(10)]
        [Enum(UnityEngine.Rendering.CullMode)] _CullMode                                    ("Cull Mode", int)          = 2
        
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendSrc                                   ("Blend Source", int)       = 1
        [Enum(UnityEngine.Rendering.BlendMode)]_BlendDst                                    ("Blend Destination", int)  = 0
        [Enum(UnityEngine.Rendering.BlendOp)]_BlendOp                                       ("Blend Operator", int)     = 0
        
        [Enum(Off, 0, On, 1)] _ZWriteEnable                                                 ("ZWrite Mode", int)        = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTestCompare                         ("ZTest Mode", int)         = 4
        
        [Enum(UnityEngine.Rendering.ColorWriteMask)] _ColorMask                             ("Color Mask", Int)         = 15
        [Space(10)]
        
        [IntRange] _StencilRef                                                              ("Stencil Ref", Range(0, 255))                  = 0
        [IntRange] _StencilReadMask                                                         ("Stencil Read Mask", Range(0, 255))            = 255
        [IntRange] _StencilWriteMask                                                        ("Stencil Write Mask", Range(0, 255))           = 255
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilTestCompare                   ("Stencil Test Compare", Int)                   = 8
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilPassOp                              ("Stencil Pass Operator", Int)                  = 0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilFailOp                              ("Stencil Fail Operator", Int)                  = 0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilDepthFailOp                         ("Stencil Depth Test Fail Operator", Int)       = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilBackTestCompare               ("Stencil Back Test Compare", Int)              = 8
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilBackPassOp                          ("Stencil Back Pass Operator", Int)             = 0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilBackFailOp                          ("Stencil Back Fail Operator", Int)             = 0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilBackDepthFailOp                     ("Stencil Back Depth Fail Operator", Int)       = 0
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilFrontTestCompare              ("Stencil Front Test Compare", Int)             = 8
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilFrontPassOp                         ("Stencil Front Pass Operator", Int)            = 0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilFrontFailOp                         ("Stencil Front Fail Operator", Int)            = 0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilFrontDepthFailOp                    ("Stencil Front Depth Fail Operator", Int)      = 0
        [Space(10)]
        
        [Toggle] _MULTIPLE_LIGHT("Enable Multiple Light", Int) = 1
        [Space(20)]
        
        [Header(Albedo Setting)]
        [Space(10)]
        [Toggle] _Enable_Albedo             ("Enable Albedo", Int)           = 0
        _Albedo                             ("Albedo Value", Color)          = (1, 1, 1, 1)
        [MainTex][NoScaleOffset] _AlbedoTex ("Albedo Tex", 2D)               = "white" {}
        _AlbedoTexTiling                    ("Albedo Tex Tiling", Float)     = 1
        _Cutoff                             ("Cut off", Range(0, 1))         = 0.5
        _AlbedoTint                         ("Albedo Tint", Color)           = (1,1,1,1)
        [Space(20)]
        
        [Header(Normal Setting)]
        [Space(10)]
        [Toggle] _Enable_Normal             ("Enable Normal", Int)           = 0
        _Normal                             ("Normal Value", Vector)         = (0.5, 0.5, 1, 1)
        [Normal][NoScaleOffset] _NormalTex  ("Normal Tex", 2D)               = "bump" {}
        _NormalIntensity                    ("Normal Intensity", Range(0, 1))= 1
        [Space(20)]
        
        [Header(PBR Setting)]
        [Space(10)]
        [Toggle] _Enable_Metallic           ("Enable Metallic", Int)         = 0
        _Metallic                           ("Metallic Value", Range(0, 1))  = 0
        [NoScaleOffset]_MetallicTex         ("Metallic Tex", 2D)             = "black" {}
        
        [Toggle] _Enable_Roughness          ("Enable Roughness", Int)        = 0
        _Roughness                          ("Roughness Value", Range(0, 1)) = 0
        [NoScaleOffset]_RoughnessTex        ("Roughness Tex", 2D)            = "white" {}
        
        [Toggle] _Enable_AO                 ("Enable AO", Int)               = 0
        _AO                                 ("AO Value", Range(0, 1))        = 1
        [NoScaleOffset]_AOTex               ("AO Tex", 2D)                   = "white" {}
        _IrradianceTex                      ("Irradiance Tex", CUBE)         = "white" {}
        _LUTTex                             ("LUT", 2D)                      = "white" {}
        _PrefilterTex                       ("Prefilter Tex", CUBE)          = "white" {}
        
        _Subsurface                         ("Subsurface", Range(0, 1))      = 0.0
        _Specular                           ("Specular", Range(0, 1))        = 0.5
        _SpecularTint                       ("SpecularTint", Range(0, 1))    = 0.0
        _Anisotropic                        ("Anisotropic", Range(0, 1))     = 0.0
        _Sheen                              ("Sheen", Range(0, 1))           = 0.0
        _SheenTint                          ("SheenTint", Range(0, 1))       = 0.5
        _Clearcoat                          ("Clearcoat", Range(0, 1))       = 0.0
        _ClearcoatGloss                     ("ClearcoatGloss", Range(0, 1))  = 0.0
        [Space(20)]
        
        [Header(Emission Setting)]
        [Space(10)]
        [Toggle] _Enable_Emission           ("Enable Emission", Int)         = 0
        _Emission                           ("Emission Value", Color)        = (1, 1, 1, 1)
        [NoScaleOffset]                     _EmissionTex("自发光贴图", 2D)    = "black" {}
    }
    
    SubShader
    {
        Tags 
        { 
            "RenderPipeline" = "UniversalRenderPipeline"
            "RenderType"="Opaque" 
            "Queue" = "Geometry"
        }
        LOD 100

        HLSLINCLUDE
        #pragma target 4.5

        // gpu instance
        #pragma multi_compile_instancing
        #pragma instancing_options procedural:setup

        #pragma multi_compile _ LIGHTMAP_ON // 启用Lightmap
        #pragma multi_compile _ DIRLIGHTMAP_COMBINED    // LightMap是否使用方向向量
        #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE // 烘焙的混合模式
        #pragma shader_feature_local _MULTIPLE_LIGHT_ON             // 启用多光源
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS                 // 计算主光源的阴影衰减
        #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE         // 计算主光源的阴影坐标
        #pragma multi_compile _ ADDITIONAL_LIGHT_CALCULATE_SHADOWS  // 计算额外光的阴影衰减和距离衰减
        #pragma multi_compile _ _SHADOWS_SOFT                       // 计算软阴影
        #pragma multi_compile __ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS   //计算阴影投射

        #pragma shader_feature _ _ENABLE_BRDFLUT
        #include_with_pragmas "Default.hlsl"
        ENDHLSL
        
        Pass
        {
            Name "Elysia PBR"
            
            Tags
            {
                "LightMode" = "UniversalForwardOnly"
            }
            
            Cull [_CullMode]
            Blend [_BlendSrc] [_BlendDst]
            BlendOp [_BlendOp]
            Stencil
            {
                Ref [_StencilRef]
                ReadMask [_StencilReadMask]
                WriteMask [_StencilWriteMask]
                
                Comp [_StencilTestCompare]
                Pass [_StencilPassOp]
                Fail [_StencilFailOp]
                ZFail [_StencilDepthFailOp]
                
                CompBack [_StencilBackTestCompare]
                PassBack [_StencilBackPassOp]
                FailBack [_StencilBackFailOp]
                ZFailBack [_StencilBackDepthFailOp]
                
                CompFront [_StencilFrontTestCompare]
                PassFront [_StencilFrontPassOp]
                FailFront [_StencilFrontFailOp]
                ZFailFront [_StencilFrontDepthFailOp]
            }
            
            ZWrite [_ZWriteEnable]
            ZTest [_ZTestCompare]
            ColorMask [_ColorMask]
            
            HLSLPROGRAM
            #pragma vertex PBRVS
            #pragma fragment PBRPS
            ENDHLSL
        }
    }
}
