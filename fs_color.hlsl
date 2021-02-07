
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
    float4 m_color : COLOR1;    
};

float4 main( PixelShaderInput IN ) : SV_Target
{
   return IN.Color;
}

