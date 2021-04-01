package graphics
import platform "../platform"
import con "../containers"

render_commands : con.Buffer(D12RenderCommand);
render_commands_ptr : ^RenderCommandList;

RenderCommand :: struct
{
    geometry : RenderGeometry,
    material_id : u64,
    model_matrix_id : u64,
    camera_matrix_id : u64,
    perspective_matrix_id : u64,
    
    //TODO(Ray):Create a mapping between pipeline state root sig slots..
    //and inputs from the application ie textures buffers etc..
    //for now we just throw on the simple ones we are using now. 
    texture_id : u64,
    is_indexed : bool,
    material_name : string,
};

RenderCommandList :: struct
{
    command_buffer : con.Buffer(RenderCommand),
};

RenderProjectionPass  :: struct
{
    matrix_buffer : ^con.Buffer(f4x4),
    matrix_quad_buffer : ^con.Buffer(f4x4),
    root_sig : rawptr,
}

RenderPass :: struct(type : typeid)
{
    list : ^RenderCommandList,
    data : type,
}

RenderPassProcs :: struct(type : typeid)
{
    setup_pass : proc(pass : RenderPass(type)),
    execute_pass : proc(pass : RenderPass(type)),
};

//Commands
D12CommandBasicDraw :: struct
{
    vertex_offset : u32,
    count : u32,
    topology : platform.D3D12_PRIMITIVE_TOPOLOGY,
    heap_count : u32,
    //ID3D12DescriptorHeap* heaps;
    buffer_view : platform.D3D12_VERTEX_BUFFER_VIEW,// TODO(Ray Garner): add a way to bind multiples
    // TODO(Ray Garner): add a way to bind multiples
};

D12CommandIndexedDraw :: struct
{
    index_count : u32,
    index_offset : u32,
    topology : platform.D3D12_PRIMITIVE_TOPOLOGY,
    heap_count : u32,
//    D3D12_VERTEX_BUFFER_VIEW uv_view,
//    D3D12_VERTEX_BUFFER_VIEW buffer_view,// TODO(Ray Garner): add a way to bind multiples
    
    index_buffer_view :     platform.D3D12_INDEX_BUFFER_VIEW,
    // TODO(Ray Garner): add a way to bind multiples
};



D12CommandSetVertexBuffer :: struct
{
    slot : u32,
    buffer_view : platform.D3D12_VERTEX_BUFFER_VIEW,
};

D12CommandViewport :: struct
{
    viewport : f4,
};

D12CommandRootSignature :: struct
{
    root_sig :  rawptr /*ID3D12RootSignature**/ ,
};

D12RenderCommand :: union
{
    D12CommandBasicDraw,
    D12CommandIndexedDraw,
    D12CommandSetVertexBuffer,
    D12CommandViewport,
    D12CommandRootSignature,
    D12CommandPipelineState,
    D12CommandScissorRect,
    D12CommandGraphicsRootDescTable,
    D12CommandGraphicsRoot32BitConstant,
    D12CommandStartCommandList,
    D12CommandEndCommmandList,
    D12RenderTargets,    
}

D12CommandPipelineState :: struct
{
    pipeline_state : rawptr /*ID3D12PipelineState* */,
};

D12CommandScissorRect :: struct
{
    rect : platform.D3D12_RECT,
    //f4 rect,
};

D12CommandGraphicsRootDescTable :: struct
{
    index : u64,
    heap : rawptr /*(ID3D12DescriptorHeap* )*/,
    gpu_handle : platform.D3D12_GPU_DESCRIPTOR_HANDLE,
}

D12CommandGraphicsRoot32BitConstant :: struct
{
    index : u32,
    num_values : u32,
    gpuptr : rawptr,
    offset : u32,
}

D12CommandStartCommandList :: struct
{
    dummy : bool,
    handles : ^platform.D3D12_CPU_DESCRIPTOR_HANDLE,
};

D12CommandEndCommmandList :: struct
{
    dummy : bool,
};

D12RenderTargets :: struct
{
    is_desc_range : bool,
    count : u32,
    descriptors : ^platform.D3D12_CPU_DESCRIPTOR_HANDLE,
    depth_stencil_handle : ^platform.D3D12_CPU_DESCRIPTOR_HANDLE,
}

renderer_init :: proc() -> RenderCommandList
{
    result : RenderCommandList;
    result.command_buffer = con.buf_init(100,RenderCommand);
    return result;
}

renderer_set_write_list :: proc(current_list : ^RenderCommandList)
{
    render_commands_ptr = current_list^;
}

process_children_recrusively :: proc(render : ^RenderCommandList,so : ^SceneObject,c_mat : u64,p_mat : u64,ctx : ^AssetContext)
{
    using con;
    for i := 0;i < cast(int)buf_len(so.children.buffer);i+=1
    {
        child_so_id := buf_get(&so.children.buffer,cast(u64)i);
        child_so := buf_chk_out(&ctx.scene_objects,child_so_id);
        transform_update(&child_so.transform);

        if child_so.type != 0//non mesh type
        {
            final_mat := buf_chk_out(&ctx.asset_tables.matrix_buffer,child_so.m_id);
            final_mat^ = child_so.transform.m;
            buf_chk_in(&ctx.asset_tables.matrix_buffer);
            
            for m := child_so.primitives_range.x;m <= child_so.primitives_range.y;m+=1
            {
                mesh_id := cast(u64)m;            
                m_ := buf_chk_out(&ctx.asset_tables.meshes,mesh_id);
                if m_ != nil
                {
                    mesh := m_^;
                    //get mesh issue render command
                    com := RenderCommand{};        
                    geo := RenderGeometry{};
                    //TODO(Ray):No point in this if else statement change it.
                    if mesh.index32_count > 0
                    {
                        com.is_indexed = true;
                        geo.buffer_id_range = mesh.mesh_resource.buffer_range;
                        geo.index_id = cast(u64)mesh.mesh_resource.index_id;
                        geo.index_count = mesh.index32_count;                
                    }
                    else if mesh.index16_count > 0
                    {
                        com.is_indexed = true;
                        geo.buffer_id_range = mesh.mesh_resource.buffer_range;
                        geo.index_id = cast(u64)mesh.mesh_resource.index_id;
                        geo.index_count = mesh.index16_count;                
                    }
                    else
                    {
                        com.is_indexed = false;
                        geo.buffer_id_range = mesh.mesh_resource.buffer_range;
                        geo.index_id = cast(u64)mesh.mesh_resource.index_id;
                        geo.count = mesh.vertex_count;
                    }
            
                    geo.offset = 0;
                    geo.base_color = mesh.base_color;
                    com.geometry = geo;

                    com.material_id = cast(u64)mesh.material_id;
		    com.material_name = mesh.material_name;
                    com.texture_id = mesh.metallic_roughness_texture_id;
                    com.model_matrix_id = child_so.m_id;
                    com.camera_matrix_id = c_mat;
                    com.perspective_matrix_id = p_mat;
                    buf_push(&render.command_buffer,com);
                    buf_chk_in(&ctx.asset_tables.meshes);                    
                }                
            }
        }

        process_children_recrusively(render,child_so,c_mat,p_mat,ctx);
        buf_chk_in(&ctx.scene_objects);
    }
}

issue_render_commands :: proc(render : ^RenderCommandList,s : ^Scene,ctx : ^AssetContext,c_mat : u64,p_mat : u64)
{
    using con;
    //Start at root node
    for i := 0;i < cast(int)buf_len(s.buffer.buffer);i +=1 
    {
        so_id := buf_get(&s.buffer.buffer,cast(u64)i);        
        so := buf_chk_out(&ctx.scene_objects,so_id);
//        FMJSceneObject* so = fmj_stretch_buffer_check_out(FMJSceneObject,&s.buffer.buffer,i);
//        if(so.type == scene_object_type_mesh)

        if buf_len(so.children.buffer) > 0
        {
            process_children_recrusively(render,so,c_mat,p_mat,ctx);
        }
        buf_chk_in(&ctx.scene_objects);
    }
}
