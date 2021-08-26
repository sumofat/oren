 
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
    float3 normal : NORMAL;
    float4 frag_p : TEXCOORD1;    
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
    
     output.color = color;
     output.normal = float4(IN.normal,1);
     output.position = IN.frag_p;
     return output; 
}
