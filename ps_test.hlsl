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
    float4 Position : SV_Position;
    float4 Color : COLOR;
    float2 UV : TEXCOORD;
};

//NOTE(Ray):currenty everything is alpha blended change that later.
float4 main( PixelShaderInput IN ) : SV_Target
{
   float4 color = ts[shader_vars.tex_index].Sample(s1, IN.UV);
 //  return float4(0,1,0,1);
   return color;//float4(color.xyz,1.0)// * IN.Color;
}
