#pragma pack_matrix( row_major )

ByteAddressBuffer matrix_buffer : register(t0);

struct ModelViewProjection
{
    matrix MVP;
};

ConstantBuffer<ModelViewProjection> ModelViewProjectionCB : register(b0);
ConstantBuffer<ModelViewProjection> WorldProjectionCB : register(b1);

struct VertexPosColor
{
    float3 Position : POSITION;
    float2 UV : TEXCOORD;
};
 
struct VertexShaderOutput
{
    float4 Position : SV_Position;
    float2 UV : TEXCOORD;
};

VertexShaderOutput main(VertexPosColor IN)
{
    VertexShaderOutput OUT;
    OUT.Position = float4(IN.Position,1.0f);
    OUT.UV = IN.UV;

    return OUT;
}
