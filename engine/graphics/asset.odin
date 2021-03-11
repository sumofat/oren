package graphics

import "core:fmt"
import "core:c"
import "core:mem"
import strings "core:strings"
import la "core:math/linalg"

import platform "../platform"
import "../external/cgltf"
import "../external/odin_stb/stbi"

import windows "core:sys/windows"
import window32 "core:sys/win32"

import con "../containers"

asset_ctx : AssetContext;

Texture :: struct
{
    texels : rawptr
    dim : f2,
    size : u32,
    bytes_per_pixel : u32,
    width_over_height : f32,// TODO(Ray Garner): probably remove
    align_percentage : f2,// TODO(Ray Garner): probably remove this
    channel_count : u32,//grey = 1: grey,alpha = 2,rgb = 3,rgba = 4
    //    Texture texture : Texture,
    state : rawptr,// NOTE(Ray Garner): temp addition
    slot : u32,
};

Sprite :: struct
{
    id : u64,
    tex_id : u32,
    uvs : [4]f2,
    color : f4,
    is_visible : bool,
    material_name : string,
};

VertCompressionType :: enum
{
    none
};

IndexComponentSize :: enum
{
    none = 0,
    size_32 = 1,
    size_16 = 2
};

Mesh :: struct
{
    id : u32,
    name : string,
    compression_type : VertCompressionType,
    
    vertex_data : ^f32,
    vertex_data_size : u64,
    vertex_count : u64,
    tangent_data : ^f32,
    tangent_data_size : u64,
    tangent_count : u64,
    bi_tangent_data : ^f32,
    bi_tangent_data_size : u64,
    bi_tangent_count : u64,
    normal_data : ^f32,
    normal_data_size : u64,
    normal_count : u64,
    uv_data : ^f32,
    uv_data_size : u64,
    uv_count : u64,
    //NOTE(Ray):We are only support max two uv sets
    uv2_data : ^f32,
    uv2_data_size : u64,
    uv2_count : u64,
    
    index_component_size : IndexComponentSize,
    //TODO(Ray):These are seriously problematic and ugly will be re working these.
    index_32_data : ^u32,
    index_32_data_size : u64,
    index32_count : u64,
    index_16_data : ^u16,
    index_16_data_size : u64,
    index16_count : u64,
    mesh_resource : GPUMeshResource,    
    material_id : u32,
    material_name : string,    
    metallic_roughness_texture_id : u64,

    base_color : f4,
};

Model :: struct
{
    id : u32,
    model_name : string,
    meshes : con.Buffer(Mesh),
};

ModelLoadResult :: struct
{
    is_success : bool,
//    FMJAssetModel model;
    scene_object_id : u64,//instance id of the model created as a scene object  node 
//    FMJSceneObject scene_object;
};

RenderMaterial :: struct
{
    id : u64,
    name : string,
    pipeline_state : rawptr,//finalized depth stencil state etc... 
    scissor_rect : f4,
    viewport_rect : f4,
    metallic_roughness_texture_id : u64,
    base_color : f4
};

load_meshes_recursively_gltf_node ::  proc(result : ^ModelLoadResult,node : cgltf.node,ctx : ^AssetContext,file_path : cstring, material : RenderMaterial,so_id : u64)
{
    for i := 0;i < cast(int)node.children_count;i+=1
    {
        child_ptr := mem.ptr_offset(node.children,i);//cgltf.node
        child : ^cgltf.node = child_ptr^;	
        trans := transform_init();

        out_mat := la.MATRIX4_IDENTITY;
        if child.has_matrix == 1
        {
                    
            out_mat = f4x4{{child.matrix[0],child.matrix[1],child.matrix[2],child.matrix[3]},
                           {child.matrix[4],child.matrix[5],child.matrix[6],child.matrix[7]},
                           {child.matrix[8],child.matrix[9],child.matrix[10],child.matrix[11]},
                           {child.matrix[12],child.matrix[13],child.matrix[14],child.matrix[15]}};                                        
        }
        else
        {
            cgltf.node_transform_world(child,  cast(^cgltf.cgltf_float)&out_mat);
        }

        trans.p = f3{out_mat[3].x,out_mat[3].y,out_mat[3].z};
        trans.s = f3{la.length(f3{out_mat[0].x,out_mat[0].y,out_mat[0].z}),
                     la.length(f3{out_mat[1].x,out_mat[1].y,out_mat[1].z}),
                     la.length(f3{out_mat[2].x,out_mat[2].y,out_mat[2].z})};
        trans.r = la.quaternion_from_matrix4(out_mat);
        trans.m = out_mat;                    

        type : u32 = 0;
        mesh_range := f2{};
        if child.mesh != nil
        {
//            result.model.model_name = string(file_path);
            mesh_range = create_mesh_from_cgltf_mesh(ctx,child.mesh,material);
            type = 1;
            upload_meshes(ctx,mesh_range);            
        }

	mptr : rawptr = nil;
//add node to parent
        //TODO(Ray):We need this not to be associated with the context perm mem.
        //Have each sceneobject tree hold its own string meme
        mesh_name := string(child.name);
        child_id := add_child_to_scene_object_with_transform(ctx,so_id,&trans,&mptr,mesh_name);
        child_so := con.buf_chk_out(&ctx.scene_objects,child_id);
        child_so.type = type;
        child_so.primitives_range = mesh_range;
        con.buf_chk_in(&ctx.scene_objects);                    	
        load_meshes_recursively_gltf_node(result,child^,ctx,file_path, material,child_id);
    }
}

asset_load_model :: proc(ctx : ^AssetContext,file_path : cstring,material : RenderMaterial) -> ModelLoadResult
{
    using con;
    result : ModelLoadResult;
    is_success := false;

    mem_options : cgltf.memory_options;

    options : cgltf.options;
    cgltf_data : ^cgltf.data;
    aresult := cgltf.parse_file(&options,file_path, &cgltf_data);    
    assert(aresult == cgltf.result.result_success);
    if cast(cgltf.result)aresult == cgltf.result.result_success
    {
	
        for i := 0;i < cast(int)cgltf_data.buffers_count;i += 1
        {
	    uri := mem.ptr_offset(cgltf_data.buffers,i).uri;
            rs := cgltf.load_buffers(&options, cgltf_data, uri);
            assert(rs == cgltf.result.result_success);
        }
        //TODO(ray):If we didnt  get a mesh release any memory allocated.
        if cgltf_data.nodes_count > 0
        {
            parent_trans := transform_init();
            p_matrix_id := buf_push(&ctx.asset_tables.matrix_buffer,parent_trans.m);

            model_root_so_ : SceneObject = scene_object_init("model_root_so");
            model_root_so_id := buf_push(&ctx.scene_objects,model_root_so_);
            assert(cgltf_data.scenes_count == 1);
	    scenes_count := mem.ptr_offset(cgltf_data.scenes,0).nodes_count;	    
            for i := 0;i < cast(int)scenes_count;i+=1
            {
		root_scene := mem.ptr_offset(cgltf_data.scenes,0);
                root_node : ^cgltf.node = mem.ptr_offset(root_scene.nodes,i)^;
		
                trans := transform_init();
                out_mat := la.MATRIX4_IDENTITY;
                if root_node.has_matrix == 1
                {
                    out_mat = f4x4{{root_node.matrix[0],root_node.matrix[1],root_node.matrix[2],root_node.matrix[3]},
                                   {root_node.matrix[4],root_node.matrix[5],root_node.matrix[6],root_node.matrix[7]},
                                   {root_node.matrix[8],root_node.matrix[9],root_node.matrix[10],root_node.matrix[11]},
                                   {root_node.matrix[12],root_node.matrix[13],root_node.matrix[14],root_node.matrix[15]}};                                        
                }
                else
                {
                    cgltf.node_transform_world(root_node, cast(^cgltf.cgltf_float)&out_mat);
                }

                trans.p = f3{out_mat[3].x,out_mat[3].y,out_mat[3].z};
                trans.s = f3{la.length(f3{out_mat[0].x,out_mat[0].y,out_mat[0].z}),
                             la.length(f3{out_mat[1].x,out_mat[1].y,out_mat[1].z}),
                             la.length(f3{out_mat[2].x,out_mat[2].y,out_mat[2].z})};
                trans.r = la.quaternion_from_matrix4(out_mat);
                trans.m = out_mat;

                type : u32 = 0;
                mesh_range := f2{};
                if root_node.mesh != nil
                {
//                    result.model.model_name = string(file_path_mem);                
                    mesh_range = create_mesh_from_cgltf_mesh(ctx,root_node.mesh,material);
                    type = 1;
                    upload_meshes(ctx,mesh_range);
                }

                mptr : rawptr = nil;
                mesh_name := string(root_node.name);                
                child_id := add_child_to_scene_object_with_transform(ctx,model_root_so_id,&trans,&mptr,mesh_name);
                child_so := buf_chk_out(&ctx.scene_objects,child_id);
                child_so.type = type;
                child_so.primitives_range = mesh_range;
                buf_chk_in(&ctx.scene_objects);		
		load_meshes_recursively_gltf_node(&result,root_node^,ctx,file_path,material,child_id);
            }

            buf_chk_in(&ctx.scene_objects);
            result.scene_object_id = model_root_so_id;	    
	}

        cgltf.free(cgltf_data);	
    }

    return result;        
}

create_mesh_from_cgltf_mesh  :: proc(ctx : ^AssetContext,ma : ^cgltf.mesh,material : RenderMaterial) -> f2
{
    using con;
    assert(ma != nil);
    mesh_id := buf_len(ctx.asset_tables.meshes);
    
    result := f2{cast(f32)mesh_id,cast(f32)mesh_id};

    for j := 0;cast(uint)j < ma.primitives_count; j += 1
    {
        mesh := Mesh{};
        prim := mem.ptr_offset(ma.primitives,j);
        mat  := prim.material;

        if mat.normal_texture.texture != nil
        {
//            tv := mat.normal_texture;
        }

        if mat.occlusion_texture.texture != nil
        {
//            tv := mat.occlusion_texture;
        }
	
        if mat.emissive_texture.texture != nil
        {
//            tv := mat.emissive_texture;
        }

        if mat.has_pbr_metallic_roughness == 1
        {
            if mat.pbr_metallic_roughness.base_color_texture.texture != nil
            {
                tv := mat.pbr_metallic_roughness.base_color_texture;
                {
                    offset := cast(u64)tv.texture.image.buffer_view.offset;
                    tex_data := mem.ptr_offset(cast(^u8)tv.texture.image.buffer_view.buffer.data,cast(int)offset);

		    //TODO(Ray):This if statement is not good
                    if tex_data != nil
                    {
                        data_size := cast(u64)tv.texture.image.buffer_view.size;
			tex :=  texture_from_mem(tex_data,cast(i32)data_size,4);                
                        id := texture_add(ctx,&tex,default_srv_desc_heap);
                        mesh.metallic_roughness_texture_id = id;                    
                    }                    
                }
            }

            if mat.pbr_metallic_roughness.metallic_roughness_texture.texture != nil
            {
//                tv := mat.pbr_metallic_roughness.metallic_roughness_texture;
            }

            bcf := mat.pbr_metallic_roughness.base_color_factor;
            mesh.base_color = f4{bcf[0],bcf[1],bcf[2],bcf[3]};

//            cgltf_float* mf = &mat.pbr_metallic_roughness.metallic_factor;
//            cgltf_float* rf = &mat.pbr_metallic_roughness.roughness_factor;
        }

        if mat.has_pbr_specular_glossiness == 1
        {
            if mat.pbr_specular_glossiness.diffuse_texture.texture != nil
            {
//                tv := mat.pbr_specular_glossiness.diffuse_texture;
            }

            if mat.pbr_specular_glossiness.specular_glossiness_texture.texture != nil
            {
//                tv := mat.pbr_specular_glossiness.specular_glossiness_texture;
            }

            dcf := mat.pbr_specular_glossiness.diffuse_factor;
            diffuse_value := f4{dcf[0],dcf[1],dcf[2],dcf[3]};
            sf := mat.pbr_specular_glossiness.specular_factor;
            specular_value := f3{sf[0],sf[1],sf[2]};
            gf := &mat.pbr_specular_glossiness.glossiness_factor;
        }

        //alphaCutoff
        //alphaMode
        //emissiveFactor
        //emissiveTexture
        //occlusionTexture
        //normalTexture

        mesh.name = string(ma.name);
        mesh.material_id = 0;

        if prim.type == cgltf.primitive_type.primitive_type_triangles
        {
            has_got_first_uv_set := false;

            if prim.indices != nil
            {
                istart_offset := prim.indices.offset + prim.indices.buffer_view.offset;
                ibuf := prim.indices.buffer_view.buffer;                
                if prim.indices.component_type == cgltf.component_type.component_type_r_16u
                {
                    indices_size :=  cast(u64)prim.indices.count * size_of(u16);
                    indices_buffer := cast(^u16)mem.ptr_offset(cast(^u8)ibuf.data,cast(int)istart_offset);
                    outindex_f := cast(^u16)mem.alloc(cast(int)indices_size);
                    
                    mem.copy(outindex_f,indices_buffer,cast(int)indices_size);
                    mesh.index_16_data = outindex_f;
                    mesh.index_16_data_size = size_of(u16) * cast(u64)prim.indices.count;
                    mesh.index16_count = cast(u64)prim.indices.count;                    
                }

                else if prim.indices.component_type == cgltf.component_type.component_type_r_32u
                {
                    indices_size :=  cast(u64)prim.indices.count * size_of(u32);
                    indices_buffer := cast(^u32)(mem.ptr_offset(cast(^u8)ibuf.data,cast(int)istart_offset));
		    outindex_f := cast(^u32)mem.alloc(cast(int)indices_size);

                    mem.copy(outindex_f,indices_buffer,cast(int)indices_size);
                    mesh.index_32_data = outindex_f;
                    mesh.index_32_data_size = size_of(u32) * cast(u64)prim.indices.count;
                    mesh.index32_count = cast(u64)prim.indices.count;                    
                }
            }
            
            for k := 0;k < cast(int)prim.attributes_count; k += 1
            {
                ac := mem.ptr_offset(prim.attributes,k);

                acdata := ac.data;
                count := acdata.count;
		bf := acdata.buffer_view;
                {
                    start_offset := bf.offset;
                    stride := bf.stride;
                    buf := bf.buffer;
                    buffer := (^f32)(mem.ptr_offset(cast(^u8)buf.data,cast(int)start_offset));

                    if acdata.is_sparse == 1
                    {
                        assert(false);
                    }

                    num_floats := acdata.count * cgltf.num_components(acdata.type);
                    num_bytes := size_of(f32) * num_floats;                
                    outf := cast(^cgltf.cgltf_float)mem.alloc(cast(int)num_bytes);
                    csize := cgltf.accessor_unpack_floats(acdata,outf,num_floats);

                    if ac.type == cgltf.attribute_type.attribute_type_position
                    {
                        mesh.vertex_data = outf;
                        mesh.vertex_data_size = cast(u64)num_bytes;
                        mesh.vertex_count = cast(u64)count;
                    }

                    else if ac.type == cgltf.attribute_type.attribute_type_normal
                    {
                        mesh.normal_data = outf;
                        mesh.normal_data_size = cast(u64)num_bytes;
                        mesh.normal_count = cast(u64)count;
                    }

                    else if ac.type == cgltf.attribute_type.attribute_type_tangent
                    {
                        mesh.tangent_data = outf;
                        mesh.tangent_data_size = cast(u64)num_bytes;
                        mesh.tangent_count = cast(u64)count;
                    }

//NOTE(Ray):only support two set of uv data for now.
                    else if ac.type == cgltf.attribute_type.attribute_type_texcoord && !has_got_first_uv_set
                    {
                        mesh.uv_data = outf;
                        mesh.uv_data_size = cast(u64)num_bytes;
                        mesh.uv_count = cast(u64)count;
                        has_got_first_uv_set = true;
                    }
                
                    else if ac.type == cgltf.attribute_type.attribute_type_texcoord && has_got_first_uv_set
                    {
                        mesh.uv2_data = outf;
                        mesh.uv2_data_size = cast(u64)num_bytes;
                        mesh.uv2_count = cast(u64)count;
                        has_got_first_uv_set = true;                        
                    }                    
                }
            }
        }
	
        mesh.material_id = cast(u32)material.id;
	mesh.material_name = material.name;

        last_id  := buf_push(&ctx.asset_tables.meshes,mesh);
	//TODO(Ray):Does this cast properly? verify
        result.y = cast(f32)last_id;

    }

    return result;    
}

/*
// NOTE(Ray Garner): We give the ability to pass in channels
//because we dont do swizzling the channels here yet. 
//For now we assume the data on disk has been preconditioned 
//the way we need it but this may not always be the case.

void get_image_from_disc(char* file,LoadedTexture* loaded_texture,int desired_channels)
{

    
    int dimx;
    int dimy;
    //NOTE(Ray):Depends on your pipeline wether or not you will need this or not.
#if IOS
    //    stbi_convert_iphone_png_to_rgb(0);
    //    stbi_set_unpremultiply_on_load(1);
    stbi_set_flip_vertically_on_load(true);    
#endif
    int comp;
    stbi_info(file,&dimx, &dimy, &comp);
        
    loaded_texture->texels = stbi_load(file, (&dimx), (&dimy), (int*)&loaded_texture->channel_count, desired_channels);
    loaded_texture->dim = f2_create(dimx, dimy);
    loaded_texture->width_over_height = dimx/dimy;
    // NOTE(Ray Garner):stbi_info always returns 8bits/1byte per channels if we want to load 16bit or float need to use a 
    //a different api. for now we go with this. 
    //Will probaby need a different path for HDR textures etc..
    loaded_texture->bytes_per_pixel = desired_channels;
    loaded_texture->align_percentage = f2_create(0.5f,0.5f);
    loaded_texture->channel_count = desired_channels;
    loaded_texture->texture = {};
    loaded_texture->size = dimx * dimy * loaded_texture->bytes_per_pixel;
}
    
LoadedTexture get_loaded_image(char* file,int desired_channels)
{
    LoadedTexture tex;
    get_image_from_disc(file,&tex,desired_channels);
    ASSERT(tex.texels);
    return tex;
}

*/

image_from_mem :: proc(ptr : ^u8,size : i32,texture : ^Texture ,desired_channels : i32)
{
    dimx : i32;
    dimy : i32;
    //NOTE(Ray):Depends on your pipeline wether or not you will need this or not.
    //IOS not supported RN
//when os.IOS{
//    stbi_set_flip_vertically_on_load(true);    
    //}
    comp : i32;
    stbi.info_from_memory(ptr,size,&dimx, &dimy, &comp);

    texture.texels = stbi.load_from_memory(ptr,size,&dimx,&dimy,cast(^i32)&texture.channel_count,desired_channels);

    texture.dim = f2{cast(f32)dimx,cast(f32)dimy};
    texture.width_over_height = cast(f32)(dimx / dimy);

    // NOTE(Ray Garner):stbi_info always returns 8bits/1byte per channels if we want to load 16bit or float need to use a 
    //a different api. for now we go with this. 
    //Will probaby need a different path for HDR textures etc..
    texture.bytes_per_pixel = cast(u32)desired_channels;
    texture.align_percentage = f2{0.5,0.5};
    texture.channel_count = cast(u32)desired_channels;
//    texture.texture = {};
    texture.size = cast(u32)(dimx * dimy * cast(i32)texture.bytes_per_pixel);
}
    
texture_from_mem :: proc(ptr : ^u8,size : i32,desired_channels : i32) -> Texture
{
    tex : Texture;
    image_from_mem(ptr,size,&tex,desired_channels);
    assert(tex.texels != nil);
    return tex;
}

texture_add :: proc(ctx : ^AssetContext,texture : ^Texture,heap : platform.ID3D12DescriptorHeap) -> u64
{
    using con;
    tex_id := buf_push(&ctx.asset_tables.textures,texture^);

    hmdh_size : u32 = GetDescriptorHandleIncrementSize(device.device,platform.D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);
    hmdh := platform.GetCPUDescriptorHandleForHeapStart(heap.value);
    offset : u64 = cast(u64)hmdh_size * cast(u64)tex_id;
    hmdh.ptr = hmdh.ptr + cast(windows.SIZE_T)offset;

    srvDesc2 : platform.D3D12_SHADER_RESOURCE_VIEW_DESC;
    srvDesc2.Shader4ComponentMapping = platform.D3D12_ENCODE_SHADER_4_COMPONENT_MAPPING(0,1,2,3);
    srvDesc2.Format = platform.DXGI_FORMAT.DXGI_FORMAT_R8G8B8A8_UNORM;
    srvDesc2.ViewDimension = platform.D3D12_SRV_DIMENSION.D3D12_SRV_DIMENSION_TEXTURE2D;
    srvDesc2.Buffer.Texture2D.MipLevels = 1;

    tex_resource : platform.D12Resource;

    using platform;                

    sd : DXGI_SAMPLE_DESC =
	{
	    1,0
	};
    
    res_d : D3D12_RESOURCE_DESC  = {
	.D3D12_RESOURCE_DIMENSION_TEXTURE2D,
        0,
  	cast(u64)texture.dim.x,
	cast(u32)texture.dim.y,
	1,0,
	.DXGI_FORMAT_R8G8B8A8_UNORM,
	sd,
	.D3D12_TEXTURE_LAYOUT_UNKNOWN,
	.D3D12_RESOURCE_FLAG_NONE,
    };

    hp : D3D12_HEAP_PROPERTIES  =  
        {
	    .D3D12_HEAP_TYPE_DEFAULT,
            .D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
            .D3D12_MEMORY_POOL_UNKNOWN,
            1,
            1
        };
    
    CreateCommittedResource(device.device,
        &hp,
        .D3D12_HEAP_FLAG_NONE,
        &res_d,
        .D3D12_RESOURCE_STATE_COMMON,
        nil,
        &tex_resource);
    
    CreateShaderResourceView(device.device,tex_resource.state, &srvDesc2, hmdh);
    //Texture2D(texture,cast(u32)tex_id,&tex_resource,heap.value);

    texture_2d(texture,cast(u32)tex_id,&tex_resource,heap.value);
    
    //TODO(ray):Add assert to how many textures are allowed in acertain heap that
    //we are using to store the texture on the gpu.
    //texid is a slot on the gpu heap??
//    ASSERT(tex_id < MAX_TEX_ID_FOR_HEAP)
    return tex_id;
}

set_buffer :: proc(ctx : ^AssetContext,buff : ^platform.GPUArena,stride : u32,size : u64,data : ^f32) -> u64
{
    v_size := size;
    buff^ = AllocateStaticGPUArena(v_size);
    SetArenaToVertexBufferView(buff,v_size,stride);
    //UploadBufferData(buff,data,v_size);
    upload_buffer_data(buff,data,v_size);    
    id := con.buf_push(&ctx.asset_tables.vertex_buffers,buff.buffer_view.vertex_buffer_view);
    return id;
}

upload_meshes :: proc(ctx : ^AssetContext,range : f2)
{
    using con;
    for i := range.x;i <= range.y;i+=1
    {
        is_valid := 0;
        mesh_r : GPUMeshResource;
        mesh := buf_chk_out(&ctx.asset_tables.meshes,cast(u64)i);
        id_range := f2{};
        if mesh.vertex_count > 0
        {
            id_range.x = cast(f32)set_buffer(ctx,&mesh_r.vertex_buff,size_of(f32) * 3,mesh.vertex_data_size,mesh.vertex_data);            
            is_valid += 1;
        }
        else
        {
            assert(false);
        }

        start_range := id_range.x;
        
        if mesh.normal_count > 0
        {
            set_buffer(ctx,&mesh_r.normal_buff,size_of(f32) * 3,mesh.normal_data_size,mesh.normal_data);            
            start_range  = start_range + 1.0;
            is_valid  += 1;
        }
        
        if mesh.uv_count > 0
        {
            set_buffer(ctx,&mesh_r.uv_buff,size_of(f32) * 2,mesh.uv_data_size,mesh.uv_data);            	    
            start_range += 1.0;            
            is_valid += 1;
        }
        
        id_range.y = start_range;
        
        if mesh.index32_count > 0
        {
            size := mesh.index_32_data_size;
            mesh_r.element_buff = AllocateStaticGPUArena(size);
            format : platform.DXGI_FORMAT;
            mesh.index_component_size = IndexComponentSize.size_32;
            format = platform.DXGI_FORMAT.DXGI_FORMAT_R32_UINT;                
            SetArenaToIndexVertexBufferView(&mesh_r.element_buff,size,format);
            upload_buffer_data(&mesh_r.element_buff,mesh.index_32_data,size);            
            index_id := buf_push(&ctx.asset_tables.index_buffers,mesh_r.element_buff.buffer_view.index_buffer_view);
            
            mesh_r.index_id = cast(u32)index_id;
            is_valid += 1;
        }
        
        else if mesh.index16_count > 0
        {
            size := mesh.index_16_data_size;
            mesh_r.element_buff = AllocateStaticGPUArena(size);
            format : platform.DXGI_FORMAT;
            mesh.index_component_size = IndexComponentSize.size_16;
            format = platform.DXGI_FORMAT.DXGI_FORMAT_R16_UINT;
	    
            SetArenaToIndexVertexBufferView(&mesh_r.element_buff,size,format);
            upload_buffer_data(&mesh_r.element_buff,mesh.index_16_data,size);            
            index_id := buf_push(&ctx.asset_tables.index_buffers,mesh_r.element_buff.buffer_view.index_buffer_view);
            
            mesh_r.index_id = cast(u32)index_id;
            is_valid += 1;
        }
        
        //NOTE(RAY):For now we require that you have met all the data criteria
        if is_valid >= 1
        {
            mesh_r.buffer_range = id_range;
            mesh.mesh_resource = mesh_r;
        }
        else
        {
            assert(false);
        }

        buf_chk_in(&ctx.asset_tables.meshes);        
    }
}

get_mesh_id_by_name :: proc(name : string,ctx : ^AssetContext, start : ^SceneObject,result : ^u64) -> bool
{
    using con;
    s := cast(int)start.primitives_range.y;
    for i := 0;i <= s;i+=1
    {
        mesh := buf_get(&ctx.asset_tables.meshes,cast(u64)i);
        if strings.compare(mesh.name,name) == 0
        {
            result^ = cast(u64)i;
            return true;
        }
    }

    is_found := false;
    c_l := len(start.children.buffer.buffer);
    for c := 0;c < c_l;c+=1
    {
        c_id := buf_get(&start.children.buffer,cast(u64)c);
        child_so := buf_get(&ctx.scene_objects,c_id);
        is_found := get_mesh_id_by_name(name,ctx,&child_so,result);
        if is_found
        {
            break;
        }
    }
    
    return is_found;
}

create_model_instance :: proc(ctx : ^AssetContext,model : ModelLoadResult) -> u64
{
    using con;
    src := buf_get(&ctx.scene_objects,model.scene_object_id);

    dest_ := copy_scene_object(ctx,&src);

    dest_id := buf_push(&ctx.scene_objects,dest_);

    for i := 0;i < cast(int)buf_len(src.children.buffer);i+=1
    {
        dest := buf_chk_out(&ctx.scene_objects,dest_id);            
        src_child_so_id := buf_get(&src.children.buffer,cast(u64)i);
        src_child_so := buf_get(&ctx.scene_objects,src_child_so_id);
        dest_child_so_ := copy_scene_object(ctx,&src_child_so);

        buf_chk_in(&ctx.scene_objects);
        dest_child_so_id : u64 = buf_push(&ctx.scene_objects,dest_child_so_);
        dest = buf_chk_out(&ctx.scene_objects,dest_id);            
        buf_push(&dest.children.buffer,dest_child_so_id);
        buf_chk_in(&ctx.scene_objects);        
        
        copy_model_data_recursively_(ctx,dest_child_so_id,src_child_so_id);
    }

    return 1;//dest_id;
}

copy_scene_object :: proc(ctx : ^AssetContext,so : ^SceneObject)  -> SceneObject 
{
    using con;
    assert(so != nil);
    result : SceneObject = so^;
    result.children.buffer = buf_copy(&so.children.buffer);
    result.transform = so.transform;
    result.m_id = buf_push(&ctx.asset_tables.matrix_buffer,result.transform.m);

    //    result.data = so.data;
    //    result.type = so.type;
    //    result.primitives_range = so.primitives_range;
    return result;
}

copy_model_data_recursively_ :: proc(ctx : ^AssetContext,dest_id : u64,src_id : u64)
{
    using con;
    src := buf_get(&ctx.scene_objects,src_id);
    for i := 0;i < cast(int)buf_len(src.children.buffer);i+=1
    {
        dest := buf_chk_out(&ctx.scene_objects,dest_id);
           
        child_so_id := buf_get(&src.children.buffer,cast(u64)i);
        child_so := buf_get(&ctx.scene_objects,child_so_id);
	new_child_dest := copy_scene_object(ctx,&child_so);

        buf_chk_in(&ctx.scene_objects);
        new_dest_id := buf_push(&ctx.scene_objects,new_child_dest);
        dest = buf_chk_out(&ctx.scene_objects,dest_id);        
        buf_push(&dest.children.buffer,new_dest_id);
        buf_chk_in(&ctx.scene_objects);
        
        copy_model_data_recursively_(ctx,new_dest_id,child_so_id);
    }
}

