package main

import "core:fmt"
import "core:c"
import windows "core:sys/windows"
import window32 "core:sys/win32"

import platform "engine/platform"
import fmj "engine/fmj"
import gfx "engine/graphics"

//first test importing libs that we compile here with the foreign system.
//starting with simple C lib FMJ

//Graphics

//Get a window and some basic rendering working.
main :: proc()
{
    fmt.println("Hellope!");

    x :f32 = fmj.degrees(20);
    fmt.println(x);
    x = fmj.radians(x);
    fmt.println(x);    
    fmt.println(x);
    ps : platform.PlatformState;
    window_dim := fmj.f2{1024,1024};
    window_p := fmj.f2{0,0};
    show_cmd : i32 = 0;
//    ps.is_running  = true;

    //    testPlatformInit(&ps,100);
    //fmt.println(ps);
    fmt.println(ps.is_running);
    fmt.println(ps.window.handle);
    //    if !platformtest(&ps,window_dim,window_p)
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
	using fmj;

	//engine init
	assetctx_init(&asset_ctx);
	//scene
	scenes := make(map[string]Scene);
	defer delete(scenes);
	
	scene := scenes["test"];
	object_name := "Root Node";
	
	test := buf_init(100,Scene);

	test_scene := Scene{};
	test_scene.name = "test";
	
	test_id := buf_push(&test,test_scene);

	test_scene_result := buf_get(&test,test_id,Scene);
	test_scene_result.name = "modified_test";

	test_scene_result = buf_get(&test,test_id,Scene);	

	test_scene_result_ptr := buf_chk_out(&test,test_id,Scene);
	test_scene_result_ptr.name = "modified_test";
	
	test_scene_result = buf_get(&test,test_id,Scene);
	
	/*
//	    InitSceneBuffer(&scenes);
    u64 scene_id = CreateEmptyScene(&scenes);
    FMJScene* test_scene = fmj_stretch_buffer_check_out(FMJScene,&scenes.buffer,scene_id);
    FMJString object_name = fmj_string_create("Root Node",asset_ctx.perm_mem);
    u64 root_node_id = AddSceneObject(&asset_ctx,&test_scene->buffer,f3_create_f(0),quaternion_identity(),f3_create_f(1),object_name);
    FMJSceneObject* root_node = fmj_stretch_buffer_check_out(FMJSceneObject,&asset_ctx.scene_objects,root_node_id);
    fmj_scene_object_buffer_init(&root_node->children);
    FMJ3DTrans root_t;
    fmj_3dtrans_init(&root_t);
    root_node->transform = root_t;    
    fmj_stretch_buffer_check_in(&asset_ctx.scene_objects);

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
	
        for ps.is_running
        {
	    AddStartCommandListCommand();
	    //Get default root sig from api
	    //	    platform.AddRootSignatureCommand(D12RendererCode::root_sig);
	    rect := fmj.f4{0,0,window_dim.x,window_dim.y};	    
	    AddViewportCommand(rect);
	    //full screen rect
            AddScissorRectCommand(rect);

	    material := asset_ctx.asset_tables.materials["base"];//fmj_anycache_get(FMJRenderMaterial,&asset_tables.materials,(void*)&command.material_id);
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

