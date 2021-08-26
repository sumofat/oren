#pragma pack_matrix( row_major )

ByteAddressBuffer matrix_buffer : register(t3);

struct ModelViewProjection
{
    matrix MVP;
};


ConstantBuffer<ModelViewProjection> ModelViewProjectionCB : register(b0);
ConstantBuffer<ModelViewProjection> test : register(b1);

struct VertexPosColor
{
    float3 Position : POSITION;
    float3 normal : NORMAL;
    float2 UV : TEXCOORD;
};
 
struct VertexShaderOutput
{
    float4 position : SV_Position;    
    float4 Color : COLOR;
    float2 UV : TEXCOORD0;
    float3 normal : NORMAL;
    float4 frag_p : TEXCOORD1;    
};

VertexShaderOutput main(VertexPosColor IN)
{
    VertexShaderOutput OUT;
 
      uint offset = (uint)ModelViewProjectionCB.MVP[0][0];
      float4 m0 = asfloat(matrix_buffer.Load4(offset + 0));
      float4 m1 = asfloat(matrix_buffer.Load4(offset + 16));
      float4 m2 = asfloat(matrix_buffer.Load4(offset + 32));
      float4 m3 = asfloat(matrix_buffer.Load4(offset + 48));
      
    matrix m = { m0.x,m0.y,m0.z,m0.w,
                 m1.x,m1.y,m1.z,m1.w,
	         m2.x,m2.y,m2.z,m2.w,
	         m3.x,m3.y,m3.z,m3.w};

      uint mmoffset = (uint)ModelViewProjectionCB.MVP[0][1];
      float4 mm0 = asfloat(matrix_buffer.Load4(mmoffset + 0));
      float4 mm1 = asfloat(matrix_buffer.Load4(mmoffset + 16));
      float4 mm2 = asfloat(matrix_buffer.Load4(mmoffset + 32));
      float4 mm3 = asfloat(matrix_buffer.Load4(mmoffset + 48));

    matrix mm = { mm0.x,mm0.y,mm0.z,mm0.w,
                 mm1.x,mm1.y,mm1.z,mm1.w,
	         mm2.x,mm2.y,mm2.z,mm2.w,
	         mm3.x,mm3.y,mm3.z,mm3.w};
float3x3 mm3x3 = { mm0.x,mm0.y,mm0.z,
                 mm1.x,mm1.y,mm1.z,
                 mm2.x,mm2.y,mm2.z};


    float4 p = mul(float4(IN.Position,1.0f),m);
    float4 world_p = mul(float4(IN.Position,1.0f),mm);
    
    OUT.position = p;
    OUT.frag_p = world_p;    
    OUT.Color = float4(1,1,1,1);
    OUT.UV = IN.UV;
    float3 n = IN.normal;

OUT.normal = mul(n,mm3x3);
    //OUT.normal = normalize(n);//normalize(mul(float4(n,0),mm3).xyz);

    return OUT;
}
