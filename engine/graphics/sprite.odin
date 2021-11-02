package graphics

import e_math "../math"
import con "../containers"
import mem "core:mem"


Texture2D :: struct{
	quad_mesh : ^Mesh,
	material : RenderMaterial,
}


/*
InstanceProperties :: struct{
	mat : e_math.f4x4,
	color : e_math.f4,
	tex_id_unused : e_math.f4,
	uvs : e_math.f2,
}



FastDraw :: struct{
	mats : con.Buffer(e_math.f4x4),
	mesh : ^Mesh,
	material : RenderMaterial,
	mat : e_math.f4x4,
	properties : con.Buffer(InstanceProperties),
}
*/

create_quad :: proc(ctx : ^AssetContext,width : f32 = 1, height : f32 = 1) -> Mesh{
        using e_math
        using con
        using mem
        // Create a quad mesh.
		mesh := Mesh{};
        w := width * .5
        h := height * .5

        vertices : [4]f3 = {
        	f3 { -w , -h , 0},
        	f3 { w , -h , 0},
        	f3{ -w , h , 0},
        	f3{w,h,0},
        }

		indices : [6]u32 = {
			//lower left tri
			0,2,1,
			//lower right tri
			2,3,1,
		}

		z_forward := f3{0,0,-1}
		normals : [4]f3 = {
			z_forward,z_forward,z_forward,z_forward,
		}

		uv : [4]f2 = {
			f2{0,0},
			f2{1,0},
			f2{0,1},
			f2{1,1},
		}
		mesh_id := buf_len(ctx.asset_tables.meshes)
		mesh.name = "quad";	
		indices_size := cast(int)len(indices) * size_of(u32)
		outindex_f := cast(^u32)mem.alloc(cast(int)indices_size)
		mem.copy(outindex_f,&indices,cast(int)indices_size)
		mesh.index_32_data = outindex_f;
		mesh.index_32_data_size = size_of(u32) * cast(u64)len(indices);
		mesh.index32_count = cast(u64)len(indices);


		verts_size := len(vertices) * size_of(f3)
		out_vert := cast(^f32)mem.alloc(cast(int)verts_size);
		mem.copy(out_vert,&vertices,cast(int)verts_size)

        mesh.vertex_data = out_vert
		mesh.vertex_data_size = cast(u64)verts_size
		mesh.vertex_count = cast(u64)len(vertices)

		normals_size := len(normals) * size_of(f3)
		out_normals := cast(^f32)mem.alloc(cast(int)normals_size);
		mem.copy(out_normals,&normals,cast(int)normals_size)
		
        mesh.normal_data = out_normals
		mesh.normal_data_size = cast(u64)normals_size
		mesh.normal_count = cast(u64)len(normals)


		uvs_size := len(uv) * size_of(f2)
		out_uv := cast(^f32)mem.alloc(cast(int)uvs_size);
		mem.copy(out_uv,&uv,cast(int)uvs_size)
		
        mesh.uv_data = out_uv
		mesh.uv_data_size = cast(u64)uvs_size
		mesh.uv_count = cast(u64)len(uv)
		
		previous_mesh_id := buf_len(ctx.asset_tables.meshes);
		id := buf_push(&ctx.asset_tables.meshes,mesh);
		range := f2{cast(f32)previous_mesh_id,cast(f32)id};
//upload mesh
		upload_meshes(ctx,range)


        return mesh;
}


