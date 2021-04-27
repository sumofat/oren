package graphics
import "core:math"
import platform "../platform"
import con "../containers"
import la "core:math/linalg"
import "core:mem"

pers_proj_pass : RenderPass(RenderProjectionPass);
gbuffer_pass : RenderPass(GbufferPass);

mapped_matrix_data : rawptr;
matrix_quad_buffer := con.buf_init(200,f4x4);

init_perspective_projection_pass :: proc()
{
    pers_proj_pass.data.root_sig = default_root_sig;
}

setup_perspective_projection_pass :: proc(list : ^RenderCommandList, matrix_buffer : ^con.Buffer(f4x4),matrix_quad_buffer : ^con.Buffer(f4x4))
{
    pers_proj_pass.data.matrix_buffer = matrix_buffer;
    pers_proj_pass.data.matrix_quad_buffer = matrix_quad_buffer;
    pers_proj_pass.list = list;
}

execute_perspective_projection_pass :: proc(pass : RenderPass(RenderProjectionPass))
{
    has_update := false;
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

	    gpu_handle_default_srv_desc_heap := GetGPUDescriptorHandleForHeapStart(default_srv_desc_heap.value);
	    add_graphics_root_desc_table(1,default_srv_desc_heap.value,gpu_handle_default_srv_desc_heap);

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

    if(has_update)
    {
	mem.copy(mapped_matrix_data,mem.raw_dynamic_array_data(matrix_quad_buffer.buffer),cast(int)buf_len(matrix_quad_buffer) * size_of(f4x4));		
	buf_clear(&matrix_quad_buffer);
    }
}


init_gbuffer_pass :: proc()
{
    using platform;
    gbuffer_pass.data.root_sig = default_root_sig;
    gbuffer_pass.data.render_targets = con.buf_init(1,platform.D3D12_CPU_DESCRIPTOR_HANDLE);
    gbuffer_pass.data.render_targets = con.buf_init(1,D3D12_CPU_DESCRIPTOR_HANDLE);

    desc : D3D12_DESCRIPTOR_HEAP_DESC;
    desc.NumDescriptors = 2;
    desc.Type = .D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
 
    render_texture_heap := create_descriptor_heap(device.device, desc); 

    diffuse_render_texture_heap_index := create_render_texture(&asset_ctx,ps.window.dim,render_texture_heap); 

    diffuse_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,cast(u32)diffuse_render_texture_heap_index);
    
    con.buf_push(&gbuffer_pass.data.render_targets,diffuse_cpu_handle);

    normal_render_texture_heap_index := create_render_texture(&asset_ctx,ps.window.dim,render_texture_heap); 

    normal_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,cast(u32)normal_render_texture_heap_index);
    
    con.buf_push(&gbuffer_pass.data.render_targets,normal_cpu_handle);
}

setup_gbuffer_pass :: proc(list : ^RenderCommandList, matrix_buffer : ^con.Buffer(f4x4),matrix_quad_buffer : ^con.Buffer(f4x4))
{
    gbuffer_pass.data.matrix_buffer = matrix_buffer;
    gbuffer_pass.data.matrix_quad_buffer = matrix_quad_buffer;
    gbuffer_pass.list = list;
}

execute_gbuffer_pass :: proc(pass : RenderPass(GbufferPass))
{
    has_update := false;
    using con;
    using la;
    using platform;
    
    if buf_len(pass.list.command_buffer) > 0
    {
	renderer_set_write_list(pass.list);
	list := pass.list;
	matrix_buffer := pass.data.matrix_buffer;
	matrix_quad_buffer := pass.data.matrix_quad_buffer;
	
	add_start_command_list_with_render_targets(2,mem.raw_dynamic_array_data(pass.data.render_targets.buffer));
	
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

	    gpu_handle_default_srv_desc_heap := GetGPUDescriptorHandleForHeapStart(default_srv_desc_heap.value);
	    add_graphics_root_desc_table(1,default_srv_desc_heap.value,gpu_handle_default_srv_desc_heap);

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

    if(has_update)
    {
	mem.copy(mapped_matrix_data,mem.raw_dynamic_array_data(matrix_quad_buffer.buffer),cast(int)buf_len(matrix_quad_buffer) * size_of(f4x4));		
	buf_clear(&matrix_quad_buffer);
    }
    
}
