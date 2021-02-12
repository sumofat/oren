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
    }
    /*    

}

        //TODO(ray):If we didnt  get a mesh release any memory allocated.
        if(data->nodes_count > 0)
        {
            //result.model = fmj_asset_model_create(ctx);
            FMJ3DTrans parent_trans = {};
            fmj_3dtrans_init(&parent_trans);

            u64 p_matrix_id = fmj_stretch_buffer_push(&ctx->asset_tables->matrix_buffer,&parent_trans.m);
            void* p_mptr = (void*)p_matrix_id;

            FMJSceneObject model_root_so_ = {};
            fmj_scene_object_buffer_init(&model_root_so_.children);
            u64 model_root_so_id = fmj_stretch_buffer_push(&ctx->scene_objects,&model_root_so_);
            FMJSceneObject* model_root = fmj_stretch_buffer_check_out(FMJSceneObject,&ctx->scene_objects,model_root_so_id);

            ASSERT(data->scenes_count == 1);
            for(int i = 0;i < data->scenes[0].nodes_count;++i)
            {
                cgltf_node* root_node = data->scenes[0].nodes[i];
            
                FMJ3DTrans trans = {};
                fmj_3dtrans_init(&trans);

                f4x4 out_mat = f4x4_identity();
                if(root_node->has_matrix)
                {
                    out_mat = f4x4_create(root_node->matrix[0],root_node->matrix[1],root_node->matrix[2],root_node->matrix[3],
                                          root_node->matrix[4],root_node->matrix[5],root_node->matrix[6],root_node->matrix[7],
                                          root_node->matrix[8],root_node->matrix[9],root_node->matrix[10],root_node->matrix[11],
                                          root_node->matrix[12],root_node->matrix[13],root_node->matrix[14],root_node->matrix[15]);                                        
                }
                else
                {
                    cgltf_node_transform_world(root_node, (cgltf_float*)&out_mat);
                }

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

