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
import con "engine/containers"
import enginemath "engine/math"

import imgui  "engine/external/odin-imgui";
import runtime "core:runtime"
import editor "engine/editor"
//Graphics
/*
	Start with a simple deffered renderer and figure out how we want the pipeline to work
	Now we are doing imgui integration than some basic editor functionality try using odin RTTI
	
	clear : done
	depth pre pass
	g buffer passes : started
	shadow pass 
	light accum pass : seems done
	buffer composite pass : ok for now

	imgui integration : BASICS DONE
	FIXme: Some issue with the lower you go to the bottom of the window mouse is slightly offset from imgui
	inputs.

	graphics:
	sponza model loading : todo
	sun light : todo
	spot light : todo
	point light shadows : todo
	cascading shadow maps : todo
	spotlight shadows : todo
	present : done
	Once we get to point lights basic point lights.
	Next basic sun and spotlights.
	Than we do point light shadows than sun (cascading shadow maps) and than spotlight shadows.

	animation:
	3d bones : todo
	skinned meshes : todo

	physics:
	basic particle system : todo
	physx integration : todo
	
	Look at implementing a simple render graph even if it does nothing at first lets collect
	the info on resources and references etc...
*/

/*
	Once we have basic lighting (meaning lights and shadows) 
	working we will start working on quality of life things.
	
	TODO:
	We have the light sphere rendered scaling is off on imported models need to verify 
	what we want there.
	
	A basic roadmap....
	
	Make sure we can load the sponza model. which will be our reference model.
	
	Than IMGUI integration.
	Saving of scenes to disk.  SO with references to assets and lights / set properties on scene objects.
	
	Than basic picking and moving of objects via mouse.
	
	Than back to graphics starting with shadows.. first point lights directional lights than cascading shadow maps .
	We will use the virutal texture method as in doom using summmons reference code.
	
	Than do basic skeletal animation bones than skinning.
	
	at that point we will want to move onto something new which will be rendering techniques.
	
*/
Wnd_Proc :: proc "std" (hwnd : window32.Hwnd, uMsg : u32, wParam : window32.Wparam, lParam : window32.Lparam) -> window32.Lresult{
	context = runtime.default_context();
	platform.ImGui_ImplWin32_WndProcHandler(hwnd, uMsg, wParam, lParam);//{

    switch (uMsg){
    	case window32.WM_DESTROY:{
    	    window32.post_quit_message(0);
    	    return 0;
        }
    	case window32.WM_PAINT:{
    	    ps : window32.Paint_Struct = {};
    	    hdc : window32.Hdc = window32.begin_paint(hwnd, &ps);

    	    //window32.fill_rect(hdc, &ps.rcPaint, window32.COLOR_BACKGROUND);

    	    window32.end_paint(hwnd, &ps);
    	    return 0;
    	}
    }
    return window32.def_window_proc_a(hwnd, uMsg, wParam, lParam);
}

WindowData :: struct {
    hInstance : window32.Hinstance,
    hwnd : window32.Hwnd,
    width : u32,
    height : u32,
};

ErrorStr :: cstring;


spawn_window :: proc(ps : ^platform.PlatformState,windowName : cstring, width : u32 = 640, height : u32 = 480 ) -> (ErrorStr, ^WindowData){
    // Register the window class.
    using la;

    CLASS_NAME : cstring = "Main Vulkan Window";

    wc : window32.Wnd_Class_Ex_A = {}; 

    hInstance := cast(window32.Hinstance)(window32.get_module_handle_a(nil));
    ps.is_running = true;
    ps.window.dim = Vector2f32{f32(width), f32(height)};
    ps.window.p = Vector2f32{};
    
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
        window32.CW_USEDEFAULT, window32.CW_USEDEFAULT, i32(ps.window.dim.x), i32(ps.window.dim.y),
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

handle_msgs :: proc(window : ^WindowData) -> bool{
    msg : window32.Msg = {};
    cont : bool = true;
    for window32.peek_message_a(&msg, nil, 0, 0, window32.PM_REMOVE){ 
        if msg.message == window32.WM_QUIT do cont = false;
        window32.translate_message(&msg);
        window32.dispatch_message_a(&msg);
    }
    return cont;
}
main :: proc() {
	   using la;
	   using gfx;
	   using con;
	   using platform;
	   fmt.println("Executing Main!");

	   //    x :f32 = math.degrees(20);
	   //    fmt.println(x);
	   //    x = fmj.radians(x);
	   //    fmt.println(x);    
	   //    fmt.println(x);

	   window_dim := enginemath.f2{1920, 1080};
	   window_p   := enginemath.f2{0, 0};
	   show_cmd: i32 = 0;
	   //    platform.ps.is_running  = true;

	   //    testPlatformInit(&platform.ps,100);
	   //fmt.println(platform.ps);
	   fmt.println(ps.is_running);
	   fmt.println(ps.window.handle);
	   //    if !platformtest(&platform.ps,window_dim,window_p)
	   result,window_data := spawn_window(&ps, "test window", cast(u32)window_dim.x, cast(u32)window_dim.y);

	   if !platform.PlatformInit(&ps, window_dim, window_p, 5) {
		   fmt.println("Failed to initialize platform window!");
		   assert(false);
	   } else {
		   fmt.println("Initialized platform window!");
		   fmt.println(ps.is_running);
		   fmt.println(ps.window.handle);
		   fmt.println(ps.window.dim);
		   fmt.println("Initializing graphics Window and api's.");
		   //Lets init directx12


		   init_result := gfx.init(&ps);

		   if (init_result.is_init) {
			device = init_result.device;
			//Do some setup if needed
			fmt.println("Graphics are initialized...");
		} else {
			//Could not initialize graphics device.
			fmt.println("Failed to initialize graphics...");
			assert(false);
		}

		//editor //imgui
		//res := Imgui_State{};
		version := imgui.get_version();
    	imgui.create_context();
    	imgui.style_colors_dark();

		io := imgui.get_io();
		
    	///imglfw.setup_state(window, true);

    	//imgl.setup_state(&res.opengl_state);

		//imgui_state := res;//imgui.init_imgui_state(window);
    	//io := imgui.get_io();
		g_pd3dSrvDescHeap : ID3D12DescriptorHeap;
        	
		imgui_desc : platform.D3D12_DESCRIPTOR_HEAP_DESC;
    	imgui_desc.Type = .D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
    	imgui_desc.NumDescriptors = 1;
    	imgui_desc.Flags = .D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
    	g_pd3dSrvDescHeap = create_descriptor_heap(device.device,imgui_desc);
        //if g_pd3dSrvDescHeap != nil{
            //return false;
        //    assert(false);    
		//}

		assert(g_pd3dSrvDescHeap.value != nil);

		ImGui_ImplWin32_Init(ps.window.handle);
		ImGui_ImplDX12_Init(device.device, gfx.num_of_back_buffers,
			.DXGI_FORMAT_R8G8B8A8_UNORM, g_pd3dSrvDescHeap.value,
			GetCPUDescriptorHandleForHeapStart(g_pd3dSrvDescHeap.value),
			GetGPUDescriptorHandleForHeapStart(g_pd3dSrvDescHeap.value));

		using gfx;
		using enginemath;
		//	using platform;

		//engine init
		assetctx_init(&asset_ctx);
		render       := renderer_init(40_000,GeometryRenderCommandList,RenderCommand);
		light_render := renderer_init(1_000,LightRenderCommandList,LightRenderCommand);

		//scene
		scenes := make(map[string]Scene);
		defer delete(scenes);

		scene := scenes["test"];


		test_scene := scene_init("test");
		rn_id      := scene_add_so(&asset_ctx, &test_scene.buffer, enginemath.f3{0, 0, 0}, QUATERNIONF32_IDENTITY, enginemath.f3{1, 1, 1}, "root_so");

		root_so := buf_chk_out(&asset_ctx.scene_objects, rn_id);

		root_t := transform_init();
		root_so.transform = root_t;
		buf_chk_in(&asset_ctx.scene_objects);

		desc_heap_desc: D3D12_DESCRIPTOR_HEAP_DESC;
		MAX_SRV_DESC_HEAP_COUNT: u32 = 512; // NOTE(Ray Garner): totally arbiturary number
		desc_heap_desc.NumDescriptors = MAX_SRV_DESC_HEAP_COUNT;
		desc_heap_desc.Type = .D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
		desc_heap_desc.Flags = .D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
		default_srv_desc_heap.heap = platform.create_descriptor_heap(device.device, desc_heap_desc);


		def_r := quaternion_angle_axis(degrees(cast(f32)0.0), enginemath.f3{0, 0, 1});

		top_right_screen_xy := f2{ps.window.dim.x, ps.window.dim.y};
		bottom_left_xy      := f2{0, 0};

		rc:    RenderCamera;
		rc_ui: RenderCamera;

		//Camera setup
		rc.ot.p = enginemath.f3{};
		rc.ot.r = la.quaternion_angle_axis(cast(f32)radians(0.0), f3{0, 0, 1});
		rc.ot.s = f3{1, 1, 1};

		aspect_ratio := ps.window.dim.x / ps.window.dim.y;
		size         := f2{300, 300};
		size.x = size.x * aspect_ratio;
		//    rc.projection_matrix = init_ortho_proj_matrix(size,0.0f,1.0f);
		rc.fov = 80;
		rc.near_far_planes = f2{0.1, 1000};
		rc.projection_matrix = init_pers_proj_matrix(ps.window.dim, rc.fov, rc.near_far_planes);
		rc.matrix = la.MATRIX4F32_IDENTITY;

		matrix_buffer        := &asset_ctx.asset_tables.matrix_buffer;
		projection_matrix_id := buf_push(matrix_buffer, rc.projection_matrix);
		rc_matrix_id         := buf_push(matrix_buffer, rc.matrix);
		rc.projection_matrix_id = projection_matrix_id;
		rc.matrix_id = rc_matrix_id;

		rc_ui.ot.p = f3{};
		rc_ui.ot.r = la.quaternion_angle_axis(cast(f32)radians(0.0), f3{0, 0, 1});
		rc_ui.ot.s = f3{1, 1, 1};
		rc_ui.projection_matrix = init_screen_space_matrix(ps.window.dim);
		rc_ui.matrix = MATRIX4F32_IDENTITY;

		screen_space_matrix_id := buf_push(matrix_buffer, rc_ui.projection_matrix);
		identity_matrix_id     := buf_push(matrix_buffer, rc_ui.matrix);
		//End Camera Setups

		max_screen_p   := screen_to_world(rc.projection_matrix, rc.matrix, ps.window.dim, top_right_screen_xy, 0);
		lower_screen_p := screen_to_world(rc.projection_matrix, rc.matrix, ps.window.dim, bottom_left_xy, 0);

		material      := asset_ctx.asset_tables.materials["base"];
		mesh_material := asset_ctx.asset_tables.materials["mesh"];

		//game object setup 	
		//	test_model_result := asset_load_model(&asset_ctx,"data/BoxTextured.glb",mesh_material);
		test_model_result   := asset_load_model(&asset_ctx, "data/Lantern.glb", mesh_material);
		test_model_instance := create_model_instance(&asset_ctx, test_model_result);

		light_sphere_model_result := asset_load_model(&asset_ctx, "data/sphere.glb", mesh_material, SceneObjectType.light);
		light_sphere_instance     := create_model_instance(&asset_ctx, light_sphere_model_result);


		//	    add_new_child_to_scene_object(&asset_ctx,rn_id,f3{},Quat{},f3{1,1,1},nil,"test_so");

		test_so := buf_chk_out(&asset_ctx.scene_objects, test_model_result.scene_object_id);
		test_so.name = string("track so");

		mesh_id: u64;

		new_trans := transform_init();
		new_trans.s = f3{1, 1, 1};
		new_trans.p = f3{0, -15, -10};

		add_child_to_scene_object(&asset_ctx, rn_id, test_model_instance, new_trans);
		new_trans.p = f3{0, 0, -6};
		new_trans.s = f3{1, 1, 1} * 10;
		add_child_to_scene_object(&asset_ctx, rn_id, light_sphere_instance, new_trans);

		test_light_transform := get_t(light_sphere_instance);
		add_light(&test_scene, test_light_transform.p);

		/*
			//TODO(Ray):Making mapped memory to the gpu needs to be simplified and idiot proffed
			//light memory for mapping
			light_list_mem_size : u64 = (size_of(Light)) * 100;
			light_list_gpu_arena := AllocateGPUArena(device.device,light_list_mem_size);
			set_arena_constant_buffer(device.device,&light_list_gpu_arena,default_srv_desc_heap.count,default_srv_desc_heap.heap);
			default_srv_desc_heap.count += 1;
			//Map(light_list_gpu_arena.resource,0,nil,&light_list_data);
		*/

		//matrix memory for mapping        
		matrix_mem_size: u64 = (size_of(f4x4)) * 100;
		matrix_gpu_arena := AllocateGPUArena(device.device, matrix_mem_size);

		set_arena_constant_buffer(device.device, &matrix_gpu_arena, default_srv_desc_heap.count, default_srv_desc_heap.heap);
		default_srv_desc_heap.count += 1;

		Map(matrix_gpu_arena.resource, 0, nil, &mapped_matrix_data);

		/*
			if(!get_mesh_id_by_name("Box",&asset_ctx,test_so,&mesh_id))
			{
			assert(false);    
			}
		*/

		//Create a test light
		test_light: Light = {f3{0, 0, 0}, f4{1, 1, 1, 1}, 10, 1};
		buf_push(&test_scene.lights, test_light);

		buf_chk_in(&asset_ctx.scene_objects);
		//end game object setup

		//experimental
		init_gbuffer_pass();
		//        init_projective_pass();
		init_lighting_pass1();
		init_lighting_pass2();
		//		    init_perspective_projection_pass();
			init_composite_pass(&asset_ctx);
			//end experimental
	
		speed : f32 = 0.01;	
		yspeed : f32 = 0.1;
		dir : f32 = 1;					
		ydir : f32 = 1;
		
		show_demo_window := true;

		using editor;
		editor_scene_tree : EditorSceneTree;
		editor_scene_tree_init(&editor_scene_tree);

		for ps.is_running {	
			PullMouseState(&ps);
			io.mouse_pos = imgui.Vec2{f32(ps.input.mouse.p.x),f32(ps.input.mouse.p.y)};	
			io.mouse_down[0] = ps.input.mouse.lmb.down;
			//editor
			//imglfw.update_display_size();
    		//imglfw.update_mouse();
    		//imglfw.update_dt();
    		ImGui_ImplDX12_NewFrame();
        	ImGui_ImplWin32_NewFrame();
			imgui.new_frame();
			if show_demo_window do imgui.show_demo_window(&show_demo_window);

			fmj_editor_scene_tree_show(&editor_scene_tree,&test_scene,&asset_ctx);


			//get_local_	p(test_model_instance).x += 0.001;
			t := get_t(test_model_instance);
			if t.p.x > 4{
				dir = -1;
			}	
			else if t.p.x < -4{
				dir = 1;
			}	

			if t.p.z < -10{
				ydir = 1;
			}
			else if t.p.z > -6{
				ydir = -1;
			}
			t.local_p.x += speed * dir;
			t.local_p.z += yspeed * ydir;
				//get_local_s(test_model_instance)^ += f3{0.001, 0.001, 0.001};
				//            get_t(test_model_instance).s += f3{0.1,0.1,0.1};
	
				//End game update
			
			//editor
			imgui.render();
			
			update_scene(&asset_ctx, &test_scene);
			issue_render_commands(&render, &light_render, &test_scene, &asset_ctx, rc_matrix_id, projection_matrix_id);
			//            issue_light_render_commands(&light_render,&test_scene,&asset_ctx,rc_matrix_id,projection_matrix_id);            

			//Deffered rendering
			//GBUFFER Pass
			setup_gbuffer_pass(&render, matrix_buffer, &matrix_quad_buffer);
			execute_gbuffer_pass(gbuffer_pass);

			//lighting pass
			setup_lighting_pass1(&light_render, matrix_buffer, &matrix_quad_buffer);
			execute_lighting_pass1(light_accum_pass1);

			//lighting pass
			setup_lighting_pass2(&light_render, matrix_buffer, &matrix_quad_buffer);
			execute_lighting_pass2(light_accum_pass2);

			//composite pass
			setup_composite_pass();
			execute_composite_pass(composite_pass);

            setup_imgui_pass();
            execute_imgui_pass(g_pd3dSrvDescHeap.value);
			//Basic forward rendering
			//Basic pass
			//	        setup_perspective_projection_pass(&render,matrix_buffer,&matrix_quad_buffer);
			//	        execute_perspective_projection_pass(pers_proj_pass);

			execute_frame();
			
			//platform.HandleWindowsMessages(&ps);
			 //if
			 
			 //}else{
			ps.is_running = handle_msgs(window_data);
			 //}

        		
			//TODO(Ray):Have all the command lists a buffer iterate and clear
			buf_clear(&render.list.command_buffer);
			buf_clear(&light_render.list.command_buffer);
		}
	}
}
