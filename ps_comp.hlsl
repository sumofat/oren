Texture2D ts[2] : register(t0);
SamplerState s1 : register(s0);

struct PixelShaderInput
{
    float4 Position : SV_Position;
    float2 UV : TEXCOORD;
};

struct ShaderVars
{
    uint tex_index;
    float2 bar;
    int moo;
};

ConstantBuffer<ShaderVars> shader_vars : register(b0);

//NOTE(Ray):currenty everything is alphay blended change that later.
float4 main( PixelShaderInput IN ) : SV_Target
{
    float4 color = ts[shader_vars.tex_index].Sample(s1, IN.UV);
    float4 normal = ts[shader_vars.tex_index + 1].Sample(s1, IN.UV);    
    float4 position = ts[shader_vars.tex_index + 2].Sample(s1, IN.UV);
  
    return color;// + test_light_color;//position;//normal;//color;//float4(color.xyz,1.0) * IN.Color;
}
