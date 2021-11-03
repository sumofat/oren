package graphics

import e_math "../math"
import con "../containers"
import mem "core:mem"
import pkg_entity "../entity"
import linalg "core:math/linalg"

SpriteGroup :: struct{
	asset_ctx : ^AssetContext,
	projection_m_id : u64,
	camera_m_id : u64,
	sprites	: con.Buffer(Sprite),
	arch_id : pkg_entity.EntityBucketKey,
	render_list : ^RenderCommandList(CustomRenderCommandList),
}

Sprite :: struct{
	material : RenderMaterial,
	m_id : u64,
}

sprite_group : SpriteGroup
quad_mesh_id : u64

add_sprite :: proc(p : e_math.f3,s : e_math.f3,r : e_math.Quat){
	using e_math

	result : Sprite
	result.material = sprite_group.asset_ctx.asset_tables.materials["mesh_alpha"]
	new_e := pkg_entity.create_entity(sprite_group.arch_id)
	m : f4x4
	//TODO(Ray):have to verify this matrix is in the right memory layout
	m = linalg.matrix4_from_trs_f32 (p,r,s) *  con.buf_get(&sprite_group.asset_ctx.asset_tables.matrix_buffer,u64(sprite_group.projection_m_id))
	result.m_id = con.buf_push(&sprite_group.asset_ctx.asset_tables.matrix_buffer,m)
	con.buf_push(&asset_ctx.asset_tables.sprites,result)
}

sprite_update :: proc(entity_bucket : ^pkg_entity.EntityBucket,data : rawptr){
	using pkg_entity

	mesh := con.buf_get(&sprite_group.asset_ctx.asset_tables.meshes,quad_mesh_id)

	for b ,i in entity_bucket.entities.buffer{
		
		ecs_sprites := (^con.Buffer(Sprite))(data)

		sprite := con.buf_ptr(ecs_sprites,u64(i))
		com := CustomRenderCommand{}
		geo := RenderGeometry{}
		com.is_indexed = true
		geo.buffer_id_range = mesh.mesh_resource.buffer_range
		geo.index_id = cast(u64)mesh.mesh_resource.index_id
		geo.index_count = mesh.index32_count
		geo.offset = 0
		geo.base_color = mesh.base_color
		com.geometry = geo

		com.material_id = cast(u64)mesh.material_id
		com.material_name = "mesh_alpha"
		com.texture_id = mesh.metallic_roughness_texture_id
		com.matrix_id = sprite.m_id//child_so.m_id
		///com.camera_matrix_id = sprite_group.camera_m_id
		//com.perspective_matrix_id = sprite_group.projection_m_id//p_mat
		con.buf_push(&sprite_group.render_list.list.command_buffer, com)

	}
}

create_sprite_render_system :: proc(ctx : ^AssetContext,render_list : ^RenderCommandList(CustomRenderCommandList)){
	using e_math
	create_quad(ctx,1,1)
	sprite_group.sprites = con.buf_init(1,Sprite)
	sprite_group.asset_ctx = ctx
	projection_m := init_ortho_proj_matrix(f2{100,100},0.0,1.0);
	camera_m := f4x4_identity
	sprite_group.camera_m_id = con.buf_push(&sprite_group.asset_ctx.asset_tables.matrix_buffer,camera_m)
	sprite_group.projection_m_id = con.buf_push(&sprite_group.asset_ctx.asset_tables.matrix_buffer,projection_m)

	ok,sprite_arch_id := pkg_entity.get_archetype([]typeid{typeid_of(Sprite)},[]rawptr{rawptr(&sprite_group.asset_ctx.asset_tables.sprites)})
	sprite_group.arch_id = sprite_arch_id
	pkg_entity.create_system(sprite_update,sprite_arch_id)
	sprite_group.render_list = render_list

}

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
	
	previous_mesh_id := buf_len(ctx.asset_tables.meshes)
	id := buf_push(&ctx.asset_tables.meshes,mesh)
	quad_mesh_id = id

	range := f2{cast(f32)id,cast(f32)id}
//upload mesh
	upload_meshes(ctx,range)

    return mesh;
}



