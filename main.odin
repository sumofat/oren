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
import entity "engine/entity"
//import sprite "engine/sprite"

//test game real games would use
//import game "../game"
import game "game"

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
	TODO: 
	1.Some issue with the lower you go to the bottom of the window mouse is slightly offset from imgui
	inputs.
		a. fixed when full screen but still probably issues when not in fullscreen investigate later
	2. input_floats and others not using pointers where arrays are rEQUIRED 
		a. change to multipointers
	3. create a basic engine update scheme
		a. there are a list of entities with a list of update functions
		b. the updpates are called in order
		
	3. Do a basic 2d editor
		A. Not doing instanced drawing yet first do the quad basic draw alpha blended-
		a. place bit mapped or color quads on a grid
		b. freeform placement
		c. basic animation
	*	d. use directdrawinstanced to render basic quads that share bit maps. 
			essentialy we will try to fit as many 2d quads into the same draw call.
		e. layers or groups can be flat mapped or use projection mapping as they go out into the distance to create a parralax effect
			(might be not how to do parralax rendering)
		f. need to make sure matrix works correctly ortho matrix.
		g. get basic sprites 
		h. figure out textures with the sprite system
		i. will need layers or groups
		j. do we need to have entities on sprites could just have the command written out by 
			something like drawsprite api save a for loop of sprites
		k. create a texture cache to ensure same texture doesnt get used twice unless intentional
		
	4. Entities // Low priority
		a. a flexible entity system
		b. attach systems array to the entity example:
			render would be removed from scene heiarcary traversal and we would make a render system list.
			with a list of all entityes that are render something.  Traverse that list 
		c. Making buckets of enities based on what components operate on  the entities in that bucket
		d. Use an anycache that can take a key of void and size to create hashes based on arbitrary compoenents.
		E. Experimenting with different ways of doing it quickly trying out different ways...
			we are at the point where we need to fill in the buckets of entity archetypes with new entities being 
			careful to track and copy the buckets when we add new archetypes.
		F. Start testing and pushing the ECS system with some quads/bitmaps of various Types
		G. Because the user game systems are created or later than this one
			any systems created here would be behind by one frame at least.
			fix this by sorting systems

	5. Scene Hierarchry  // Low priority as we not  use that mostly just flat mostly this will be used with just 
	//mesh rendering and animations
		a. Remove the full traversal every frame only traverse from that node when a transform is touched
		b. Remove mesh info from SceneObject should be tracked by systems themselves.
		c. for UI viewing only get the entity and systems attached to SO and reflect them.
		d. Make a UI button that doesnt diplay useful SO.  
		e. Filter by type / name etc..
	
	6. Asset Pipeline is very cumbersome
		1. allow to create a material with properties that can infer graphics state.
		2. refelct the shaders to further get the state and vertex layout required
		3. add some verification of the struct that is passed to the buffer when rendering to ensure matching
		4. having specific states on the pipeline is difficult
			a. we should have meta data for the pipeline associated with a shader

	7. RenderPipeline Dx12
		a. default_srv_heap count is the texture id we need to make a heap allocator that can keep track of free
		 	indexes into the heap and create new heaps and link them together when we have more than 512 textures in play at once.
		 	
	8. Memory CPU and GPU
		a. create a memory tracker for gpu and than cpu later.
		b. need to handle gpu memory allocation for constant buffers 
			a. resize / delete / create etc...

	9. Sound
		a. get some basic sound with fmod but before that we can try other more simple api's


	A. convert matrices to use the new builtin matrix in odin
	B. PullTime is a mess in win32.cpp possibly use odin native intrinsics for it in the future
	C. Have frozen meshes(meshes that are not only static in transform but also all properties) be ultra light
	   in that they dont need to be instantiated at SceneObjects as well just id to the mesh 
	 	could also be that if a property is changed that at that point it gets an instance on Scene

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
GWL_STYLE :: -16
set_screen_mode :: proc(ps : ^platform.PlatformState,is_full_screen : bool){
	platform.WINSetScreenMode(ps,is_full_screen)
}

spawn_window :: proc(ps : ^platform.PlatformState,windowName : cstring, width : u32 = 640, height : u32 = 480 ) -> (ErrorStr, WindowData){
    // Register the window class.
    using la;
	window : WindowData;

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

    if window32.register_class_ex_a(&wc) == 0 do return "Failed to register class!", window;

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
    
    if hwnd == nil do return "failed to create window!", window;

    
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


	   window_dim := enginemath.f2{1920, 1080};
	   window_p   := enginemath.f2{0, 0};
	   show_cmd: i32 = 0;
	   fmt.println(ps.is_running);
	   fmt.println(ps.window.handle);
	   result,window_data := spawn_window(&ps, "test window", cast(u32)window_dim.x, cast(u32)window_dim.y);
	   if len(result) == 0{
	   	set_screen_mode(&ps,true)
	   }
	   if !platform.PlatformInit(&ps, window_dim, window_p, 5) {
		fmt.println("Failed to initialize platform window!");
		   assert(false);
	   } else {
		   fmt.println("Initialized platform window!");
		   fmt.println(ps.is_running);
		   fmt.println(ps.window.handle);
		   fmt.println(ps.window.dim);
		   fmt.println("Initializing graphics Window and api's.");

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

			version := imgui.get_version();
	    	imgui.create_context();
	    	imgui.style_colors_dark();

			io := imgui.get_io();
			g_pd3dSrvDescHeap : ID3D12DescriptorHeap;
        	
			imgui_desc : platform.D3D12_DESCRIPTOR_HEAP_DESC;
	    	imgui_desc.Type = .D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
	    	imgui_desc.NumDescriptors = 1;
	    	imgui_desc.Flags = .D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
	    	g_pd3dSrvDescHeap = create_descriptor_heap(device.device,imgui_desc);

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
		assetctx_init(&asset_ctx)

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
		rc.m = la.MATRIX4F32_IDENTITY;

		matrix_buffer        := &asset_ctx.asset_tables.matrix_buffer;
		projection_matrix_id := buf_push(matrix_buffer, rc.projection_matrix);
		rc_matrix_id         := buf_push(matrix_buffer, rc.m);
		rc.projection_matrix_id = projection_matrix_id;
		rc.matrix_id = rc_matrix_id;

		rc_ui.ot.p = f3{};
		rc_ui.ot.r = la.quaternion_angle_axis(cast(f32)radians(0.0), f3{0, 0, 1});
		rc_ui.ot.s = f3{1, 1, 1};
		rc_ui.projection_matrix = init_screen_space_matrix(ps.window.dim);
		rc_ui.m = MATRIX4F32_IDENTITY;

		screen_space_matrix_id := buf_push(matrix_buffer, rc_ui.projection_matrix);
		identity_matrix_id     := buf_push(matrix_buffer, rc_ui.m);
		//End Camera Setups

		max_screen_p   := screen_to_world(rc.projection_matrix, rc.m, ps.window.dim, top_right_screen_xy, 0);
		lower_screen_p := screen_to_world(rc.projection_matrix, rc.m, ps.window.dim, bottom_left_xy, 0);

		material      := asset_ctx.asset_tables.materials["base"];
		mesh_material := asset_ctx.asset_tables.materials["mesh"];

		//game object setup 	
		//	test_model_result := asset_load_model(&asset_ctx,"data/BoxTextured.glb",mesh_material);
		test_model_result   := asset_load_model(&asset_ctx, "data/Lantern.glb", mesh_material);
		test_model_instance := create_model_instance(&asset_ctx, test_model_result);

		light_sphere_model_result := asset_load_model(&asset_ctx, "data/sphere.glb", mesh_material, SceneObjectType.light);
		light_sphere_instance     := create_model_instance(&asset_ctx, light_sphere_model_result);

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
		//TODO(Ray):Need to tighten this up !!! if we try to push more matrices than we have 
		//allocated for will silently failmapped_matrix_data
		matrix_mem_size: u64 = (size_of(f4x4)) * 900;
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

		//init of render passes
		init_gbuffer_pass();
		//        init_projective_pass();
		init_lighting_pass1();
		init_lighting_pass2();
		//		    init_perspective_projection_pass();
		init_composite_pass(&asset_ctx);
		init_custom_pass()
		//end render passes
	
	//test game stuuff
		speed : f32 = 10;	
		yspeed : f32 = 1;
		dir : f32 = 1;					
		ydir : f32 = 1;
		
		//editor stuff
		show_demo_window := true;

		using editor;
		editor_scene_tree : EditorSceneTree;
		editor_scene_tree_init(&editor_scene_tree);
		should_show_log : bool = true
			
		using entity
		
		init_ecs()
		init_buckets()

		//TODO(Ray):Because the user game systems are created or later than this one
		//any systems created here would be behind by one frame at least.
		//fix this by sorting systems
		init_sprite_render_system()
		//Examples ECS
		init_lantern()
		add_lantern_ecs(test_model_instance)

		//NOTE(RAY):First frame of running will be an init frame called by the game.
		//that can setup systems ect...
		init_frame_done := false

		for ps.is_running {	
			PullMouseState(&ps)
			PullTimeState(&ps)
			dt := ps.time.delta_seconds
			io.mouse_pos = imgui.Vec2{f32(ps.input.mouse.p.x),f32(ps.input.mouse.p.y)};	
			io.mouse_down[0] = ps.input.mouse.lmb.down;
			//editor
    		ImGui_ImplDX12_NewFrame();
        	ImGui_ImplWin32_NewFrame();
			imgui.new_frame();
			if show_demo_window do imgui.show_demo_window(&show_demo_window);

			fmj_editor_scene_tree_show(&editor_scene_tree,&test_scene,&asset_ctx);
			show_log(&should_show_log)
 			
 			if !init_frame_done{
	 			game.init()
	 			init_frame_done = true
 			}else{
	 			game.update(ps.time.delta_seconds)
 			}

//Entity Logic Execute
			update_ecs_entities()			

//editor
			imgui.render();

			update_scene(&asset_ctx, &test_scene);

//Prepare Rendering 
			issue_render_commands(&render, &light_render, &test_scene, &asset_ctx, rc_matrix_id, projection_matrix_id);
			//            issue_light_render_commands(&light_render,&test_scene,&asset_ctx,rc_matrix_id,projection_matrix_id);            

//Execute Rendering
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

			setup_custom_pass(&custom_render, matrix_buffer, &matrix_quad_buffer)
			execute_custom_pass(custom_pass)

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
			ps.is_running = handle_msgs(&window_data);
			 //}

        		
			//TODO(Ray):Have all the command lists a buffer iterate and clear
			end_passes()
			//buf_clear(&render.list.command_buffer);
			//buf_clear(&light_render.list.command_buffer);
		}
	}
}
