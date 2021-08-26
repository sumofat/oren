 
Texture2D ts[3] : register(t0);
SamplerState s1 : register(s0);

struct ShaderVars
{
    uint tex_index;
    float2 bar;
    int moo;
};

struct Light
{
    float4 p;
    float4 color;
    float4 size_intensity;
    float4 padding;
};

ConstantBuffer<ShaderVars> shader_vars : register(b0);
ConstantBuffer<Light> light : register(b1);

struct PixelShaderInput
{
    float4 position : SV_Position;    
    float4 Color : COLOR;
    float2 UV : TEXCOORD0;
    float3 normal : NORMAL;
    float4 frag_p : TEXCOORD1;    
};

//NOTE(Ray):currenty everything is alphay blended change that later.
float4 main( PixelShaderInput IN ) : SV_Target
{
    float2 screen_dim = float2(1920,1080);
    float2 vNormalizedScreenPos = IN.position.xy / screen_dim;
    float2 tex_coord = vNormalizedScreenPos + (0.5 / screen_dim);
    float4 albedo = ts[shader_vars.tex_index].Sample(s1, tex_coord);
    //float4 normal_sample = ts[shader_vars.tex_index + 1].Sample(s1, tex_coord);    
    float4 normal_sample = ts[shader_vars.tex_index + 1].Sample(s1, tex_coord);    
    
    float4 position = ts[shader_vars.tex_index + 2].Sample(s1, tex_coord);
           
    //float4 test_light_p = light.p;//float4(30,-30,0,1);
    float4 test_light_p = float4(0,0,6,0);
    float4 frag_position = position;//IN.frag_p;
    float attenuation = 5;//distance(frag_position.xyz,test_light_p.xyz);
    float3 normal = normal_sample.xyz;//IN.normal;
    float3 light_dir = (test_light_p.xyz - frag_position.xyz);
    //float3 light_dir = (frag_position.xyz - test_light_p.xyz);
    
    float smoothness = 0.75f;
    float  dist = length(light_dir);
    float att = 1.0f - smoothstep(attenuation  * smoothness, attenuation,dist);

    float dotp = max(dot(normalize(normal),normalize(light_dir)),0);

    float light_intensity = light.size_intensity.y;
    float4 light_color = light.color;// * attenuation * 10;
    
    return light_color * dotp * att;
    //return float4(1,1,1,1) * dotp * 100;
    //return float4(att,att,att,1);
    ///return float4(light_dir,1);
    //return float4(dist,dist,dist,1);
    //return float4(normal,1);
    //return float4(1,1,1,1) * dot(normal,normalize(light_dir)) * 1;
}
