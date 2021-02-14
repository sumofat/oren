package graphics

import "core:fmt"
import "core:c"
import "core:mem"

import la "core:math/linalg"

import platform "../platform"
import "../external/cgltf"

AssetVertCompressionType :: enum
{
    fmj_asset_vert_compression_none
};

AssetIndexComponentSize :: enum
{
    fmj_asset_index_component_size_none,
    fmj_asset_index_component_size_32,
    fmj_asset_index_component_size_16
};

Mesh :: struct
{
    id : u32,
    name : string,
    compression_type : AssetVertCompressionType,
    
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
    
    index_component_size : AssetIndexComponentSize,
    //TODO(Ray):These are seriously problematic and ugly will be re working these.
    index_32_data : ^u32,
    index_32_data_size : u64,
    index32_count : u64,
    index_16_data : ^u16,
    index_16_data_size : u64,
    index16_count : u64,
    mesh_resource : GPUMeshResource,    
    material_id : u32,
    metallic_roughness_texture_id : u64,

    base_color : f4,
};

AssetModel :: struct
{
    id : u32,
    model_name : string,
    meshes : Buffer(Mesh),
};

AssetModelLoadResult :: struct
{
    is_success : bool,
//    FMJAssetModel model;
    scene_object_id : u64,
//    FMJSceneObject scene_object;
};

RenderMaterial :: struct
{
    id : u64,
    pipeline_state : rawptr,//finalized depth stencil state etc... 
    scissor_rect : f4,
    viewport_rect : f4,
    metallic_roughness_texture_id : u64,
    base_color : f4
};

asset_load_model :: proc(ctx : ^AssetContext,file_path : cstring,material_id : u32) -> AssetModelLoadResult
{
    
    result : AssetModelLoadResult;
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
            //result.model = fmj_asset_model_create(ctx);

            parent_trans := transform_init();

            p_matrix_id := buf_push(&ctx.asset_tables.matrix_buffer,parent_trans.m);
//            p_mptr : rawptr = (rawptr)p_matrix_id;

            model_root_so_ : SceneObject = scene_object_init("model_root_so");
            model_root_so_id := buf_push(&ctx.scene_objects,model_root_so_);
            model_root := buf_chk_out(&ctx.scene_objects,model_root_so_id,SceneObject);
            assert(cgltf_data.scenes_count == 1);
	    scenes_count := mem.ptr_offset(cgltf_data.scenes,0).nodes_count;	    
            for i := 0;i < cast(int)scenes_count;i+=1
            {
		root_scene := mem.ptr_offset(cgltf_data.scenes,0);
                root_node : ^cgltf.node = mem.ptr_offset(root_scene.nodes,i)^;
		
                trans := transform_init();
                out_mat := la.MATRIX4_IDENTITY;
                if(root_node.has_matrix)
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

                mesh_id : i32 = -1;
                type : u32 = 0;
                mesh_range := f2{};
                if root_node.mesh != nil
                {
                    //result.model.model_name = fmj_string_create((char*)file_path,ctx->perm_mem);                
                    mesh_range = create_mesh_from_cgltf_mesh(ctx,root_node.mesh,cast(u64)material_id);
//                    type = 1;
//                    asset_upload_meshes(ctx,mesh_range);
                }
		
            }	    
	}
    }


    
    /*    

                trans.p = f3_create(out_mat.c3.x,out_mat.c3.y,out_mat.c3.z);
                trans.s = f3_create(f3_length(f3_create(out_mat.c0.x,out_mat.c0.y,out_mat.c0.z)),
                                    f3_length(f3_create(out_mat.c1.x,out_mat.c1.y,out_mat.c1.z)),
                                    f3_length(f3_create(out_mat.c2.x,out_mat.c2.y,out_mat.c2.z)));
                trans.r = quaternion_create_f4x4(out_mat);
                trans.m = out_mat;

                s32 mesh_id = -1;
                u32 type = 0;
                f2 mesh_range = f2_create_f(0);                
                if(root_node->mesh)
                {
                    //result.model.model_name = fmj_string_create((char*)file_path,ctx->perm_mem);                
                    mesh_range = fmj_asset_create_mesh_from_cgltf_mesh(ctx,root_node->mesh,material_id);
                    type = 1;
                    fmj_asset_upload_meshes(ctx,mesh_range);
                }

                void* mptr = (void*)mesh_id;
                FMJString mesh_name = fmj_string_create_formatted("mesh %s",ctx->temp_mem,ctx->perm_mem,root_node->name);                
                u64 child_id = AddChildToSceneObject(ctx,model_root,&trans,&mptr,mesh_name);
                FMJSceneObject* child_so = fmj_stretch_buffer_check_out(FMJSceneObject,&ctx->scene_objects,child_id);
                child_so->type = type;
                child_so->primitives_range = mesh_range;
                fmj_asset_load_meshes_recursively_gltf_node_(&result,root_node,ctx,file_path,material_id,child_so);
                fmj_stretch_buffer_check_in(&ctx->scene_objects);
                
            }
            fmj_stretch_buffer_check_in(&ctx->scene_objects);
            result.scene_object_id = model_root_so_id;
        }
        
        if(!is_success)
        {
//            ASSERT(false);
        }
//        cgltf_free(data);
    }
*/
    return result;        
}



create_mesh_from_cgltf_mesh  :: proc(ctx : ^AssetContext,ma : ^cgltf.mesh,material_id : u64) -> f2
{
    assert(ma != nil);

    //TODO(Ray):This doesnt work anymore needs a different method
    mesh_id := len(ctx.asset_tables.meshes.buffer);
    
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
	

        if mat.has_pbr_metallic_roughness
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
//			tex :=  get_loaded_image_from_mem(tex_data,data_size,4);                
//                        u64 id = fmj_asset_texture_add(ctx,tex);                
//                        mesh.metallic_roughness_texture_id = id;                    
                    }                    
                }
            }
    /*                    
            if(mat.pbr_metallic_roughness.metallic_roughness_texture.texture)
            {
                cgltf_texture_view tv = mat.pbr_metallic_roughness.metallic_roughness_texture;
            }

            cgltf_float* bcf = mat.pbr_metallic_roughness.base_color_factor;
            mesh.base_color = f4_create(bcf[0],bcf[1],bcf[2],bcf[3]);
            
//            cgltf_float* mf = &mat.pbr_metallic_roughness.metallic_factor;
//            cgltf_float* rf = &mat.pbr_metallic_roughness.roughness_factor;
        }
            
        if(mat.has_pbr_specular_glossiness)
        {
            if(mat.pbr_specular_glossiness.diffuse_texture.texture)
            {
                cgltf_texture_view tv = mat.pbr_specular_glossiness.diffuse_texture;
            }

            if(mat.pbr_specular_glossiness.specular_glossiness_texture.texture)
            {
                cgltf_texture_view tv = mat.pbr_specular_glossiness.specular_glossiness_texture;
            }

            cgltf_float* dcf = mat.pbr_specular_glossiness.diffuse_factor;
            f4 diffuse_value = f4_create(dcf[0],dcf[1],dcf[2],dcf[3]);
            cgltf_float* sf = mat.pbr_specular_glossiness.specular_factor;
            f3 specular_value = f3_create(sf[0],sf[1],sf[2]);
            cgltf_float* gf = &mat.pbr_specular_glossiness.glossiness_factor;
        }
            
        //alphaCutoff
        //alphaMode
        //emissiveFactor
        //emissiveTexture
        //occlusionTexture
        //normalTexture

        mesh.name = fmj_string_create(ma.name,ctx.perm_mem);
        mesh.material_id = 0;

        if(prim.type == cgltf_primitive_type_triangles)
        {
            bool has_got_first_uv_set = false;

            if(prim.indices)
            {
                u64 istart_offset = prim.indices.offset + prim.indices.buffer_view.offset;
                cgltf_buffer* ibuf = prim.indices.buffer_view.buffer;                
                if(prim.indices.component_type == cgltf_component_type_r_16u)
                {
                    u64 indices_size =  (u64)prim.indices.count * sizeof(u16);
                    u16* indices_buffer = (u16*)((uint8_t*)ibuf.data + istart_offset);
                    u16* outindex_f = (u16*)malloc(indices_size);
                    
                    memcpy(outindex_f,indices_buffer,indices_size);
                    mesh.index_16_data = outindex_f;
                    mesh.index_16_data_size = sizeof(u16) * prim.indices.count;
                    mesh.index16_count = prim.indices.count;                    
                }

                else if(prim.indices.component_type == cgltf_component_type_r_32u)
                {
                    u64 indices_size =  (u64)prim.indices.count * sizeof(u32);
                    u32* indices_buffer = (u32*)((uint8_t*)ibuf.data + istart_offset);
                    u32* outindex_f = (u32*)malloc(indices_size);

                    memcpy(outindex_f,indices_buffer,indices_size);
                    mesh.index_32_data = outindex_f;
                    mesh.index_32_data_size = sizeof(u32) * prim.indices.count;
                    mesh.index32_count = prim.indices.count;                    
                }
            }
            
            for(int k = 0;k < prim.attributes_count;++k)
            {
                cgltf_attribute ac = prim.attributes[k];

                cgltf_accessor* acdata = ac.data;
                u64 count = acdata.count;
                cgltf_buffer_view* bf = acdata.buffer_view;
                {
                    u64 start_offset = bf.offset;
                    u32 stride = (u32)bf.stride;
                    cgltf_buffer* buf = bf.buffer;
                    float* buffer = (float*)((uint8_t*)buf.data + start_offset);

                    if (acdata.is_sparse)
                    {
                        ASSERT(false);
                    }

                    cgltf_size num_floats = acdata.count * cgltf_num_components(acdata.type);
                    cgltf_size num_bytes = sizeof(f32) * num_floats;                
                    cgltf_float* outf = (cgltf_float*)malloc(num_bytes);
                    cgltf_size csize = cgltf_accessor_unpack_floats(acdata,outf,num_floats);

                    if(ac.type == cgltf_attribute_type_position)
                    {
                        mesh.vertex_data = outf;
                        mesh.vertex_data_size = num_bytes;
                        mesh.vertex_count = count;
                    }

                    else if(ac.type == cgltf_attribute_type_normal)
                    {
                        mesh.normal_data = outf;
                        mesh.normal_data_size = num_bytes;
                        mesh.normal_count = count;
                    }

                    else if(ac.type == cgltf_attribute_type_tangent)
                    {
                        mesh.tangent_data = outf;
                        mesh.tangent_data_size = num_bytes;
                        mesh.tangent_count = count;
                    }

//NOTE(Ray):only support two set of uv data for now.
                    else if(ac.type == cgltf_attribute_type_texcoord && !has_got_first_uv_set)
                    {
                        mesh.uv_data = outf;
                        mesh.uv_data_size = num_bytes;
                        mesh.uv_count = count;
                        has_got_first_uv_set = true;
                    }
                
                    else if(ac.type == cgltf_attribute_type_texcoord && has_got_first_uv_set)
                    {
                        mesh.uv2_data = outf;
                        mesh.uv2_data_size = num_bytes;
                        mesh.uv2_count = count;
                        has_got_first_uv_set = true;                        
                    }                    
                }
            }
*/    
        }

        mesh.material_id = cast(u32)material_id;
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

get_image_from_mem :: proc(ptr : rawptr,size : u64,loaded_texture : ^Texture ,desired_channels : int)
{
    dimx : int;
    dimy : int;
    //NOTE(Ray):Depends on your pipeline wether or not you will need this or not.
    //IOS not supported RN
//when os.IOS{
//    stbi_set_flip_vertically_on_load(true);    
    //}
    
    comp : int;
    stbi_info_from_memory((u8*)ptr,size,&dimx, &dimy, &comp);
    loaded_texture->texels = stbi_load_from_memory((u8*)ptr,size,(&dimx), (&dimy), (int*)&loaded_texture->channel_count, desired_channels);
//    loaded_texture->texels = stbi_load(file, (&dimx), (&dimy), (int*)&loaded_texture->channel_count, desired_channels);
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
    
texture_from_mem :: proc(void* ptr,u64 size,int desired_channels) -> Texture 
{
    Texture tex;
    image_from_mem(ptr,size,&tex,desired_channels);
    assert(tex.texels != nil);
    return tex;
}
