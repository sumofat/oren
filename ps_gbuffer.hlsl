 
Texture2D ts[3] : register(t0);
SamplerState s1 : register(s0);

struct ShaderVars
{
    uint tex_index;
    float2 bar;
    int moo;
};

ConstantBuffer<ShaderVars> shader_vars : register(b0);
 
struct PixelShaderInput
{
    float4 position : SV_Position;    
    float4 Color : COLOR;
    float2 UV : TEXCOORD0;
    float3 normal : TEXCOORD1;
    float4 frag_p : TEXCOORD2;    
};

struct PixelShaderOutput
{
    float4 color : SV_Target0;
    float4 normal : SV_Target1;    
    float4 position : SV_Target2;
};

//NOTE(Ray):currenty everything is alphay blended change that later.
PixelShaderOutput main( PixelShaderInput IN )
{
     float4 color = ts[shader_vars.tex_index].Sample(s1, IN.UV);

     PixelShaderOutput output;
       
    float4 test_light_p = float4(30,-30,0,1);
    float4 frag_position = IN.frag_p;
    float3 normal = IN.normal;
    float3 light_dir = normalize(test_light_p.xyz - frag_position.xyz);
//    float3 light_dir = normalize(frag_position.xyz - test_light_p.xyz);
    float3 dotp = max(dot(normal,light_dir),0);

    float light_intensity = 1.0;
    float4 test_light_color = float4(1,1,1,1) * light_intensity;
    
    
     output.color = color * test_light_color * float4(dotp,1);
     output.normal = float4(normal,1);
     output.position = IN.frag_p;
     return output; 
}
