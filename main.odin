package main

import "core:fmt"
import "core:c"
import "core:mem"
import windows "core:sys/windows"
import window32 "core:sys/win32"
import la "core:math/linalg"

import platform "engine/platform"
import fmj "engine/fmj"
import gfx "engine/graphics"

//first test importing libs that we compile here with the foreign system.
//starting with simple C lib FMJ

//Graphics

//Get a window and some basic rendering working.
ErrorStr :: cstring;

WindowData :: struct {
    hInstance : window32.Hinstance,
    hwnd : window32.Hwnd,
    width : u32,
    height : u32,
};

Wnd_Proc :: proc "std" (hwnd : window32.Hwnd, uMsg : u32, wParam : window32.Wparam, lParam : window32.Lparam) -> window32.Lresult
{
    switch (uMsg)
    {
	case window32.WM_DESTROY:
        {
	    window32.post_quit_message(0);
	    return 0;
        }
	case window32.WM_PAINT:
	{
	    ps : window32.Paint_Struct = {};
	    hdc : window32.Hdc = window32.begin_paint(hwnd, &ps);

	    //window32.fill_rect(hdc, &ps.rcPaint, window32.COLOR_BACKGROUND);

	    window32.end_paint(hwnd, &ps);
	    return 0;
	}
    }
    return window32.def_window_proc_a(hwnd, uMsg, wParam, lParam);
}

spawn_window :: proc(ps : ^platform.PlatformState,windowName : cstring, width : u32 = 640, height : u32 = 480 ) -> (ErrorStr, ^WindowData)
{
    // Registerl the window class.
    CLASS_NAME : cstring = "Main Vulkan Window";

    wc : window32.Wnd_Class_Ex_A = {}; 

    hInstance := cast(window32.Hinstance)(window32.get_module_handle_a(nil));
    ps.is_running = true;
    ps.window.dim = gfx.f2{cast(f32)width, cast(f32)height};
    ps.window.p = gfx.f2{};
    
    wc.size = size_of(window32.Wnd_Class_Ex_A);
    wc.wnd_proc = Wnd_Proc;
    wc.instance = hInstance;
    wc.class_name = CLASS_NAME;

    if window32.register_class_ex_a(&wc) == 0 do return "Failed to register class!", nil;

    hwnd := window32.create_window_ex_a(
        0,
        CLASS_NAME,
        windowName,
        window32.WS_OVERLAPPEDWINDOW | window32.WS_VISIBLE,
        window32.CW_USEDEFAULT, window32.CW_USEDEFAULT, cast(i32)width, cast(i32)height,
        nil,
        nil,
        hInstance,
        nil,
    );

    ps.window.handle = hwnd;
    
    if hwnd == nil do return "failed to create window!", nil;

    window := new(WindowData);
    window.hInstance = hInstance;
    window.hwnd = hwnd;
    window.width = width;
    window.height = height;

    return nil, window;
}

handle_msgs :: proc(window : ^WindowData) -> bool
{
    msg : window32.Msg = {};
    cont : bool = true;
    for window32.peek_message_a(&msg, nil, 0, 0, window32.PM_REMOVE)
    { 
        if msg.message == window32.WM_QUIT do cont = false;
        window32.translate_message(&msg);
        window32.dispatch_message_a(&msg);
    }
    return cont;
}

main :: proc()
{
    using la;
    using gfx;    
    fmt.println("Hellope!");

    x :f32 = fmj.degrees(20);
    fmt.println(x);
    x = fmj.radians(x);
    fmt.println(x);    
    fmt.println(x);
    ps : platform.PlatformState;
    window_dim := f2{1920,1080};
    window_p := f2{0,0};
    show_cmd : i32 = 0;
//    ps.is_running  = true;

    //    testPlatformInit(&ps,100);
    //fmt.println(ps);
    fmt.println(ps.is_running);
    fmt.println(ps.window.handle);
    //    if !platformtest(&ps,window_dim,window_p)
    spawn_window(&ps,"test window",cast(u32)window_dim.x,cast(u32)window_dim.y);
    
    if !platform.PlatformInit(&ps,window_dim,window_p,5)    
    {
	fmt.println("Failed to initialize platform window!");
	assert(false);
    }
    else
    {
        fmt.println("Initialized platform window!");
        fmt.println(ps.is_running);
	fmt.println(ps.window.handle);
	fmt.println(ps.window.dim);
	fmt.println("Initializing graphics Window and api's.");
//	fmt.println(ps.time);
	//Lets init directx12
	
	init_result := platform.Init(&ps.window.handle,ps.window.dim);

	if (init_result.is_init)
	{
            //Do some setup if needed
            fmt.println("Graphics are initialized...");
	    device = init_result.device;
	    gfx.init(&ps);	    
	}
	else
	{
            //Could not initialize graphics device.
            fmt.println("Failed to initialize graphics...");	    	    
            assert(false);
	}

	using gfx;
	using platform;

	//engine init
	assetctx_init(&asset_ctx);
	render := renderer_init();
	//scene
	scenes := make(map[string]Scene);
	defer delete(scenes);
	
	scene := scenes["test"];
	
	test_scene := scene_init("test");
	rn_id := scene_add_so(&asset_ctx,&test_scene.buffer,f3{0,0,0},QUATERNION_IDENTITY,f3{1,1,1},"test_so");

	root_so := buf_chk_out(&asset_ctx.scene_objects,rn_id);	

	root_t := transform_init();
	root_so.transform = root_t;
	buf_chk_in(&asset_ctx.scene_objects);
	
	/*
    scene_manager = {0};
    scene_manager.current_scene = test_scene;
    scene_manager.root_node_id = root_node_id;
*/

	desc_heap_desc : D3D12_DESCRIPTOR_HEAP_DESC;
	MAX_SRV_DESC_HEAP_COUNT : u32 = 512;// NOTE(Ray Garner): totally arbiturary number
	desc_heap_desc.NumDescriptors =  MAX_SRV_DESC_HEAP_COUNT;	    
	desc_heap_desc.Type = .D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
	desc_heap_desc.Flags = .D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
	default_srv_desc_heap = create_descriptor_heap(device,desc_heap_desc);

	def_r := quaternion_angle_axis(degrees(cast(f32)0.0),f3{0,0,1});	

	top_right_screen_xy := f2{ps.window.dim.x,ps.window.dim.y};
	bottom_left_xy := f2{0,0};

	rc : RenderCamera;
	rc_ui : RenderCamera;

	//Camera setup
	rc.ot.p = f3{};
	rc.ot.r = la.quaternion_angle_axis(cast(f32)radians(0.0),f3{0,0,1});
	rc.ot.s = f3{1,1,1};

	aspect_ratio := ps.window.dim.x / ps.window.dim.y;
	size := f2{300,300};
	size.x = size.x * aspect_ratio;
	//    rc.projection_matrix = init_ortho_proj_matrix(size,0.0f,1.0f);
	rc.fov = 80;
	rc.near_far_planes = f2{0.1,1000};
	rc.projection_matrix = init_pers_proj_matrix(ps.window.dim,rc.fov,rc.near_far_planes);
	rc.matrix = la.MATRIX4_IDENTITY;
	
	matrix_buffer := &asset_ctx.asset_tables.matrix_buffer;
	projection_matrix_id := buf_push(matrix_buffer,rc.projection_matrix);
	rc_matrix_id := buf_push(matrix_buffer,rc.matrix);
	rc.projection_matrix_id = projection_matrix_id;
	rc.matrix_id = rc_matrix_id;

	rc_ui.ot.p = f3{};
	rc_ui.ot.r = la.quaternion_angle_axis(cast(f32)radians(0.0),f3{0,0,1});
	rc_ui.ot.s = f3{1,1,1};
	rc_ui.projection_matrix = init_screen_space_matrix(ps.window.dim);
	rc_ui.matrix = MATRIX4_IDENTITY;
	
	screen_space_matrix_id := buf_push(matrix_buffer,rc_ui.projection_matrix);
	identity_matrix_id := buf_push(matrix_buffer,rc_ui.matrix);
	//End Camera Setups

	matrix_quad_buffer := buf_init(200,f4x4);
	
	max_screen_p := screen_to_world(rc.projection_matrix,rc.matrix,ps.window.dim,top_right_screen_xy,0);
	lower_screen_p := screen_to_world(rc.projection_matrix,rc.matrix,ps.window.dim,bottom_left_xy,0);

	material := asset_ctx.asset_tables.materials["base"];
	mesh_material := asset_ctx.asset_tables.materials["mesh"];
	
//game object setup 	
	//	test_model_result := asset_load_model(&asset_ctx,"data/BoxTextured.glb",mesh_material);
	test_model_result := asset_load_model(&asset_ctx,"data/Lantern.glb",mesh_material);	
	test_model_instance := create_model_instance(&asset_ctx,test_model_result);
	
	add_new_child_to_scene_object(&asset_ctx,rn_id,f3{},Quat{},f3{1,1,1},nil,"test_so");
	
	test_trans := transform_init();
	test_trans.r = quaternion_angle_axis(radians(f32(0.0)),f3{});
    
	test_so := buf_chk_out(&asset_ctx.scene_objects,test_model_result.scene_object_id);
	test_so.name = string("track so");
	
	mesh_id : u64;

	new_trans := transform_init();
	new_trans.s = f3{1,1,1};
	new_trans.p = f3{0,0,-10};
	
	add_child_to_scene_object(&asset_ctx,rn_id,test_model_instance,new_trans);

	matrix_mem_size : u64 = (size_of(f4x4)) * 100;
	matrix_gpu_arena := AllocateGPUArena(matrix_mem_size);
	
	set_arena_constant_buffer(device.device,&matrix_gpu_arena,4,default_srv_desc_heap);
	mapped_matrix_data : rawptr;
	Map(matrix_gpu_arena.resource,0,nil,&mapped_matrix_data);
	
	/*
	if(!get_mesh_id_by_name("Box",&asset_ctx,test_so,&mesh_id))
	{
            assert(false);    
	}
*/

	buf_chk_in(&asset_ctx.scene_objects);
	
	test_mesh := buf_get(&asset_ctx.asset_tables.meshes,mesh_id);	
//end game object setup

        for ps.is_running
        {
	    update_scene(&asset_ctx,&test_scene);
            issue_render_commands(&render,&test_scene,&asset_ctx,rc_matrix_id,projection_matrix_id);

	    has_update := false;
	    if buf_len(render.command_buffer) > 0
	    {
		AddStartCommandListCommand();

		for command in render.command_buffer.buffer
		{
                    m_mat := buf_get(matrix_buffer,command.model_matrix_id);
                    c_mat := buf_get(matrix_buffer,command.camera_matrix_id);
                    proj_mat := buf_get(matrix_buffer,command.perspective_matrix_id);
                    world_mat := mul(c_mat,m_mat);
                    finalmat := mul(proj_mat,world_mat);
                    m_mat[0].x = cast(f32)buf_len(matrix_quad_buffer) * size_of(f4x4);
                    m_mat[0].y = 5.0;

                    base_color := command.geometry.base_color;
		    m_mat[1] = [4]f32{base_color.x,base_color.y,base_color.z,base_color.w};
		    
                    buf_push(&matrix_quad_buffer,finalmat);        

		    AddRootSignatureCommand(gfx.default_root_sig);
		    
		    rect := fmj.f4{0,0,window_dim.x,window_dim.y};	    
		    AddViewportCommand(rect);
		    //full screen rect
		    AddScissorRectCommand(rect);
		    
		    material := asset_ctx.asset_tables.materials[command.material_name];
		    AddPipelineStateCommand(material.pipeline_state);

		    AddGraphicsRoot32BitConstant(0,16,&m_mat,0);
		    AddGraphicsRoot32BitConstant(2,16,&finalmat,0);

		    tex_index := command.texture_id;	    
		    AddGraphicsRoot32BitConstant(4,4,&tex_index,0);

//		    AddGraphicsRootDescTable(1,nil,D3D12_GPU_DESCRIPTOR_HANDLE{});
		    gpu_handle_default_srv_desc_heap := GetGPUDescriptorHandleForHeapStart(default_srv_desc_heap.value);
		    AddGraphicsRootDescTable(1,default_srv_desc_heap.value,gpu_handle_default_srv_desc_heap);

		    slot : int = 0;
		    for j := command.geometry.buffer_id_range.x;j <= command.geometry.buffer_id_range.y;j+=1 
		    {
			bv := buf_get(&asset_ctx.asset_tables.vertex_buffers,cast(u64)j);
			AddSetVertexBufferCommand(cast(u32)slot,bv);
			slot += 1;
		    }

		    if command.is_indexed
                    {
			ibv := buf_get(&asset_ctx.asset_tables.index_buffers,command.geometry.index_id);
			AddDrawIndexedCommand(cast(u32)command.geometry.index_count,cast(u32)command.geometry.offset,platform.D3D12_PRIMITIVE_TOPOLOGY.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST,ibv);
                    }
		    else
                    {
			AddDrawCommand(cast(u32)command.geometry.offset,cast(u32)command.geometry.count,platform.D3D12_PRIMITIVE_TOPOLOGY.D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);                        
                    }
                    has_update = true;		    
		}
		platform.AddEndCommandListCommand();		
	    }

            if(has_update)
            {
		mem.copy(mapped_matrix_data,mem.raw_dynamic_array_data(matrix_quad_buffer.buffer),cast(int)buf_len(matrix_quad_buffer) * size_of(f4x4));		
		buf_clear(&matrix_quad_buffer);
            }
	    
	    platform.EndFrame();
	    platform.HandleWindowsMessages(&ps);

	    buf_clear(&render.command_buffer);
	    
        }
    }
}

