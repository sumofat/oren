package graphics
import "core:math"
import platform "../platform"
import con "../containers"
import la "core:math/linalg"
import "core:mem"
import windows "core:sys/windows"
import "core:fmt"
import enginemath "../math"
import imgui "../external/odin-imgui"

render       := renderer_init(40_000,GeometryRenderCommandList,RenderCommand)
light_render := renderer_init(1_000,LightRenderCommandList,LightRenderCommand)
custom_render := renderer_init(2_000,CustomRenderCommandList,CustomRenderCommand)

pers_proj_pass : RenderPass(RenderProjectionPass,GeometryRenderCommandList)
gbuffer_pass : RenderPass(GbufferPass,GeometryRenderCommandList)
light_accum_pass1 : RenderPass(LightingAccumPass1,LightRenderCommandList)
light_accum_pass2 : RenderPass(LightingAccumPass2,LightRenderCommandList)
composite_pass : RenderPass(CompositePass,GeometryRenderCommandList)
custom_pass : RenderPass(CustomPass,CustomRenderCommandList)

mapped_matrix_data : rawptr;
matrix_quad_buffer := con.buf_init(200,enginemath.f4x4);
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
diffuse_render_texture_heap_index : u64
normal_render_texture_heap_index : u64
position_render_texture_heap_index : u64

diffuse_res_id : u64
normal_res_id : u64
position_res_id : u64

init_gbuffer_pass :: proc()
{
    using platform;
    gbuffer_pass.data.root_sig = default_root_sig;
    gbuffer_pass.data.render_targets = con.buf_init(1,D3D12_CPU_DESCRIPTOR_HANDLE);

  
    diffuse_render_texture_heap_index_,diffuse_srv_heap_index,diffuse_res_id_ := create_render_texture(&asset_ctx,ps.window.dim,render_texture_heap);
    diffuse_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,diffuse_render_texture_heap_index_);
    diffuse_render_texture_heap_index = diffuse_render_texture_heap_index_
    diffuse_res_id = diffuse_res_id_
    con.buf_push(&gbuffer_pass.data.render_targets,diffuse_cpu_handle);
    
    normal_render_texture_heap_index_,normal_srv_heap_index,normal_res_id_ := create_render_texture(&asset_ctx,ps.window.dim,render_texture_heap,.DXGI_FORMAT_R32G32B32A32_FLOAT); 
    normal_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,normal_render_texture_heap_index_);
    normal_render_texture_heap_index = normal_render_texture_heap_index_
    normal_res_id = normal_res_id_
    con.buf_push(&gbuffer_pass.data.render_targets,normal_cpu_handle);
    
    position_render_texture_heap_index_,position_srv_heap_index,position_res_id_ := create_render_texture(&asset_ctx,ps.window.dim,render_texture_heap,.DXGI_FORMAT_R32G32B32A32_FLOAT); 
    position_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,position_render_texture_heap_index_);
    position_render_texture_heap_index = position_render_texture_heap_index_
    position_res_id = position_res_id_
    con.buf_push(&gbuffer_pass.data.render_targets,position_cpu_handle);

    //TODO(Ray):Cross data sharing of passes //NOTE(Ray):Not for sure if this is good 
    light_accum_pass2.data.render_target_start_id = cast(u64)diffuse_srv_heap_index;
    composite_pass.data.render_target_start_id = cast(u64)diffuse_srv_heap_index;    
}

setup_gbuffer_pass :: proc(list : ^RenderCommandList(GeometryRenderCommandList), matrix_buffer : ^con.Buffer(enginemath.f4x4),matrix_quad_buffer : ^con.Buffer(enginemath.f4x4))
{
    gbuffer_pass.data.matrix_buffer = matrix_buffer;
    gbuffer_pass.data.matrix_quad_buffer = matrix_quad_buffer;
    gbuffer_pass.list = list;

    using platform;
    using con;
    rtv_cpu_handle1 : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,diffuse_render_texture_heap_index);
    rtv_cpu_handle2 : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,normal_render_texture_heap_index);    
    rtv_cpu_handle3 : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,position_render_texture_heap_index);
    
    color := enginemath.f4{0,1,0,1};
    //NOTE(Ray):These magic numbers will not be correct in th e casea of triple buffering
    //as the resourceviews before it will be more than expected (double buffered swap buffers)
//    rt_resource_view1 := buf_ptr(&resourceviews,2);
//    rt_resource_view2 := buf_ptr(&resourceviews,3);    
    add_clear_command(color,rtv_cpu_handle1,diffuse_res_id);//rt_resource_view1);
    add_clear_command(color,rtv_cpu_handle2,normal_res_id);//rt_resource_view2);
    add_clear_command(color,rtv_cpu_handle3,position_res_id);//rt_resource_view2);        
    
    dsv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = GetCPUDescriptorHandleForHeapStart(depth_heap.value);
    add_clear_depth_stencil_command(true,1.0,true,1,&dsv_cpu_handle,depth_buffer);    
}

execute_gbuffer_pass :: proc(pass : RenderPass(GbufferPass,GeometryRenderCommandList),cam_id : int = -1)
{
    using con;
    using la;
    using platform;
    using enginemath;    
    if buf_len(pass.list.list.command_buffer) > 0
    {
	    renderer_set_write_list(pass.list);
	    list := pass.list;
	    matrix_buffer := pass.data.matrix_buffer;
	    matrix_quad_buffer := pass.data.matrix_quad_buffer;
	    pass_local := pass;
	    rt_mem := mem.raw_dynamic_array_data(pass.data.render_targets.buffer);
	    add_start_command_list_with_render_targets(3,rt_mem);
	    
	    for command in list.list.command_buffer.buffer{
            m_mat := buf_get(matrix_buffer,command.model_matrix_id);

//            model_matrix := transpose(m_mat);
            camera_id : u64
            c_mat : f4x4
            if cam_id > -1{
                camera_id = u64(cam_id)
                cam := get_camera(camera_id)
                c_mat = buf_get(matrix_buffer,cam.matrix_id)
            }else{
                camera_id = command.camera_matrix_id
                c_mat = buf_get(matrix_buffer,command.camera_matrix_id)
            }
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
	        for j := command.geometry.buffer_id_range.x;j <= command.geometry.buffer_id_range.y;j+=1{
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

setup_composite_pass :: proc(vp : ^CameraViewport)
{
    using platform;
    using enginemath;
//clear the rendertarget
    if vp != nil{

        color := f4{0,1,0,1};
        add_clear_command(color,vp.rt_cpu_handle,vp.resource_id);
     
        dsv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = GetCPUDescriptorHandleForHeapStart(depth_heap.value);

        add_clear_depth_stencil_command(true,1.0,true,1,&dsv_cpu_handle,depth_buffer);
    }else{
        current_backbuffer_index := GetCurrentBackBufferIndex(swap_chain);    
        rtv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,rtv_descriptor_heap,u64(current_backbuffer_index));

    //    back_buffer_resource : rawptr;
    //    r : windows.HRESULT = GetBuffer(swap_chain,cast(u32)current_backbuffer_index, &back_buffer_resource);
        color := f4{0,1,0,1};

        back_buffer_resource_id := get_current_back_buffer_resource_view_id();    
        add_clear_command(color,rtv_cpu_handle,back_buffer_resource_id);
     
        dsv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = GetCPUDescriptorHandleForHeapStart(depth_heap.value);

        add_clear_depth_stencil_command(true,1.0,true,1,&dsv_cpu_handle,depth_buffer);
    }
    
}

execute_composite_pass :: proc(pass : RenderPass(CompositePass,GeometryRenderCommandList),vp : ^CameraViewport)
{
    using con;
    using la;
    using platform;
    using enginemath;
    if vp != nil{
        add_start_command_list_with_render_targets(1,&vp.rt_cpu_handle);
    }else{
        add_start_command_list_command();
    }

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

    
    
	add_end_command_list_command();		
}

init_lighting_pass1 :: proc()
{
    using platform;
    light_accum_pass1.data.root_sig = default_root_sig;
    
//no pixel shader
}

setup_lighting_pass1 :: proc(list : ^RenderCommandList(LightRenderCommandList), matrix_buffer : ^con.Buffer(enginemath.f4x4),matrix_quad_buffer : ^con.Buffer(enginemath.f4x4))
{
    light_accum_pass1.data.matrix_buffer = matrix_buffer;
    light_accum_pass1.data.matrix_quad_buffer = matrix_quad_buffer;
    light_accum_pass1.list = list;
    
    dsv_cpu_handle : platform.D3D12_CPU_DESCRIPTOR_HANDLE = platform.GetCPUDescriptorHandleForHeapStart(depth_heap.value);
    add_clear_depth_stencil_command(false,1.0,true,1,&dsv_cpu_handle,depth_buffer);        
}

//NOTE(Ray):this pass has no color output no pixel shader on teh OM stage.
execute_lighting_pass1 :: proc(pass : RenderPass(LightingAccumPass1,LightRenderCommandList))
{
    using con;
    using la;
    using platform;
    using enginemath;    
    if buf_len(pass.list.list.command_buffer) > 0
    {
	    //renderer_set_write_list(pass.list.list);
	    list := pass.list;
	    matrix_buffer := pass.data.matrix_buffer;
	    matrix_quad_buffer := pass.data.matrix_quad_buffer;
	    pass_local := pass;
	    add_start_command_list_basic(true);

        //for light in light buffer
	    for command in list.list.command_buffer.buffer{
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
	        for j := command.geometry.buffer_id_range.x;j <= command.geometry.buffer_id_range.y;j+=1{
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


init_lighting_pass2 :: proc()
{
    using platform;
    light_accum_pass2.data.root_sig = default_root_sig;

    //setup the light accumulation buffer
    light_accum_render_texture_heap_index,light_accum_srv_heap_index,res_view_id := create_render_texture(&asset_ctx,ps.window.dim,render_texture_heap,.DXGI_FORMAT_R32G32B32A32_FLOAT); 
    light_accum_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,light_accum_render_texture_heap_index);
    con.buf_push(&light_accum_pass2.data.render_targets,light_accum_cpu_handle);
}

setup_lighting_pass2 :: proc(list : ^RenderCommandList(LightRenderCommandList), matrix_buffer : ^con.Buffer(enginemath.f4x4),matrix_quad_buffer : ^con.Buffer(enginemath.f4x4))
{
    light_accum_pass2.data.matrix_buffer = matrix_buffer;
    light_accum_pass2.data.matrix_quad_buffer = matrix_quad_buffer;
    light_accum_pass2.list = list;

    using platform;
    using con;
    using enginemath;

    light_accum_rtv_cpu_handle1 := con.buf_get(&light_accum_pass2.data.render_targets,0) //D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,render_texture_heap.value,3);

    color := f4{0,0,0,1};

    add_clear_command(color,light_accum_rtv_cpu_handle1,6);//rt_resource_view1);
    
//    dsv_cpu_handle : platform.D3D12_CPU_DESCRIPTOR_HANDLE = platform.GetCPUDescriptorHandleForHeapStart(depth_heap.value);
//    add_clear_depth_stencil_command(false,1.0,true,1,&dsv_cpu_handle,depth_buffer);        
}

//NOTE(Ray):this pass has no color output no pixel shader on teh OM stage.
execute_lighting_pass2 :: proc(pass : RenderPass(LightingAccumPass2,LightRenderCommandList))
{
    using con;
    using la;
    using platform;
    using enginemath;    
    if buf_len(pass.list.list.command_buffer) > 0
    {
	    //renderer_set_write_list(pass.list);
	    list := pass.list;
	    matrix_buffer := pass.data.matrix_buffer;
	    matrix_quad_buffer := pass.data.matrix_quad_buffer;

        rt_mem := mem.raw_dynamic_array_data(pass.data.render_targets.buffer);
//	    rt_mem := mem.raw_slice_data(pass.data.render_targets.buffer[1:]);
	    add_start_command_list_with_render_targets(1,rt_mem);        
//	    add_start_command_list_basic(true);

        //for light in light buffer
	    for command in list.list.command_buffer.buffer{
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
	        
	        material := asset_ctx.asset_tables.materials["light_accum_pass2"];

	        add_pipeline_state_command(material.pipeline_state);

	        add_graphics_root32_bit_constant(0,16,&m_mat,0);

            light : ShaderLight = {};
            light.p = f4{0,0,-6,0};
            light.color = f4{1,1,1,1};
            light.size_intensity.y = 1;
            light.size_intensity.x = 1;            
	        add_graphics_root32_bit_constant(2,16,&light,0);

            //	        tex_index := command.texture_id;
	        tex_index := pass.data.render_target_start_id;            
	        add_graphics_root32_bit_constant(4,4,&tex_index,0);

            //set textures as our render targets
	        gpu_handle_heap := GetGPUDescriptorHandleForHeapStart(default_srv_desc_heap.heap.value);
	        add_graphics_root_desc_table(1,default_srv_desc_heap.heap.value,gpu_handle_heap);
            
//	        gpu_handle_default_srv_desc_heap := GetGPUDescriptorHandleForHeapStart(default_srv_desc_heap.heap.value);
//	        add_graphics_root_desc_table(1,default_srv_desc_heap.heap.value,gpu_handle_default_srv_desc_heap);
            add_stencil_ref_command(1);

	        slot : int = 0;
	        for j := command.geometry.buffer_id_range.x;j <= command.geometry.buffer_id_range.y;j+=1{
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

init_custom_pass :: proc(){
    custom_pass.data.root_sig = default_root_sig;
}

setup_custom_pass :: proc(list : ^RenderCommandList(CustomRenderCommandList), matrix_buffer : ^con.Buffer(enginemath.f4x4),matrix_quad_buffer : ^con.Buffer(enginemath.f4x4),vp : ^CameraViewport){
    using enginemath
    using platform
    custom_pass.data.matrix_buffer = matrix_buffer;
    custom_pass.data.matrix_quad_buffer = matrix_quad_buffer;
    custom_pass.list = list;
    if vp != nil{
        color := f4{0,0,0,1};
        add_clear_command(color,vp.rt_cpu_handle,vp.resource_id);
        dsv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = GetCPUDescriptorHandleForHeapStart(depth_heap.value);
        add_clear_depth_stencil_command(true,1.0,true,1,&dsv_cpu_handle,depth_buffer);
    }
}

execute_custom_pass :: proc(pass : RenderPass(CustomPass,CustomRenderCommandList),vp : ^CameraViewport){
    using con;
    using la;
    using platform;
    using enginemath;    
    if buf_len(pass.list.list.command_buffer) > 0
    {
        ///renderer_set_write_list(pass.list);
        list := pass.list;
        matrix_buffer := pass.data.matrix_buffer;
        matrix_quad_buffer := pass.data.matrix_quad_buffer;
        pass_local := pass;
        //rt_mem := mem.raw_dynamic_array_data(pass.data.render_targets.buffer);
        //add_start_command_list_with_render_targets(3,rt_mem);

        if vp != nil{
            add_start_command_list_with_render_targets(1,&vp.rt_cpu_handle);
        }else{
            add_start_command_list_command();
        }
        
        for command in list.list.command_buffer.buffer{
            mat := buf_get(matrix_buffer,command.matrix_id);
            
            c_mat := buf_get(matrix_buffer,command.camera_matrix_id)
            proj_mat := buf_get(matrix_buffer,command.perspective_matrix_id)
            world_mat := mul(c_mat,mat)

            finalmat := mul(proj_mat,world_mat);
            mat[0].x = cast(f32)buf_len(matrix_quad_buffer^) * size_of(f4x4);

            base_color := command.geometry.base_color;
            mat[1] = [4]f32{base_color.x,base_color.y,base_color.z,base_color.w};

            buf_push(matrix_quad_buffer,finalmat);        

            mat[0].y = cast(f32)buf_len(matrix_quad_buffer^) * size_of(f4x4);

            buf_push(matrix_quad_buffer,mat);
            
            add_root_signature_command(default_root_sig);           

            rect := f4{0,0,ps.window.dim.x,ps.window.dim.y};        

            add_viewport_command(rect);

            add_scissor_command(rect);
            
            material := asset_ctx.asset_tables.materials[command.material_name];

            add_pipeline_state_command(material.pipeline_state);

            add_graphics_root32_bit_constant(0,16,&mat,0);
            add_graphics_root32_bit_constant(2,16,&finalmat,0);

            tex_index := command.texture_id;        
            add_graphics_root32_bit_constant(4,4,&tex_index,0);

            gpu_handle_default_srv_desc_heap := GetGPUDescriptorHandleForHeapStart(default_srv_desc_heap.heap.value);
            add_graphics_root_desc_table(1,default_srv_desc_heap.heap.value,gpu_handle_default_srv_desc_heap);

            slot : int = 0;
            for j := command.geometry.buffer_id_range.x;j <= command.geometry.buffer_id_range.y;j+=1{
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
            {       /**/
                add_draw_command(cast(u32)command.geometry.offset,cast(u32)command.geometry.count,platform.D3D12_PRIMITIVE_TOPOLOGY.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);                        
            }
            has_update = true;          
        }
        add_end_command_list_command();     
    }
    
    
//    if(has_update)
    {
//      mem.copy(mapped_matrix_data,mem.raw_dynamic_array_data(matrix_quad_buffer.buffer),cast(int)buf_len(matrix_quad_buffer) * size_of(f4x4));        
//      buf_clear(&matrix_quad_buffer);
    }
}

//
setup_imgui_pass :: proc(){
    using platform
    using enginemath

    current_backbuffer_index := GetCurrentBackBufferIndex(swap_chain);    
    rtv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,rtv_descriptor_heap,u64(current_backbuffer_index));

    color := f4{0,0,0,1};

    back_buffer_resource_id := get_current_back_buffer_resource_view_id();    
    add_clear_command(color,rtv_cpu_handle,back_buffer_resource_id);
 
    dsv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = GetCPUDescriptorHandleForHeapStart(depth_heap.value);

    add_clear_depth_stencil_command(true,1.0,true,1,&dsv_cpu_handle,depth_buffer);
}


dest_texture_resource : rawptr
src_buffer_resource : rawptr
current_image_size : enginemath.f2
draw_imgui :: proc(command_list : rawptr,imgui_heap : rawptr){
    barrier : platform.D3D12_RESOURCE_BARRIER = {};
    barrier.Type                   = .D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Flags                  = .D3D12_RESOURCE_BARRIER_FLAG_NONE;
    using platform

    dst_union : D3D12_TEXTURE_COPY_UNION
    dst_union.SubresourceIndex = 0

    dst_loc : D3D12_TEXTURE_COPY_LOCATION = {dest_texture_resource,
        .D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX,
        dst_union}

    buffer_footprint : D3D12_SUBRESOURCE_FOOTPRINT = {
       .DXGI_FORMAT_R32G32B32A32_FLOAT,
        u32(current_image_size.x),//Width  : c.uint,
        u32(current_image_size.y),
        1,
        u32(current_image_size.x) * 4 * 4,//size_of(32),//must be aligned to 256 byte boundary
    }

    src_union : D3D12_TEXTURE_COPY_UNION
    src_union.PlacedFootprint.Offset = 0
    src_union.PlacedFootprint.Footprint = buffer_footprint

    src_loc : D3D12_TEXTURE_COPY_LOCATION = {
            src_buffer_resource,
            .D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT,
            src_union,
    }

    CopyTextureRegion(command_list,&dst_loc,0,0,0,&src_loc,nil)


    current_backbuffer_index := platform.GetCurrentBackBufferIndex(swap_chain);    
    
    back_buffer_resource : rawptr;
    r : windows.HRESULT = GetBuffer(swap_chain,cast(u32)current_backbuffer_index, &back_buffer_resource);
    barrier.barrier_union.Transition.pResource   = back_buffer_resource;
    barrier.barrier_union.Transition.Subresource = platform.D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    barrier.barrier_union.Transition.StateBefore = .D3D12_RESOURCE_STATE_PRESENT;
    barrier.barrier_union.Transition.StateAfter  = .D3D12_RESOURCE_STATE_RENDER_TARGET;
                
    //gpu_handle_default_srv_desc_heap := GetGPUDescriptorHandleForHeapStart(default_srv_desc_heap.heap.value);
    //add_graphics_root_desc_table(1,default_srv_desc_heap.heap.value,gpu_handle_default_srv_desc_heap);

    ResourceBarrier(command_list,1, &barrier);
    for vp in &camera_system.viewports.buffer{
        vp_barrier :=  barrier
        vp_barrier.barrier_union.Transition.pResource   = con.buf_get(&resourceviews,vp.resource_id).state
        vp_barrier.barrier_union.Transition.Subresource = platform.D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        vp_barrier.barrier_union.Transition.StateBefore = .D3D12_RESOURCE_STATE_RENDER_TARGET;
        vp_barrier.barrier_union.Transition.StateAfter  = .D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE;
        ResourceBarrier(command_list,1, &vp_barrier);
    }
    
    
    desc_heaps : []rawptr = {imgui_heap};
    SetDescriptorHeaps(command_list,1, mem.raw_slice_data(desc_heaps[:]));
    ImGui_ImplDX12_RenderDrawData(imgui.get_draw_data(),command_list);
    barrier.barrier_union.Transition.StateBefore = .D3D12_RESOURCE_STATE_RENDER_TARGET;
    barrier.barrier_union.Transition.StateAfter  = .D3D12_RESOURCE_STATE_PRESENT;
    ResourceBarrier(command_list,1, &barrier);
    for vp in &camera_system.viewports.buffer{
        vp_barrier :=  barrier
        vp_barrier.barrier_union.Transition.pResource   = con.buf_get(&resourceviews,vp.resource_id).state
        vp_barrier.barrier_union.Transition.Subresource = platform.D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
        vp_barrier.barrier_union.Transition.StateBefore = .D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE;
        vp_barrier.barrier_union.Transition.StateAfter  = .D3D12_RESOURCE_STATE_RENDER_TARGET;
        ResourceBarrier(command_list,1, &vp_barrier);
    }    
}

execute_imgui_pass :: proc(imgui_heap : rawptr){
    add_start_command_list_command();
    add_callback_command(draw_imgui,imgui_heap);
    add_end_command_list_command();
}

init_pass :: proc(){

}

end_passes :: proc(){
    using con
    using enginemath
    //TODO(Ray):Have all the command lists a buffer iterate and clear
    con.buf_clear(&render.list.command_buffer)
    con.buf_clear(&light_render.list.command_buffer)
    con.buf_clear(&custom_render.list.command_buffer)\
    if(has_update)
    {
        mem.copy(mapped_matrix_data,mem.raw_dynamic_array_data(matrix_quad_buffer.buffer),cast(int)buf_len(matrix_quad_buffer) * size_of(f4x4));        
        buf_clear(&matrix_quad_buffer);
    }
}
