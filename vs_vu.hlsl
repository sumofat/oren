#pragma pack_matrix( row_major )

ByteAddressBuffer matrix_buffer : register(t4);

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
    float4 Color : COLOR;
    float2 UV : TEXCOORD;
//    float4 normal : NORMAL;
};

VertexShaderOutput main(VertexPosColor IN)
{
    VertexShaderOutput OUT;

//  float4 world_p = mul(float4(IN.Position,1.0f),ModelViewProjectionCB.MVP);
//    float4 world_p = mul(float4(IN.Position,1.0f),WorldProjectionCB.MVP);
      uint offset = (uint)ModelViewProjectionCB.MVP[0][0];
      float4 m0 = asfloat(matrix_buffer.Load4(offset + 0));
      float4 m1 = asfloat(matrix_buffer.Load4(offset + 16));
      float4 m2 = asfloat(matrix_buffer.Load4(offset + 32));
      float4 m3 = asfloat(matrix_buffer.Load4(offset + 48));

    matrix m = { m0.x,m0.y,m0.z,m0.w,
                 m1.x,m1.y,m1.z,m1.w,
	         m2.x,m2.y,m2.z,m2.w,
	         m3.x,m3.y,m3.z,m3.w};

//m = transpose(m);

    float4 world_p = mul(float4(IN.Position,1.0f),m);

    OUT.Position = world_p;
    OUT.Color = float4(1,1,1,1);
    OUT.UV = IN.UV;
//    OUT.normal = IN.normal;    
    return OUT;
}