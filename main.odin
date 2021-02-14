package main

import "core:fmt"
import "core:c"
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
        window32.CW_USEDEFAULT, window32.CW_USEDEFAULT, 640, 480,
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
    window_dim := f2{1024,1024};
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
	device : platform.RenderDevice;
	
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
	//scene
	scenes := make(map[string]Scene);
	defer delete(scenes);
	
	scene := scenes["test"];
	
	test_scene := scene_init("test");
	rn_id := scene_add_so(&asset_ctx,&test_scene.buffer,f3{0,0,0},QUATERNION_IDENTITY,f3{1,1,1},"test_so");

	root_node := buf_chk_out(&asset_ctx.scene_objects,rn_id,SceneObject);	

	root_t := transform_init();
	root_node.transform = root_t;
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
	default_srv_desc_heap := create_descriptor_heap(device,desc_heap_desc);

	def_r := quaternion_angle_axis(degrees(cast(f32)0.0),f3{0,0,1});	

	top_right_screen_xy := f2{ps.window.dim.x,ps.window.dim.y};
	bottom_left_xy := f2{0,0};

	rc : RenderCamera;
	rc_ui : RenderCamera;
	
	max_screen_p := screen_to_world(rc.projection_matrix,rc.matrix,ps.window.dim,top_right_screen_xy,0);
	lower_screen_p := screen_to_world(rc.projection_matrix,rc.matrix,ps.window.dim,bottom_left_xy,0);

	material := asset_ctx.asset_tables.materials["base"];

	track_model_result := asset_load_model(&asset_ctx,"data/Box.glb",cast(u32)material.id);	
//    FMJAssetModelLoadResult track_model_result = fmj_asset_load_model_from_glb_2(&asset_ctx,"../data/models/track.glb",track_material.id);
//    FMJAssetModelLoadResult kart_model_result = fmj_asset_load_model_from_glb_2(&asset_ctx,"../data/models/kart.glb",kart_material.id);        
	
	/*
//game object setup 
    
    //FMJAssetModel test_model = test_model_result.model;
    //fmj_asset_upload_model(&asset_tables,&asset_ctx,&duck_model_result.model);

    u64 track_instance_id = fmj_asset_create_model_instance(&asset_ctx,&track_model_result);
    u64 kart_instance_id = fmj_asset_create_model_instance(&asset_ctx,&kart_model_result);    

    FMJ3DTrans track_trans;
    fmj_3dtrans_init(&track_trans);
    track_trans.p = f3_create(0,0,0);
    track_trans.r = f3_axis_angle(f3_create(0,0,1),0);
    
    FMJ3DTrans kart_trans;
    fmj_3dtrans_init(&kart_trans);
    kart_trans.p = f3_create(0,0.4f,-1);    
    quaternion start_r = kart_trans.r;
//    AddModelToSceneObjectAsChild(&asset_ctx,root_node_id,kart_instance_id,kart_trans);
    
    FMJ3DTrans duck_trans;
    fmj_3dtrans_init(&duck_trans);
    duck_trans.p = f3_create(-10,0,0);

    fmj_3dtrans_init(&duck_trans);
    duck_trans.p = f3_create(10,0,0);

    fmj_3dtrans_init(&duck_trans);
    duck_trans.p = f3_create(0,8,0);
    
    track_so = fmj_stretch_buffer_check_out(FMJSceneObject,&asset_ctx.scene_objects,track_instance_id);
    track_so->name = fmj_string_create("track so",asset_ctx.perm_mem);
    track_so->data = (u32*)go_type_kart;        

    FMJSceneObject* kart_so = fmj_stretch_buffer_check_out(FMJSceneObject,&asset_ctx.scene_objects,kart_instance_id);
    kart_so->name = fmj_string_create("kart so",asset_ctx.perm_mem);
    
    u64 mesh_id;
    u64 kart_mesh_id;
    if(!fmj_asset_get_mesh_id_by_name("track",&asset_ctx,track_so,&mesh_id))
    {
        ASSERT(false);    
    }
    
    if(!fmj_asset_get_mesh_id_by_name("kart",&asset_ctx,kart_so,&kart_mesh_id))
    {
        ASSERT(false);    
    }
    
    FMJAssetMesh track_mesh = fmj_stretch_buffer_get(FMJAssetMesh,&asset_ctx.asset_tables->meshes,mesh_id);
    FMJAssetMesh track_collision_mesh = track_mesh;
    PhysicsShapeMesh track_physics_mesh = CreatePhysicsMeshShape(&track_mesh,physics_material);
    PhysicsCode::SetQueryFilterData((PxShape*)track_physics_mesh.state,(u32)go_type_track);    
    PhysicsCode::SetSimulationFilterData((PxShape*)track_physics_mesh.state,go_type_track,0xFF);
            
	track_collision_mesh.vertex_data   = (f32*)track_physics_mesh.tri_mesh->getVertices();
	track_collision_mesh.vertex_count  = track_physics_mesh.tri_mesh->getNbVertices() * 3;

    physx::PxTriangleMeshFlags mesh_flags = track_physics_mesh.tri_mesh->getTriangleMeshFlags();
    if(mesh_flags & PxTriangleMeshFlag::Enum::e16_BIT_INDICES)
    {
        track_collision_mesh.index_component_size = fmj_asset_index_component_size_16;
        track_collision_mesh.index_16_data = (u16*)track_physics_mesh.tri_mesh->getTriangles();
        track_collision_mesh.index16_count = track_physics_mesh.tri_mesh->getNbTriangles() * 3;
        track_collision_mesh.index_16_data_size = track_collision_mesh.index16_count * sizeof(u16);        
    }
    else
    {
        track_collision_mesh.index_component_size = fmj_asset_index_component_size_32;
        track_collision_mesh.index_32_data = (u32*)track_physics_mesh.tri_mesh->getTriangles();
        track_collision_mesh.index32_count = track_physics_mesh.tri_mesh->getNbTriangles() * 3;
        track_collision_mesh.index_32_data_size = track_collision_mesh.index32_count * sizeof(u32);                
    }

    u64 tcm_id = fmj_stretch_buffer_push(&asset_ctx.asset_tables->meshes,&track_collision_mesh);
    fmj_asset_upload_meshes(&asset_ctx,f2_create(tcm_id,tcm_id));

    track_physics_so_.name = fmj_string_create("Track Physics",asset_ctx.perm_mem);
    track_physics_so_.transform = kart_trans;
    track_physics_so_.children.buffer = fmj_stretch_buffer_init(1,sizeof(u64),8);
    track_physics_so_.m_id = track_so->m_id;
    track_physics_so_.data = 0;
    track_physics_so_.type = 1;
    track_physics_so_.primitives_range = f2_create_f(tcm_id);
    
    track_physics_id = fmj_stretch_buffer_push(&asset_ctx.scene_objects,&track_physics_so_);
    
    AddModelToSceneObjectAsChild(&asset_ctx,scene_manager.root_node_id,track_instance_id,track_physics_so_.transform);

    PhysicsShapeBox phyx_box_shape = PhysicsCode::CreateBox(f3_create(1.2f,0.2f,1.2f),physics_material);
        
    track_rbd = PhysicsCode::CreateStaticRigidbody(track_trans.p,track_physics_mesh.state);
    u64* instance_id_ptr = (u64*)track_instance_id;
    PhysicsCode::SetRigidBodyUserData(track_rbd,instance_id_ptr);
    PhysicsCode::AddActorToScene(scene, track_rbd);    
    
//end game object setup
*/
	
	
        for ps.is_running
        {
	    AddStartCommandListCommand();
	    //Get default root sig from api
	    //	    platform.AddRootSignatureCommand(D12RendererCode::root_sig);
	    rect := fmj.f4{0,0,window_dim.x,window_dim.y};	    
	    AddViewportCommand(rect);
	    //full screen rect
            AddScissorRectCommand(rect);

//	    material := asset_ctx.asset_tables.materials["base"];
            AddPipelineStateCommand(material.pipeline_state);

	    m_mat : f4x4;
	    finalmat : f4x4;
	    
	    AddGraphicsRoot32BitConstant(0,16,&m_mat,0);
	    AddGraphicsRoot32BitConstant(2,16,&finalmat,0);
	    //            tex_index = command.texture_id;
            tex_index := 0;//command.texture_id;	    
            AddGraphicsRoot32BitConstant(4,4,&tex_index,0);
//            AddGraphicsRootDescTable(1,D12RendererCode::default_srv_desc_heap,D12RendererCode::default_srv_desc_heap->GetGPUDescriptorHandleForHeapStart());	    

	    gpu_handle_default_srv_desc_heap := GetGPUDescriptorHandleForHeapStart(default_srv_desc_heap.value);
	    AddGraphicsRootDescTable(1,default_srv_desc_heap.value,gpu_handle_default_srv_desc_heap);

            slot : int = 0;
	    //            for(int j = command.geometry.buffer_id_range.x;j <= command.geometry.buffer_id_range.y;++j)
            {
		//                D3D12_VERTEX_BUFFER_VIEW bv = fmj_stretch_buffer_get(D3D12_VERTEX_BUFFER_VIEW,&asset_tables.vertex_buffers,j);
//		bv := asset_ctx.asset_tables.vertex_buffers[j];		
//AddSetVertexBufferCommand(slot++,bv);
            }
                    
//                    if(command.is_indexed)
                    {
//                        D3D12_INDEX_BUFFER_VIEW ibv = fmj_stretch_buffer_get(D3D12_INDEX_BUFFER_VIEW,&asset_tables.index_buffers,command.geometry.index_id);
//			ibv := asset_ctx.asset_tables.index_buffers[command.geometry.id];
//                        AddDrawIndexedCommand(command.geometry.index_count,command.geometry.offset,D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST,ibv);
                    }
//                    else
                    {
                        //AddDrawCommand(command.geometry.offset,command.geometry.count,D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);                        
                    }

	    
	    platform.AddEndCommandListCommand();
	    
	    platform.EndFrame();
	    platform.HandleWindowsMessages(&ps);
        }
    }

//    for ps.is_running
    {
//	fmt.println("Running a windows app!");		
    }
//    platformtest(&ps,100);

    //for ps.is_running
    {
//        if(ps->input.keyboard.keys[keys.s].down)
        {
//            ps->is_running = false;
        }
    }

    /*
    err, win := spawn_window("test",640,480 );

//time
    now : windows.LARGE_INTEGER;
    windows.QueryPerformanceFrequency(&now);
    ps.time.ticks_per_second = cast(u64)now;
    windows.QueryPerformanceCounter(&now);
    ps.time.initial_ticks = cast(u64)now;
    ps.time.prev_ticks = ps.time.initial_ticks;

//keys
    //TODO(Ray):Propery check for layouts
//    layout : HKL =  windows.LoadKeyboardLayout("00000409",0x00000001);

    SHORT  code = VkKeyScanEx('s',layout);
    keys.s = code;
    code = VkKeyScanEx('w',layout);
    keys.w = code;
    code = VkKeyScanEx('a',layout);
	keys.a = code;
	code = VkKeyScanEx('e', layout);
	keys.e = code;
	code = VkKeyScanEx('r', layout);
    keys.r = code;
    code = VkKeyScanEx('d',layout);
    keys.d = code;
    code = VkKeyScanEx('f',layout);
    keys.f = code;
    code = VkKeyScanEx('i',layout);
    keys.i = code;
    code = VkKeyScanEx('j',layout);
    keys.j = code;
    code = VkKeyScanEx('k',layout);
    keys.k = code;
    code = VkKeyScanEx('l',layout);
    keys.l = code;
    keys.f1 = VK_F1;
    keys.f2 = VK_F2;
	keys.f3 = VK_F3;

    for ;;
    {
	handle_msgs(win);
    }
*/    
}

