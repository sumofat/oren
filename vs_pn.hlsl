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
    float4 normal : NORMAL;
};
 
struct VertexShaderOutput
{
    float4 Position : SV_Position;
    float4 Color : COLOR;
    float2 UV : TEXCOORD;
    float4 normal : NORMAL;
};

VertexShaderOutput main(VertexPosColor IN)
{
    VertexShaderOutput OUT;

//float4 world_p = mul(float4(IN.Position,1.0f),ModelViewProjectionCB.MVP);

      uint offset = (uint)ModelViewProjectionCB.MVP[0][0];
      float4 m0 = asfloat(matrix_buffer.Load4(offset + 0));
      float4 m1 = asfloat(matrix_buffer.Load4(offset + 16));
      float4 m2 = asfloat(matrix_buffer.Load4(offset + 32));
      float4 m3 = asfloat(matrix_buffer.Load4(offset + 48));

//    float4 color = float4(ModelViewProjectionCB.MVP[0][1],ModelViewProjectionCB.MVP[1][1],ModelViewProjectionCB.MVP[2][1],1.0);//ModelViewProjectionCB.MVP[3][1]);
/*float4 color = float4(ModelViewProjectionCB.MVP[1][0],
                          ModelViewProjectionCB.MVP[1][1],
			  ModelViewProjectionCB.MVP[1][2],
			  ModelViewProjectionCB.MVP[1][3]);
			  */
			  matrix a = ModelViewProjectionCB.MVP;
float4 color = a._m10_m11_m12_m13;

    matrix m = { m0.x,m0.y,m0.z,m0.w,
                 m1.x,m1.y,m1.z,m1.w,
	         m2.x,m2.y,m2.z,m2.w,
	         m3.x,m3.y,m3.z,m3.w};
		 
   m = WorldProjectionCB.MVP;
//m = transpose(m);

    float4 world_p = mul(float4(IN.Position,1.0f),m);

//    OUT.m_color = float4(m0.xyz,(float)offset);    
    OUT.Position = world_p;
    OUT.Color = color;//float4(1,1,1,1);
    OUT.UV = float2(0,0);
    OUT.normal = IN.normal;
    return OUT;
}
