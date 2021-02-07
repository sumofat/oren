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
        
        for ps.is_running
        {
	    platform.AddStartCommandListCommand();
	    //Get default root sig from api
	    //	    platform.AddRootSignatureCommand(D12RendererCode::root_sig);
	    rect := fmj.f4{0,0,window_dim.x,window_dim.y};	    
	    platform.AddViewportCommand(rect);
	    //full screen rect
            platform.AddScissorRectCommand(rect);
	    //            FMJRenderMaterial material = fmj_anycache_get(FMJRenderMaterial,&asset_tables.materials,(void*)&command.material_id);
	    //            D12RendererCode::AddPipelineStateCommand((ID3D12PipelineState*)material.pipeline_state);
	    
	    /*


                    D12RendererCode::AddGraphicsRoot32BitConstant(0,16,&m_mat,0);                    
                    D12RendererCode::AddGraphicsRoot32BitConstant(2,16,&finalmat,0);
                    
                    tex_index = command.texture_id;
                    D12RendererCode::AddGraphicsRoot32BitConstant(4,4,&tex_index,0);
                    D12RendererCode::AddGraphicsRootDescTable(1,D12RendererCode::default_srv_desc_heap,D12RendererCode::default_srv_desc_heap->GetGPUDescriptorHandleForHeapStart());
 
                    int slot = 0;
                    for(int j = command.geometry.buffer_id_range.x;j <= command.geometry.buffer_id_range.y;++j)
                    {
                        D3D12_VERTEX_BUFFER_VIEW bv = fmj_stretch_buffer_get(D3D12_VERTEX_BUFFER_VIEW,&asset_tables.vertex_buffers,j);
                        D12RendererCode::AddSetVertexBufferCommand(slot++,bv);
                    }
                    
                    if(command.is_indexed)
                    {
                        D3D12_INDEX_BUFFER_VIEW ibv = fmj_stretch_buffer_get(D3D12_INDEX_BUFFER_VIEW,&asset_tables.index_buffers,command.geometry.index_id);
                        D12RendererCode::AddDrawIndexedCommand(command.geometry.index_count,command.geometry.offset,D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST,ibv);
                    }
                    else
                    {
                        D12RendererCode::AddDrawCommand(command.geometry.offset,command.geometry.count,D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);                        
                    }
*/

	    
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

