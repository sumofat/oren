package graphics

import e_math "../math"
import con "../containers"
import mem "core:mem"
import pkg_entity "../entity"
import linalg "core:math/linalg"
import strings "core:strings"
import platform "../platform"
SpriteLayer :: struct{
	projection_m_id : u64,
	camera_m_id : u64,
	texture_id : u64,
	arch_id : pkg_entity.EntityBucketKey,
	buffer_id : u64,
}

Sprite :: struct{
	
	material : RenderMaterial,
	m_id : u64,
	proj_id : u64,
	texture_id : u64,
	visible : bool,
}

default_sprite_path :: "data/asteroid.png"
sprite_layers : con.Buffer(SpriteLayer)
quad_mesh_id : u64
global_texture_id : u64
default_layer_id : u64
//sprite_buffers : con.Buffer(con.Buffer(Sprite))
sprite_buffers : [dynamic]con.Buffer(Sprite)
MAX_LAYERS :: 10
test_sprite_buffer : con.Buffer(Sprite)

set_sprite_trs :: proc(layer : ^SpriteLayer,sprite_id : u64,p : e_math.f3,r : e_math.Quat,s : e_math.f3){
	using asset_ctx

	current_layer := layer
	if current_layer == nil{
		current_layer = con.buf_ptr(&sprite_layers,default_layer_id)
	}
	sprite := get_sprite(current_layer,sprite_id)
	sprite_matrix := con.buf_ptr(&asset_tables.matrix_buffer,sprite.m_id)

	mat := con.buf_get(&asset_tables.matrix_buffer,u64(sprite.proj_id))

	trs_mat := linalg.matrix4_from_trs(p,r,s)
	mul_mat := linalg.matrix_mul(mat,trs_mat)
	sprite_matrix^ = mul_mat
}

get_sprite :: proc(layer : ^SpriteLayer,sprite_id : u64) -> ^Sprite{
	current_layer := layer
	if current_layer == nil{
		current_layer = con.buf_ptr(&sprite_layers,default_layer_id)
	}
	ptr := con.buf_ptr(&sprite_buffers[current_layer.buffer_id],sprite_id)
	assert(ptr != nil)
	return ptr
}

add_sprite :: proc(layer : ^SpriteLayer,p : e_math.f3,r : e_math.Quat,s : e_math.f3,texture_name : string = "") -> u64{
	using e_math
	result : Sprite
	result.visible = true
	result.material = asset_ctx.asset_tables.materials["mesh_alpha"]
	current_layer := layer
	if current_layer == nil{
		current_layer = con.buf_ptr(&sprite_layers,default_layer_id)
		current_layer.buffer_id = 0
	}

	new_e := pkg_entity.create_entity(current_layer.arch_id)
	m : f4x4
	mat := con.buf_get(&asset_ctx.asset_tables.matrix_buffer,u64(current_layer.projection_m_id))
	trs_mat := linalg.matrix4_from_trs_f32(p,r,s)
	m = linalg.matrix_mul(mat,trs_mat)
	result.m_id = con.buf_push(&asset_ctx.asset_tables.matrix_buffer,m)
	result.proj_id = current_layer.projection_m_id

//add texture
	if texture_name == ""{
		result.texture_id = current_layer.texture_id
	}else{
		//TODO(Ray):ensure the same texture doesnt get loaded twice or the gpu references  the same  texture
		tex := texture_from_file(strings.clone_to_cstring(texture_name),4)
		result.texture_id = texture_add(&asset_ctx,&tex,&default_srv_desc_heap)
	}
	sprite_buffer : ^con.Buffer(Sprite) = &sprite_buffers[current_layer.buffer_id]
	return con.buf_push(sprite_buffer,result)
	//return con.buf_push(&test_sprite_buffer,result)
	//return con.buf_push(con.buf_ptr(&sprite_buffers,current_layer.buffer_id),result)
}

sprite_update :: proc(entity_bucket : ^pkg_entity.EntityBucket,data : rawptr){
	using pkg_entity

	mesh := con.buf_get(&asset_ctx.asset_tables.meshes,quad_mesh_id)

	for b ,i in entity_bucket.entities.buffer{
		
		ecs_sprites := (^con.Buffer(Sprite))(data)

		sprite := con.buf_ptr(ecs_sprites,u64(i))
		if sprite.visible{
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
			com.texture_id = sprite.texture_id
			com.matrix_id = sprite.m_id//child_so.m_id
			///com.camera_matrix_id = sprite_group.camera_m_id
			//com.perspective_matrix_id = sprite_group.projection_m_id//p_mat
			con.buf_push(&custom_render.list.command_buffer, com)
		}
	}
}

SpriteCameraSettings :: struct{
	projection_m_id : u64,
	camera_m_id : u64,
}

default_camera_settings : SpriteCameraSettings

SpriteLayerDescriptor :: struct{
	texture_name : string,
	tag : u64,
	camera : RenderCamera,

}

create_sprite_layer :: proc(texture_name : string,tag : u64,camera_settins : SpriteCameraSettings = default_camera_settings) -> ^SpriteLayer{
	assert(MAX_LAYERS != len(sprite_buffers))
	using platform.ps
	using e_math
	new_layer : SpriteLayer
	
	//new_sprite_buffer := con.buf_init(1,Sprite)
	//new_sprite_buffer_ptr := con.buf_ptr(&sprite_buffers,new_sprite_buffer_id)
	new_sprite_buffer_id := len(sprite_buffers)//con.buf_push(&sprite_buffers,new_sprite_buffer)
	append(&sprite_buffers,con.buf_init(1,Sprite))
	new_layer.buffer_id = u64(new_sprite_buffer_id)
	
	projection_m := init_ortho_proj_matrix(window.dim * 0.1,0.0,1.0);
	camera_m := f4x4_identity
	new_layer.camera_m_id = con.buf_push(&asset_ctx.asset_tables.matrix_buffer,camera_m)
	new_layer.projection_m_id = con.buf_push(&asset_ctx.asset_tables.matrix_buffer,projection_m)

	ok,new_layer_arch_id  := pkg_entity.get_archetype([]typeid{typeid_of(Sprite)},[]rawptr{rawptr(&sprite_buffers[new_layer.buffer_id])},tag)
	new_layer.arch_id = new_layer_arch_id
	pkg_entity.create_system(sprite_update,new_layer_arch_id)

	if texture_name != ""{
		tex := texture_from_file(strings.clone_to_cstring(texture_name),4)
		new_layer.texture_id = texture_add(&asset_ctx,&tex,&default_srv_desc_heap)
	}

	id := con.buf_push(&sprite_layers,new_layer)
	return con.buf_ptr(&sprite_layers,id)
}

init_sprite_render_system :: proc(){
	using e_math
	using platform.ps
	layer : SpriteLayer
	//this layer is the default layer
	//when setting up a sprite if no layer is sspecified this is the layer that will be used.
	create_quad(1,1)
	sprite_layers = con.buf_init(MAX_LAYERS,SpriteLayer)
	projection_m := init_ortho_proj_matrix(window.dim * 0.1,0.0,1.0);
	camera_m := f4x4_identity
	layer.camera_m_id = con.buf_push(&asset_ctx.asset_tables.matrix_buffer,camera_m)
	layer.projection_m_id = con.buf_push(&asset_ctx.asset_tables.matrix_buffer,projection_m)
	layer.buffer_id = 0

	default_camera_settings.projection_m_id = layer.projection_m_id
	default_camera_settings.camera_m_id = layer.camera_m_id


	//sprite_buffers = con.buf_init(1,con.Buffer(Sprite))
	sprite_buffers = make([dynamic]con.Buffer(Sprite),0,MAX_LAYERS)
	append(&sprite_buffers,con.buf_init(1,Sprite))
	//new_sprite_buffer_id := con.buf_push(&sprite_buffers,new_sprite_buffer)
	//new_sprite_buffer_ptr := con.buf_ptr(&sprite_buffers,0)

	//test := con.buf_ptr(&sprite_buffers,new_sprite_buffer_id)
	//assert(con.buf_len(test^) == 0)
	//test_sprite_buffer = con.buf_init(1,Sprite)

	ok,sprite_arch_id := pkg_entity.get_archetype([]typeid{typeid_of(Sprite)},[]rawptr{rawptr(&sprite_buffers[0])},0)
	
//rawptr(&asset_ctx.asset_tables.sprites)
	//ok,sprite_arch_id := pkg_entity.get_archetype([]typeid{typeid_of(Sprite)},[]rawptr{rawptr(&asset_ctx.asset_tables.sprites)})
	layer.arch_id = sprite_arch_id
	pkg_entity.create_system(sprite_update,sprite_arch_id)
	//NOTE(Ray): will be default texture for this layer unless excplicitly set in add_sprite
	tex := texture_from_file(strings.clone_to_cstring(default_sprite_path),4)
	layer.texture_id = texture_add(&asset_ctx,&tex,&default_srv_desc_heap)
	default_layer_id := con.buf_push(&sprite_layers,layer)

}

create_quad :: proc(width : f32 = 1, height : f32 = 1) -> Mesh{
        using e_math
        using con
        using mem
        using asset_ctx
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
	mesh_id := buf_len(asset_tables.meshes)

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
	
	previous_mesh_id := buf_len(asset_tables.meshes)
	id := buf_push(&asset_tables.meshes,mesh)
	quad_mesh_id = id

	range := f2{cast(f32)id,cast(f32)id}
	//upload mesh
	upload_meshes(range)

    	return mesh;
}



