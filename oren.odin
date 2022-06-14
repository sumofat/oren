package oren

import "core:fmt"
import "core:c"
import "core:mem"
import windows "core:sys/windows"
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

/*

SPRITE EDITOR
# Idea
	| We are potentionally creating a framework for doing random and procedural texture creation at runtime 
	| which could be also extended to a nocode solution using some generalized tools for artist such as 
	| setting a paint area with color range and random number gen.  
	| We want to also move the engine out of being wholistic and set the game code to be loaded as a module.
# Architecture
	| In general the code for doing graphics needs to be revamped and cleaned up.
	| 
	| We need a concept for a copyable texture/buffer to the gpu right now its very cumbersome
# brushes
	| The whole painting algorith needs to be redone perhaps with a volume
	| calculated per frame that is painted in rather than just stamping the brush per frame.
	| Calculate the rows per frame and divy them out to threads trying to get locality asmuch as possible
	| Also try to flatten at the same time.
	| Finally simify if it makes sense 
	| NI : allow brush size change(basics done but not centered around selected pixel) 
	| NI : show texel selection with pink outlines kind of have this
	| line tool allow for setting width specifically 2x1 line tool (Requestd by Timothy)'
	| square brush, circle brush, line brush
# Swatches
# ramps 
# pallete creation 
	| allow associating a swatch to a layer 
	| easily allow gradients to be created
	| easily create palletes based on an HSV curve that the user can create and adjust 
	| at any time.
	| 
# fill
# eyepicker

# move layers
	| calculate bounds rect while drawing on layer
	| when move/rotate without selecting anything whole layer is always auto selected
	| Have to be able to move layer contents
	| Rotate layer contents
	| TODO(Ray):Scale layer contents//will do this later for now we need to make brushes better.

#selection 
	| make selections
	| delete selections
	| fill selections
	| Move / Rotate and scale selections
	| magic wand selections 
	| selections based on pixel perfect rules or solid boundary rules
# filters 
	| bicubic
	| nearest neighbor

//low priority
# performance
	| cache the layer composite for each layer so we dont need to flatten the whole
	| stack for every brush stroke only the current layer and the  one below its cached result
	| when we brush we flatten only those layers annd push the result.
	| SimD the pixel writes and reads to do 4 at a time
	| write brush strokes on a seperate thread
	| for operations on large canvas we are slow but 
	| will speed things up when we do GPU based optimizations for now we get correctness done on the 
	| CPU

//Done but needs reviewing
# better canvas
	| use imgui image api to show the final canvas
	| map unmap to write to image every frame or when there is a change
	| do the layer color calcs on cpu

//after we got these basic implemented move to the animation editor
2. solo 
3. blending started but only mul implemented now
4. fix skipping whem  moving mouse fast.(may not be neccessary for a while)
6. output button : creates sprites in memory 
# layer moving 
	a. Simple one created can switch layer rows but cannot move to a specific
	   row can emulate this in imgui with a dummylayer inbetween each layer?

7. final output writes to disk in a mega texture with referencing info for the engine
		outputs all layers on texture with animation data

# undo / redo
//TODO(Ray):More todo as we go along
	| Have to implent all valid changes first before it can be called decent
	| record layer renames 
	| record layer blending changes
	| has to work for all layer groups / sprites active in memory
*/

//TODO(Ray):Animation Editor
/*
1. show all sprite available in real time as in sprite editor
2. can scale rotate any way 
3. attach origin points.
4. create key frames
5. looping animation or frame by frame
6. create sprite sheet animations.
*/


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
		
	3. 2d editor
		a. place bit mapped or color quads on a grid
		b. freeform placement
		c. basic animation
	*	d. use directdrawinstanced to render basic quads that share bit maps. 
			essentialy we will try to fit as many 2d quads into the same draw call.
		e. layers or groups can be flat mapped or use projection mapping as they go out into the distance to create a parralax effect
			(might be not how to do parralax rendering)
		f. need to make sure matrix works correctly ortho matrix.
		h. figure out textures with the sprite system
		j. do we need to have entities on sprites could just have the command written out by 
			something like drawsprite api save a for loop of sprites
		k. create a texture cache to ensure same texture doesnt get used twice unless intentional
	
	2D Rendering
		A. Not doing instanced drawing yet first do the quad basic draw alpha blended-
	
	Sprite Package : 
		a. a sprite while not large can still be compacted more 
		b. Should be used with instanced rendering
	4. Entities // Low priority
		a. a flexible entity system : half
		F. Start testing and pushing the ECS system with some quads/bitmaps of various Types

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

//Games will register their entry point here and initialize functions

EngineCalls :: struct{
	is_init : bool,
	init_func : proc(),
	update_func : proc(dt : f32),
}

game_bridge : [dynamic]EngineCalls
is_game_bridge_running : bool = true
set_time_seconds : f32 = 0

matrix_gpu_arena : platform.GPUArena
 
init_called : bool
window_data : WindowData
engine_init_success : bool
engine_init :: proc(dim : enginemath.f2){
	using la
	using enginemath
	using gfx
	using con;
	using platform;
	fmt.println("Initializing engine Main!");

	game_bridge = make([dynamic]EngineCalls)
	assetctx_init(&asset_ctx)
	
	window_dim := dim//enginemath.f2{1920, 1080};
   	show_cmd: i32 = 0;
   	fmt.println(ps.is_running)
  	fmt.println(ps.window.handle);
  	result : ErrorStr
   	result,window_data = spawn_window(&ps, "test window", cast(u32)window_dim.x, cast(u32)window_dim.y)
   	if len(result) == 0{
   		ps.window.dim = set_screen_mode(&ps,true)
   	}
   	window_p   := enginemath.f2{0, 0};
	   
   if !platform.PlatformInit(&ps, dim, window_p, 5) {
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
			
			desc_heap_desc: D3D12_DESCRIPTOR_HEAP_DESC;
			MAX_SRV_DESC_HEAP_COUNT: u32 = 512; // NOTE(Ray Garner): totally arbiturary number
			desc_heap_desc.NumDescriptors = MAX_SRV_DESC_HEAP_COUNT;
			desc_heap_desc.Type = .D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
			desc_heap_desc.Flags = .D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
			default_srv_desc_heap.heap = platform.create_descriptor_heap(device.device, desc_heap_desc);

			//NOTE(RAY):This must always be the first thing we do as our shaders that rely on matrix buffer expect this to be
			//the first entry in the shader resouce heap
			matrix_mem_size: u64 = (size_of(f4x4)) * u64(asset_ctx.asset_tables.max_mapped_matrices);
			matrix_gpu_arena = AllocateGPUArena(device.device, matrix_mem_size);

			set_arena_constant_buffer(device.device, &matrix_gpu_arena, default_srv_desc_heap.count, default_srv_desc_heap.heap);
			default_srv_desc_heap.count += 1;
			engine_init_success = true
		} else {
			//Could not initialize graphics device.
			fmt.println("Failed to initialize graphics...");
			assert(false);
		}
	}

	gfx.camera_system_init(20)
	editor.init_basic_viewers()
	editor.init_sprite_creator()
	init_called = true
}

engine_start :: proc(dim : enginemath.f2) {
	using la;
	using gfx;
	using con;
	using platform;
	using enginemath;

	if !engine_init_success{
		assert(false)
		return
	}

	version := imgui.get_version();
	imgui.create_context();
	imgui.style_colors_dark();

	io := imgui.get_io();

/*
	g_pd3dSrvDescHeap : ID3D12DescriptorHeap;
	imgui_desc : platform.D3D12_DESCRIPTOR_HEAP_DESC;
	imgui_desc.Type = .D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
	imgui_desc.NumDescriptors = 1;
	imgui_desc.Flags = .D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
	g_pd3dSrvDescHeap = create_descriptor_heap(device.device,imgui_desc);
	assert(g_pd3dSrvDescHeap.value != nil);
*/


	ImGui_ImplWin32_Init(ps.window.handle);

	hmdh_size : u32 = GetDescriptorHandleIncrementSize(device.device,platform.D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

	gpuhmdh := platform.GetGPUDescriptorHandleForHeapStart(default_srv_desc_heap.heap.value);
	gpugoffset : u64 = cast(u64)hmdh_size * cast(u64)default_srv_desc_heap.count
	gpuhmdh.ptr = gpuhmdh.ptr + gpugoffset

	hmdh := platform.GetCPUDescriptorHandleForHeapStart(default_srv_desc_heap.heap.value);
	offset : u64 = cast(u64)hmdh_size * cast(u64)default_srv_desc_heap.count
	hmdh.ptr = hmdh.ptr + cast(windows.SIZE_T)offset
	default_srv_desc_heap.count += 1

	ImGui_ImplDX12_Init(device.device, gfx.num_of_back_buffers,
		.DXGI_FORMAT_R8G8B8A8_UNORM, nil,
		hmdh,
		gpuhmdh);

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

	using editor
	using editor.editor_scene_views
	//when EDITOR_MODE == true{
		camera_add_viewport(editor_scene_views.main_cam_id)
		camera_add_viewport(editor_scene_views.scene_cam_id)
		camera_add_viewport(editor_scene_views.sprite_cam_id)
	//}
	
	//test_game_cam := camera_system_add_camera(rc.ot,RenderCameraProjectionType.perspective)
	//camera_add_viewport(test_game_cam)

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
	//test_model_result   := asset_load_model(&asset_ctx, "data/glTF/sponza.gltf", mesh_material);
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
	
	light_new_trans := transform_init()
	light_new_trans.p = f3{0, 0, -6};
	light_new_trans.s = f3{1, 1, 1} * 10;
	add_child_to_scene_object(&asset_ctx, rn_id, light_sphere_instance, light_new_trans);

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
	init_sprite_render_system(sprite_cam_id)
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
		show_basic_viewers()
		show_sprite_createor()		
		//play pause
		if !imgui.begin("Controls"){
			
		}
		if imgui.button("pause/resume"){
			is_game_bridge_running = !is_game_bridge_running

		}
		if is_game_bridge_running{
			ps.time.delta_seconds = set_time_seconds
		}	

		imgui.end()

		editor.show_entity_debug(true)
		editor.show_sprite_debug(true)
		editor.show_sprite_editor(true)
		show_log(&should_show_log)
// 			if is_game_bridge_running{
			set_time_seconds = 0

			for call in &game_bridge{
				if call.init_func != nil && call.is_init == false{
					call.init_func()
					call.is_init = true
				}

				if call.update_func != nil{
					call.update_func(ps.time.delta_seconds)
				}
			}
			update_ecs_entities()			
//			}

			/*
			if !init_frame_done{
 			game.init()
 			init_frame_done = true
			}else{
 			game.update(ps.time.delta_seconds)
			}
			*/

//Entity Logic Execute

//editor
		imgui.render();

		update_scene(&asset_ctx, &test_scene);

//Prepare Rendering 
		issue_render_commands(&render, &light_render, &test_scene, &asset_ctx,get_camera(main_cam_id).matrix_id /*rc_matrix_id*/, projection_matrix_id);
		//            issue_light_render_commands(&light_render,&test_scene,&asset_ctx,rc_matrix_id,projection_matrix_id);            

//Execute Rendering
		//Deffered rendering
		//if editor mode or using off screen render targets
		for cam,i in get_cameras().buffer{
			//override camera matrix
			//cam_mat := cam.projection_matrix_id
			//GBUFFER Pass
			setup_gbuffer_pass(&render, matrix_buffer, &matrix_quad_buffer);
			if i > 0{
				execute_gbuffer_pass(gbuffer_pass,1);
			}else if i == 0{
				execute_gbuffer_pass(gbuffer_pass);
			}

			//lighting pass
			setup_lighting_pass1(&light_render, matrix_buffer, &matrix_quad_buffer);
			execute_lighting_pass1(light_accum_pass1);

			//lighting pass
			setup_lighting_pass2(&light_render, matrix_buffer, &matrix_quad_buffer);
			execute_lighting_pass2(light_accum_pass2);

			vp := cam.viewport
			if i != int(sprite_cam_id){
				//composite pass
				setup_composite_pass(vp);
				execute_composite_pass(composite_pass,vp);
			}else if i == int(sprite_cam_id){
				setup_custom_pass(&custom_render, matrix_buffer, &matrix_quad_buffer,vp)
				execute_custom_pass(custom_pass,vp)
			}
			
			
			//override render target
			execute_frame();
		}

/*
		//final pass for game camera if game mode
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
*/

        setup_imgui_pass();
        execute_imgui_pass(default_srv_desc_heap.heap.value);

		//Basic forward rendering
		//Basic pass
		//	        setup_perspective_projection_pass(&render,matrix_buffer,&matrix_quad_buffer);
		//	        execute_perspective_projection_pass(pers_proj_pass);
		
		//in editor mode we render to a render target for viewport
		//in game build mode we render final to full screen back buffer
		execute_frame()

		present_frame()
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
