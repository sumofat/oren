package graphics
import "core:math"
import platform "../platform"
import con "../containers"
import la "core:math/linalg"
import "core:mem"
import windows "core:sys/windows"
import window32 "core:sys/win32"
import "core:fmt"

pers_proj_pass : RenderPass(RenderProjectionPass);
gbuffer_pass : RenderPass(GbufferPass);
light_accum_pass1 : RenderPass(LightingAccumPass1);
light_accum_pass2 : RenderPass(LightingAccumPass2);
composite_pass : RenderPass(CompositePass);

mapped_matrix_data : rawptr;
matrix_quad_buffer := con.buf_init(200,f4x4);
has_update : bool = false;

/*
init_perspective_projection_pass :: proc()
{
    pers_proj_pass.data.root_sig = default_root_sig;
}

setup_perspective_projection_pass :: proc(list : ^RenderCommandList, matrix_buffer : ^con.Buffer(f4x4),matrix_quad_buffer : ^con.Buffer(f4x4))
{
    using platform;
    pers_proj_pass.data.matrix_buffer = matrix_buffer;
    pers_proj_pass.data.matrix_quad_buffer = matrix_quad_buffer;
    pers_proj_pass.list = list;

    current_backbuffer_index := GetCurrentBackBufferIndex(swap_chain);    
    rtv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,rtv_descriptor_heap,current_backbuffer_index);
    color := f4{0,1,0,1};

    back_buffer_resource_id := get_current_back_buffer_resource_view_id();
    fmt.println("backbufferresourceid setup  projection ",back_buffer_resource_id);    
    add_clear_command(color,rtv_cpu_handle,back_buffer_resource_id);
    
    dsv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = GetCPUDescriptorHandleForHeapStart(depth_heap.value);
    
    add_clear_depth_stencil_command(1.0,0,&dsv_cpu_handle,depth_buffer);
}

execute_perspective_projection_pass :: proc(pass : RenderPass(RenderProjectionPass))
{
    using con;
    using la;
    using platform;
    
    if buf_len(pass.list.command_buffer) > 0
    {
	    renderer_set_write_list(pass.list);
	    list := pass.list;
	    matrix_buffer := pass.data.matrix_buffer;
	    matrix_quad_buffer := pass.data.matrix_quad_buffer;
	    
	    add_start_command_list_command();
	    for command in list.command_buffer.buffer
	    {
            m_mat := buf_get(matrix_buffer,command.model_matrix_id);
            c_mat := buf_get(matrix_buffer,command.camera_matrix_id);
            proj_mat := buf_get(matrix_buffer,command.perspective_matrix_id);
            world_mat := mul(c_mat,m_mat);
            finalmat := mul(proj_mat,world_mat);
            m_mat[0].x = cast(f32)buf_len(matrix_quad_buffer^) * size_of(f4x4);
            m_mat[0].y = 5.0;

            base_color := command.geometry.base_color;
	        m_mat[1] = [4]f32{base_color.x,base_color.y,base_color.z,base_color.w};
	        
            buf_push(matrix_quad_buffer,finalmat);        

	        add_root_signature_command(default_root_sig);		    

	        rect := f4{0,0,ps.window.dim.x,ps.window.dim.y};	    

	        add_viewport_command(rect);

	        add_scissor_command(rect);
	        
	        material := asset_ctx.asset_tables.materials[command.material_name];
	        add_pipeline_state_command(material.pipeline_state);

	        add_graphics_root32_bit_constant(0,16,&m_mat,0);
	        add_graphics_root32_bit_constant(2,16,&finalmat,0);

	        tex_index := command.texture_id;	    
	        add_graphics_root32_bit_constant(4,4,&tex_index,0);

	        gpu_handle_default_srv_desc_heap := GetGPUDescriptorHandleForHeapStart(default_srv_desc_heap.heap.value);
	        add_graphics_root_desc_table(1,default_srv_desc_heap.heap.value,gpu_handle_default_srv_desc_heap);

	        slot : int = 0;
	        for j := command.geometry.buffer_id_range.x;j <= command.geometry.buffer_id_range.y;j+=1 
	        {
		        bv := buf_get(&asset_ctx.asset_tables.vertex_buffers,cast(u64)j);
		        add_set_vertex_buffer_command(cast(u32)slot,bv);
		        slot += 1;
	        }

	        if command.is_indexed
            {
		        ibv := buf_get(&asset_ctx.asset_tables.index_buffers,command.geometry.index_id);
		        add_draw_indexed_command(cast(u32)command.geometry.index_count,cast(u32)command.geometry.offset,platform.D3D12_PRIMITIVE_TOPOLOGY.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST,ibv);
            }
	        else
            {		/**/
		        add_draw_command(cast(u32)command.geometry.offset,cast(u32)command.geometry.count,platform.D3D12_PRIMITIVE_TOPOLOGY.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);                        
            }
            has_update = true;		    
	    }
	    add_end_command_list_command();		
    }
}
*/

init_gbuffer_pass :: proc()
{
    using platform;
    gbuffer_pass.data.root_sig = default_root_sig;
    gbuffer_pass.data.render_targets = con.buf_init(1,D3D12_CPU_DESCRIPTOR_HANDLE);

    desc : D3D12_DESCRIPTOR_HEAP_DESC;
    desc.NumDescriptors = 3;
    desc.Type = .D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    
    render_texture_heap = create_descriptor_heap(device.device, desc); 
    
    diffuse_render_texture_heap_index,diffuse_srv_heap_index := create_render_texture(&asset_ctx,ps.window.dim,render_texture_heap);
    diffuse_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,cast(u32)diffuse_render_texture_heap_index);
    con.buf_push(&gbuffer_pass.data.render_targets,diffuse_cpu_handle);
    
    normal_render_texture_heap_index,normal_srv_heap_index := create_render_texture(&asset_ctx,ps.window.dim,render_texture_heap); 
    normal_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,cast(u32)normal_render_texture_heap_index);
    con.buf_push(&gbuffer_pass.data.render_targets,normal_cpu_handle);
    
    position_render_texture_heap_index,position_srv_heap_index := create_render_texture(&asset_ctx,ps.window.dim,render_texture_heap,.DXGI_FORMAT_R32G32B32A32_FLOAT); 
    position_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,cast(u32)position_render_texture_heap_index);
    con.buf_push(&gbuffer_pass.data.render_targets,position_cpu_handle);

    //TODO(Ray):Cross data sharing of passes //NOTE(Ray):Not for sure if this is good 
    composite_pass.data.render_target_start_id = cast(u64)diffuse_srv_heap_index;    
}

setup_gbuffer_pass :: proc(list : ^RenderCommandList, matrix_buffer : ^con.Buffer(f4x4),matrix_quad_buffer : ^con.Buffer(f4x4))
{
    gbuffer_pass.data.matrix_buffer = matrix_buffer;
    gbuffer_pass.data.matrix_quad_buffer = matrix_quad_buffer;
    gbuffer_pass.list = list;

    using platform;
    using con;
    rtv_cpu_handle1 : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,0);
    rtv_cpu_handle2 : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,1);    

    color := f4{0,1,0,1};
    //NOTE(Ray):These magic numbers will not be correct in th e casea of triple buffering
    //as the resourceviews before it will be more than expected (double buffered swap buffers)
//    rt_resource_view1 := buf_ptr(&resourceviews,2);
//    rt_resource_view2 := buf_ptr(&resourceviews,3);    
    add_clear_command(color,rtv_cpu_handle1,3);//rt_resource_view1);
    add_clear_command(color,rtv_cpu_handle2,4);//rt_resource_view2);    
    
    dsv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = GetCPUDescriptorHandleForHeapStart(depth_heap.value);
    add_clear_depth_stencil_command(true,1.0,true,1,&dsv_cpu_handle,depth_buffer);    
}

execute_gbuffer_pass :: proc(pass : RenderPass(GbufferPass))
{

    using con;
    using la;
    using platform;

//    buf_push(&render_command_lists,pass.list);
    
    if buf_len(pass.list.command_buffer) > 0
    {
	    renderer_set_write_list(pass.list);
	    list := pass.list;
	    matrix_buffer := pass.data.matrix_buffer;
	    matrix_quad_buffer := pass.data.matrix_quad_buffer;
	    pass_local := pass;
	    rt_mem := mem.raw_dynamic_array_data(pass.data.render_targets.buffer);
	    add_start_command_list_with_render_targets(3,rt_mem);
	    
	    for command in list.command_buffer.buffer
	    {
            m_mat := buf_get(matrix_buffer,command.model_matrix_id);

//            model_matrix := transpose(m_mat);
            
            c_mat := buf_get(matrix_buffer,command.camera_matrix_id);
            proj_mat := buf_get(matrix_buffer,command.perspective_matrix_id);
            world_mat := mul(c_mat,m_mat);

            finalmat := mul(proj_mat,world_mat);
            m_mat[0].x = cast(f32)buf_len(matrix_quad_buffer^) * size_of(f4x4);

            base_color := command.geometry.base_color;
	        m_mat[1] = [4]f32{base_color.x,base_color.y,base_color.z,base_color.w};

            buf_push(matrix_quad_buffer,finalmat);        

            m_mat[0].y = cast(f32)buf_len(matrix_quad_buffer^) * size_of(f4x4);

            buf_push(matrix_quad_buffer,world_mat);
            
	        add_root_signature_command(default_root_sig);		    

	        rect := f4{0,0,ps.window.dim.x,ps.window.dim.y};	    

	        add_viewport_command(rect);

	        add_scissor_command(rect);
	        
	        material := asset_ctx.asset_tables.materials["gbuffer"];

	        add_pipeline_state_command(material.pipeline_state);

	        add_graphics_root32_bit_constant(0,16,&m_mat,0);
	        add_graphics_root32_bit_constant(2,16,&finalmat,0);

	        tex_index := command.texture_id;	    
	        add_graphics_root32_bit_constant(4,4,&tex_index,0);

	        gpu_handle_default_srv_desc_heap := GetGPUDescriptorHandleForHeapStart(default_srv_desc_heap.heap.value);
	        add_graphics_root_desc_table(1,default_srv_desc_heap.heap.value,gpu_handle_default_srv_desc_heap);

	        slot : int = 0;
	        for j := command.geometry.buffer_id_range.x;j <= command.geometry.buffer_id_range.y;j+=1 
	        {
		        bv := buf_get(&asset_ctx.asset_tables.vertex_buffers,cast(u64)j);
		        add_set_vertex_buffer_command(cast(u32)slot,bv);
		        slot += 1;
	        }

	        if command.is_indexed
            {
		        ibv := buf_get(&asset_ctx.asset_tables.index_buffers,command.geometry.index_id);
		        add_draw_indexed_command(cast(u32)command.geometry.index_count,cast(u32)command.geometry.offset,platform.D3D12_PRIMITIVE_TOPOLOGY.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST,ibv);
            }
	        else
            {		/**/
		        add_draw_command(cast(u32)command.geometry.offset,cast(u32)command.geometry.count,platform.D3D12_PRIMITIVE_TOPOLOGY.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);                        
            }
            has_update = true;		    
	    }
	    add_end_command_list_command();		
    }

//    if(has_update)
    {
//	    mem.copy(mapped_matrix_data,mem.raw_dynamic_array_data(matrix_quad_buffer.buffer),cast(int)buf_len(matrix_quad_buffer) * size_of(f4x4));		
//	    buf_clear(&matrix_quad_buffer);
    }
}

init_composite_pass :: proc(ctx : ^AssetContext)
{
    pers_proj_pass.data.root_sig = default_root_sig;
    //create a screen rect
    quad_pos : [18]f32 =
    {
        -1.0, -1.0, 0.0,
        1.0,  -1.0, 0.0,
        1.0,   1.0, 0.0,
        -1.0, -1.0, 0.0,
        1.0,   1.0, 0.0,
        -1.0,  1.0, 0.0,
    };
    
    quad_st : [12]f32 = {
        0.0, 1.0,
        1.0, 1.0,
        1.0, 0.0,
        0.0, 1.0,
        1.0, 0.0,
        0.0, 0.0,
    };

    //create vertex and uv buffer
    mesh_r : GPUMeshResource;
    quad_pos_size := cast(u64)size_of(quad_pos);
    quad_pos_ptr := &quad_pos[0];
    composite_pass.data.vertex_buffer_id = set_buffer(ctx,&mesh_r.vertex_buff,size_of(f32) * 3,quad_pos_size,quad_pos_ptr);
    composite_pass.data.uv_buffer_id     = set_buffer(ctx,&mesh_r.uv_buff,size_of(f32) * 2,size_of(quad_st),&quad_st[0]);
}

setup_composite_pass :: proc()
{
    using platform;
//clear the backbuffer
    current_backbuffer_index := GetCurrentBackBufferIndex(swap_chain);    
    rtv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,rtv_descriptor_heap,current_backbuffer_index);

//    back_buffer_resource : rawptr;
//    r : windows.HRESULT = GetBuffer(swap_chain,cast(u32)current_backbuffer_index, &back_buffer_resource);
    color := f4{0,1,0,1};

    back_buffer_resource_id := get_current_back_buffer_resource_view_id();    
    add_clear_command(color,rtv_cpu_handle,back_buffer_resource_id);
 
    dsv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = GetCPUDescriptorHandleForHeapStart(depth_heap.value);

    add_clear_depth_stencil_command(true,1.0,true,1,&dsv_cpu_handle,depth_buffer);
}

execute_composite_pass :: proc(pass : RenderPass(CompositePass))
{
    using con;
    using la;
    using platform;

	add_start_command_list_command();
	{
        m_mat := f4x4_identity;
        finalmat := f4x4_identity;
	    add_root_signature_command(default_root_sig);		    

	    rect := f4{0,0,ps.window.dim.x,ps.window.dim.y};	    

	    add_viewport_command(rect);
	    add_scissor_command(rect);
	    
	    material := asset_ctx.asset_tables.materials["composite"];
	    add_pipeline_state_command(material.pipeline_state);

	    add_graphics_root32_bit_constant(0,16,&m_mat,0);
	    add_graphics_root32_bit_constant(2,16,&finalmat,0);

	    tex_index := pass.data.render_target_start_id;
        add_graphics_root32_bit_constant(4,4,&tex_index,0);
        
        //set textures as our render targets
	    gpu_handle_heap := GetGPUDescriptorHandleForHeapStart(default_srv_desc_heap.heap.value);
	    add_graphics_root_desc_table(1,default_srv_desc_heap.heap.value,gpu_handle_heap);

        bv := buf_get(&asset_ctx.asset_tables.vertex_buffers,cast(u64)pass.data.vertex_buffer_id);                
        add_set_vertex_buffer_command(0,bv);

        uvbv := buf_get(&asset_ctx.asset_tables.vertex_buffers,cast(u64)pass.data.uv_buffer_id);                
        add_set_vertex_buffer_command(1,uvbv);                
        //		add_draw_command(cast(u32)command.geometry.offset,cast(u32)command.geometry.count,platform.D3D12_PRIMITIVE_TOPOLOGY.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);

		add_draw_command(0,6,platform.D3D12_PRIMITIVE_TOPOLOGY.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);                                
	}

    if(has_update)
    {
	    mem.copy(mapped_matrix_data,mem.raw_dynamic_array_data(matrix_quad_buffer.buffer),cast(int)buf_len(matrix_quad_buffer) * size_of(f4x4));		
	    buf_clear(&matrix_quad_buffer);
    }
    
	add_end_command_list_command();		
}

init_lighting_pass1 :: proc()
{
    using platform;
    light_accum_pass1.data.root_sig = default_root_sig;
//no pixel shader
}

setup_lighting_pass1 :: proc(list : ^RenderCommandList, matrix_buffer : ^con.Buffer(f4x4),matrix_quad_buffer : ^con.Buffer(f4x4))
{
    light_accum_pass1.data.matrix_buffer = matrix_buffer;
    light_accum_pass1.data.matrix_quad_buffer = matrix_quad_buffer;
    light_accum_pass1.list = list;

    dsv_cpu_handle : platform.D3D12_CPU_DESCRIPTOR_HANDLE = platform.GetCPUDescriptorHandleForHeapStart(depth_heap.value);
    add_clear_depth_stencil_command(false,1.0,true,1,&dsv_cpu_handle,depth_buffer);        
}

//NOTE(Ray):this pass has no color output no pixel shader on teh OM stage.
execute_lighting_pass1 :: proc(pass : RenderPass(LightingAccumPass1))
{
    using con;
    using la;
    using platform;
    
    if buf_len(pass.list.command_buffer) > 0
    {
	    renderer_set_write_list(pass.list);
	    list := pass.list;
	    matrix_buffer := pass.data.matrix_buffer;
	    matrix_quad_buffer := pass.data.matrix_quad_buffer;
	    pass_local := pass;
	    add_start_command_list_basic(true);

        //for light in light buffer
	    for command in list.command_buffer.buffer
	    {
            m_mat := buf_get(matrix_buffer,command.model_matrix_id);

//            model_matrix := transpose(m_mat);
            
            c_mat := buf_get(matrix_buffer,command.camera_matrix_id);
            proj_mat := buf_get(matrix_buffer,command.perspective_matrix_id);
            world_mat := mul(c_mat,m_mat);

            finalmat := mul(proj_mat,world_mat);
            m_mat[0].x = cast(f32)buf_len(matrix_quad_buffer^) * size_of(f4x4);

            base_color := command.geometry.base_color;
	        m_mat[1] = [4]f32{base_color.x,base_color.y,base_color.z,base_color.w};

            buf_push(matrix_quad_buffer,finalmat);        

            m_mat[0].y = cast(f32)buf_len(matrix_quad_buffer^) * size_of(f4x4);

            buf_push(matrix_quad_buffer,world_mat);
            
	        add_root_signature_command(default_root_sig);		    

	        rect := f4{0,0,ps.window.dim.x,ps.window.dim.y};	    

	        add_viewport_command(rect);

	        add_scissor_command(rect);
	        
	        material := asset_ctx.asset_tables.materials["light_accum_pass1"];

	        add_pipeline_state_command(material.pipeline_state);

	        add_graphics_root32_bit_constant(0,16,&m_mat,0);
	        add_graphics_root32_bit_constant(2,16,&finalmat,0);

	        tex_index := command.texture_id;	    
	        add_graphics_root32_bit_constant(4,4,&tex_index,0);

	        gpu_handle_default_srv_desc_heap := GetGPUDescriptorHandleForHeapStart(default_srv_desc_heap.heap.value);
	        add_graphics_root_desc_table(1,default_srv_desc_heap.heap.value,gpu_handle_default_srv_desc_heap);

	        slot : int = 0;
	        for j := command.geometry.buffer_id_range.x;j <= command.geometry.buffer_id_range.y;j+=1 
	        {
		        bv := buf_get(&asset_ctx.asset_tables.vertex_buffers,cast(u64)j);
		        add_set_vertex_buffer_command(cast(u32)slot,bv);
		        slot += 1;
	        }

	        if command.is_indexed
            {
		        ibv := buf_get(&asset_ctx.asset_tables.index_buffers,command.geometry.index_id);
		        add_draw_indexed_command(cast(u32)command.geometry.index_count,cast(u32)command.geometry.offset,platform.D3D12_PRIMITIVE_TOPOLOGY.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST,ibv);
            }
	        else
            {		/**/
		        add_draw_command(cast(u32)command.geometry.offset,cast(u32)command.geometry.count,platform.D3D12_PRIMITIVE_TOPOLOGY.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);                        
            }
            has_update = true;		    
	    }
	    add_end_command_list_command();		
    }
}
