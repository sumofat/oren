 package graphics

import "core:fmt"
import "core:c"
import "core:mem"
import "core:math"

import platform "../platform"
import fmj "../fmj"
import la "core:math/linalg"

import windows "core:sys/windows"
import window32 "core:sys/win32"

import con "../containers";

foreign import gfx "../../library/windows/build/win32.lib"

D3D12_APPEND_ALIGNED_ELEMENT : u32 : 0xffffffff;

default_srv_desc_heap : platform.ID3D12DescriptorHeap;
depth_heap : platform.ID3D12DescriptorHeap;
depth_buffer : rawptr;/*ID3D12Resource**/;

device : RenderDevice;
default_root_sig : rawptr;

temp_queue_command_list : con.Buffer(rawptr);

graphics_command_queue : rawptr;
copy_command_queue : rawptr;
compute_command_queue : rawptr;

rtv_descriptor_heap : rawptr;
current_allocator_index : u64;            
rtv_desc_size : u64;
 
allocator_tables : platform.D12CommandAllocatorTables;
resource_ca : rawptr; //ID3D12CommandAllocator*
resource_cl : rawptr; //ID3D12GraphicsCommandList*
upload_operations : platform.UploadOperations;

fence : rawptr;
fence_event : windows.HANDLE;
fence_value : u64;

@(default_calling_convention="c")
foreign gfx
{
//    Texture2D  :: proc "c"(lt : ^Texture,heap_index : u32,tex_resource : ^platform.D12Resource,heap : rawptr) ---;
    AllocateStaticGPUArena :: proc "c"(size : u64 ) -> platform.GPUArena ---;
//    UploadBufferData :: proc "c"(g_arena : ^platform.GPUArena,data : rawptr,size : u64 ) ---;    
    SetArenaToVertexBufferView :: proc "c"(g_arena  : ^platform.GPUArena,size : u64 ,stride : u32) ---;    
    SetArenaToIndexVertexBufferView :: proc "c"(g_arena : ^platform.GPUArena,size : u64 ,format : platform.DXGI_FORMAT) ---;
    GetDescriptorHandleIncrementSize :: proc "c"(device : rawptr,DescriptorHeapType :  platform.D3D12_DESCRIPTOR_HEAP_TYPE) -> c.uint  ---;
    CreateShaderResourceView :: proc "c"(device : rawptr,resource : rawptr,desc : ^platform.D3D12_SHADER_RESOURCE_VIEW_DESC,handle : platform.D3D12_CPU_DESCRIPTOR_HANDLE) ---;
    Map :: proc "c"(resource : rawptr,sub_resource : u32,range : ^platform.D3D12_RANGE,data : ^rawptr) ---;
    AllocateGPUArena :: proc "c"(size : u64)-> platform.GPUArena ---;
    CreateCommittedResource :: proc "c"(device : rawptr,
					pHeapProperties : ^platform.D3D12_HEAP_PROPERTIES,
					HeapFlags : platform.D3D12_HEAP_FLAGS,
					pDesc : ^platform.D3D12_RESOURCE_DESC,
					InitialResourceState : platform.D3D12_RESOURCE_STATES,
					pOptimizedClearValue : ^platform.D3D12_CLEAR_VALUE,
					resource : rawptr)-> windows.HRESULT ---;
    CreateCommandQueue :: proc "c"(device : rawptr,type : platform.D3D12_COMMAND_LIST_TYPE) -> rawptr ---;
    CreateSwapChain :: proc "c"( hWnd : windows.HWND,commandQueue : rawptr,width : u32, height : u32,bufferCount :  u32) -> rawptr ---;
    UpdateRenderTargetViews :: proc "c"(device : rawptr,swapChain : rawptr, descriptorHeap : rawptr) ---;
    ResetCommandAllocator :: proc "c"(a  : rawptr/*ID3D12CommandAllocator* */) -> windows.LONG ---;
    ResetCommandList :: proc "c"(l : rawptr/*^ID3D12GraphicsCommandList*/,/*ID3D12CommandAllocator **/pAllocator : rawptr,/*ID3D12PipelineState **/ pInitialState : rawptr) -> windows.LONG ---;
    Init :: proc "c" (window : ^window32.Hwnd,dim : la.Vector2) -> CreateDeviceResult ---;
    D3D12UpdateSubresources :: proc "c"(pCmdList : rawptr/*^ID3D12GraphicsCommandList*/, pDestinationResource : rawptr /*^ID3D12Resource*/, pIntermediate : rawptr/*^ID3D12Resource*/,FirstSubresource : u32,NumSubresources : u32,RequiredSize : u64,pSrcData  : ^platform.D3D12_SUBRESOURCE_DATA) -> windows.HRESULT  ---;
    CloseCommandList :: proc "c"(/*ID3D12CommandList**/ list : rawptr) ---;
    ExecuteCommandLists :: proc "c"(queue : rawptr,/*ID3D12CommandList* takes array of lists*/ lists : rawptr,list_count : u32) ---;
    Signal :: proc "c"(/*ID3D12CommandQueue**/ commandQueue : rawptr, /*ID3D12Fence**/ fence : rawptr,fenceValue : ^u64) -> u64  ---;
    WaitForFenceValue :: proc "c"(/*ID3D12Fence**/ fence : rawptr,fenceValue : u64,fenceEvent : windows.HANDLE ,duration : f64) ---;
    CheckFeatureSupport :: proc "c"(device : rawptr,Feature : platform.D3D12_FEATURE,pFeatureSupportData : rawptr,FeatureSupportDataSize : windows.UINT) -> bool ---;
    GetIntermediateSize :: proc "c"(resource : rawptr/*ID3D12Resource* */,firstSubResource : u32,NumSubresources : u32) -> u64  ---;
    CreateDepthStencilView :: proc "c"(device : rawptr,pResource : rawptr/*ID3D12Resource **/,pDesc : ^platform.D3D12_DEPTH_STENCIL_VIEW_DESC,DestDescriptor : platform.D3D12_CPU_DESCRIPTOR_HANDLE) ---;
    CreatRootSignature :: proc "c"(params : ^platform.D3D12_ROOT_PARAMETER1,param_count : int,samplers : ^platform.D3D12_STATIC_SAMPLER_DESC,sampler_count : int,flags : platform.D3D12_ROOT_SIGNATURE_FLAGS) -> rawptr /*    ID3D12RootSignature* */ ---;
    TransitionResource :: proc "c"(cle : platform.D12CommandListEntry,resource : /* ID3D12Resource*  */ rawptr,from : platform.D3D12_RESOURCE_STATES,to : platform.D3D12_RESOURCE_STATES) ---;
    ClearRenderTargetView :: proc "c"(list : rawptr,RenderTargetView : platform.D3D12_CPU_DESCRIPTOR_HANDLE,ColorRGBA : [4]f32,NumRects : windows.UINT,pRects : ^platform.D3D12_RECT)---;
    ClearDepthStencilView :: proc "c"(list : rawptr/*ID3D12GraphicsCommandList**/,DepthStencilView : platform.D3D12_CPU_DESCRIPTOR_HANDLE ,ClearFlags : platform.D3D12_CLEAR_FLAGS,Depth : f32,Stencil : u8,NumRects : u32,pRects : ^platform.D3D12_RECT) ---;
    OMSetRenderTargets :: proc "c"(list : rawptr/*ID3D12GraphicsCommandList* */,NumRenderTargetDescriptors : u32 ,pRenderTargetDescriptors : ^platform.D3D12_CPU_DESCRIPTOR_HANDLE,RTsSingleHandleToDescriptorRange : bool,pDepthStencilDescriptor : ^platform.D3D12_CPU_DESCRIPTOR_HANDLE) ---;
    RSSetViewports :: proc "c"(list : rawptr,NumViewports : u32,pViewports : ^platform.D3D12_VIEWPORT ) ---;
    SetGraphicsRootSignature :: proc "c"(list : rawptr/*^platform.ID3D12GraphicsCommandList*/,pRootSignature : rawptr/*^ID3D12RootSignature*/)---;
    RSSetScissorRects :: proc "c"(list : rawptr,NumRects : u32,pRects : ^platform.D3D12_RECT) ---;
    IASetPrimitiveTopology :: proc "c"(list : rawptr,PrimitiveTopology : platform.D3D12_PRIMITIVE_TOPOLOGY) ---;
    DrawInstanced :: proc "c"(list : rawptr,VertexCountPerInstance : u32,InstanceCount : u32,StartVertexLocation : u32,StartInstanceLocation : u32) ---;
    IASetIndexBuffer :: proc "c"(list : rawptr,pView : ^platform.D3D12_INDEX_BUFFER_VIEW) ---;
    DrawIndexedInstanced :: proc "c"(list : rawptr/*ID3D12GraphicsCommandList**/,IndexCountPerInstance : u32,InstanceCount : u32,StartIndexLocation : u32,BaseVertexLocation : i32,StartInstanceLocation : u32)---;
    IASetVertexBuffers :: proc "c"(list : rawptr,StartSlot : u32,NumViews : u32,pViews : ^platform.D3D12_VERTEX_BUFFER_VIEW) ---;
    SetPipelineState :: proc "c"(list : rawptr,pPipelineState : /*^ID3D12PipelineState*/rawptr) ---;        
}

CommandAllocToListResult :: struct
{
    list : platform.D12CommandListEntry,
    index : u64,
    found : bool,
}

CreateDeviceResult :: struct
{
    is_init : bool,
    compatible_level : c.int,
    dim : fmj.f2,
    device : RenderDevice
};

RenderDevice :: struct
{
    device : rawptr,
    device_context : rawptr,
    max_render_targets : u32,//GRAPHICS_MAX_RENDER_TARGETS;
    profile : platform.CompatibilityProfile, 
    //TODO(Ray):- newArgumentEncoderWithArguments:
    //Creates a new argument encoder for a specific array of arguments.
    //Required.
    //ArgumentBuffersTier argument_buffers_support;
    //This limit is only applicable to samplers that have their supportArgumentBuffers property set to YES.
    max_argument_buffer_sampler_count : u32,
};

RenderCameraProjectionType :: enum
{
    perspective,
    orthographic,
    screen_space
};

RenderCamera :: struct
{
    ot : Transform,//perspective and ortho only
    matrix : f4x4,
    projection_matrix : f4x4,
    spot_light_shadow_projection_matrix : f4x4,
    point_light_shadow_projection_matrix  : f4x4,
    projection_type : RenderCameraProjectionType,
    size : f32,//ortho only
    fov : f32,//perspective only
    near_far_planes : f2,
    matrix_id : u64,
    projection_matrix_id : u64,
};

GPUMeshResource :: struct
{
    vertex_buff : platform.GPUArena ,
    normal_buff : platform.GPUArena ,
    uv_buff : platform.GPUArena ,
    tangent_buff : platform.GPUArena ,
    element_buff : platform.GPUArena ,
    hash_key : u64 ,
    buffer_range : f2 ,
    index_id : u32,
};

RenderGeometry :: struct
{
    buffer_id_range : f2,
    count : u64,
    offset: u64,
    index_id: u64,
    index_count : u64,
    is_indexed : bool,
    base_color : f4
};

RenderShader :: struct
{
    vs_file_name : cstring,
    fs_file_name : cstring,
    vs_blob : rawptr,//ID3DBlob*,
    fs_blob : rawptr,//ID3DBlob*
};

CreateRenderShader :: proc(vs_file_name : cstring,fs_file_name : cstring) -> RenderShader
{
    result : RenderShader;
    result.vs_file_name = vs_file_name;
    result.fs_file_name = fs_file_name;
    platform.CompileShader_(vs_file_name,&result.vs_blob,"vs_5_1");
    platform.CompileShader_(fs_file_name,&result.fs_blob,"ps_5_1");
    return result;
}

RenderState :: struct
{
    command_buffer : [dynamic]RenderCommand,//FMJStretchBuffer,
};

SwapChain :: struct
{
    value : rawptr,
}

CommandQueue :: struct
{
    value : rawptr,
}

create_command_queue :: proc(device : RenderDevice,type : platform.D3D12_COMMAND_LIST_TYPE) -> rawptr
{
    return CreateCommandQueue(device.device,type);
}

create_default_pipeline_state_stream_desc :: proc(root_sig : rawptr,input_layout : ^platform.D3D12_INPUT_ELEMENT_DESC,input_layout_count : int,vs_blob :  rawptr/*ID3DBlob**/,fs_blob : rawptr /*ID3DBlob* */,depth_enable := false) -> platform.PipelineStateStream
{
    using platform;
    ppss : PipelineStateStream; 
    
    ppss.root_sig = PipelineStateSubObject(rawptr){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_ROOT_SIGNATURE, value = root_sig};

    input_layout_desc : D3D12_INPUT_LAYOUT_DESC = {input_layout,cast(u32)input_layout_count};

    ppss.input_layout  = PipelineStateSubObject(D3D12_INPUT_LAYOUT_DESC){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_INPUT_LAYOUT, value = input_layout_desc};

    ppss.topology_type = PipelineStateSubObject(platform.D3D12_PRIMITIVE_TOPOLOGY_TYPE){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_PRIMITIVE_TOPOLOGY,value = .D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE};

    ppss.vertex_shader = PipelineStateSubObject(D3D12_SHADER_BYTECODE){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_VS,value = GetShaderByteCode(vs_blob)};
    ppss.fragment_shader = PipelineStateSubObject(D3D12_SHADER_BYTECODE){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_PS,value = GetShaderByteCode(fs_blob)};    

    ppss.dsv_format = PipelineStateSubObject(DXGI_FORMAT){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_DEPTH_STENCIL_FORMAT , value = .DXGI_FORMAT_D32_FLOAT};

    rtv_formats : D3D12_RT_FORMAT_ARRAY;
    rtv_formats.NumRenderTargets = 1;
    rtv_formats.RTFormats[0] = .DXGI_FORMAT_R8G8B8A8_UNORM;
    ppss.rtv_formats = PipelineStateSubObject(D3D12_RT_FORMAT_ARRAY){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_RENDER_TARGET_FORMATS, value = rtv_formats};
    
    //    CD3DX12_RASTERIZER_DESC raster_desc = CD3DX12_RASTERIZER_DESC(d);
    raster_desc := DEFAULT_D3D12_RASTERIZER_DESC;
    raster_desc.FrontCounterClockwise = true;
    ppss.rasterizer_state = PipelineStateSubObject(D3D12_RASTERIZER_DESC){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_RASTERIZER, value = raster_desc};
    /*
    raster_desc : D3D12_RASTERIZER_DESC;
    raster_desc.FillMode = .D3D12_FILL_MODE_SOLID;
    raster_desc.CullMode = .D3D12_CULL_MODE_NONE;
    raster_desc.FrontCounterClockwise = false;
    raster_desc.DepthBias = 0;
    raster_desc.DepthBiasClamp = 0.0;
    raster_desc.SlopeScaledDepthBias = 0.0;
    raster_desc.DepthClipEnable = false;
    raster_desc.MultisampleEnable = true;
    raster_desc.AntialiasedLineEnable = false;
    raster_desc.ForcedSampleCount = 0;
    raster_desc.ConservativeRaster = .D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF;        
    fmt.println(raster_desc); 
*/
    //    ppss.rasterizer_state : PipelineStateSubObject(D3D12_RASTERIZER_DESC);
//    ppss.rasterizer_state.type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_RASTERIZER;
//    ppss.rasterizer_state.value = raster_desc;

    fmt.println("size of raster desc : ",size_of(ppss.rasterizer_state));     
  //  ppss.rasterizer_state.value.FillMode = .D3D12_FILL_MODE_SOLID;
//    ppss.rasterizer_state.value.CullMode = .D3D12_CULL_MODE_BACK;
    
//    fmt.println(ppss.rasterizer_state.value);     

    //NOTE(Ray):Compiler error here
//    bdx : D3D12_BLEND_DESC = { AlphaToCoverageEnable = false, IndependentBlendEnable = false, RenderTarget = DEFAULT_D3D12_RENDER_TARGET_BLEND_DESC};

    bdx : D3D12_BLEND_DESC;
    bdx.AlphaToCoverageEnable = false;
    bdx.IndependentBlendEnable = false;
    bdx.RenderTarget = DEFAULT_D3D12_RENDER_TARGET_BLEND_DESC;
    bdx.RenderTarget[0].BlendEnable = false;
    bdx.RenderTarget[0].SrcBlend = .D3D12_BLEND_SRC_ALPHA;
    bdx.RenderTarget[0].DestBlend = .D3D12_BLEND_INV_SRC_ALPHA;

    ppss.blend_state = PipelineStateSubObject(D3D12_BLEND_DESC){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_BLEND, value = bdx};

    dss1 : D3D12_DEPTH_STENCIL_DESC1 = DEFAULT_D3D12_DEPTH_STENCIL_DESC1;
//    dss1.DepthEnable = true;
    
    //    dss1.DepthEnable = depth_enable;
/*
    dss1 : D3D12_DEPTH_STENCIL_DESC1;
    dss1.DepthEnable = true;
    dss1.DepthWriteMask = .D3D12_DEPTH_WRITE_MASK_ALL;
    dss1.DepthFunc = .D3D12_COMPARISON_FUNC_LESS;
    dss1.StencilEnable = false;
    dss1.StencilReadMask = DEFAULT_D3D12_STENCIL_READ_MASK;
    dss1.StencilWriteMask = DEFAULT_D3D12_STENCIL_WRITE_MASK;

    dsd : D3D12_DEPTH_STENCILOP_DESC;
    dsd.StencilFailOp = .D3D12_STENCIL_OP_KEEP;
    dsd.StencilDepthFailOp = .D3D12_STENCIL_OP_KEEP;
    dsd.StencilPassOp = .D3D12_STENCIL_OP_KEEP;
    dsd.StencilFunc = .D3D12_COMPARISON_FUNC_ALWAYS;

    dss1.FrontFace = dsd;
    dss1.BackFace = dsd;
*/    

//    dss1.DepthEnable = depth_enable;
    
    ppss.depth_stencil_state = PipelineStateSubObject(D3D12_DEPTH_STENCIL_DESC1){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_DEPTH_STENCIL1, value = dss1};

    return ppss;        
}

create_pipeline_state :: proc(pss : platform.PipelineStateStream)->rawptr	  /*ID3D12PipelineState**/  
{
    result : rawptr;
    using platform;
    psslocal_copy := pss;
    pipeline_state_stream_desc : D3D12_PIPELINE_STATE_STREAM_DESC = {size_of(PipelineStateStream), &psslocal_copy};
    
    result = CreatePipelineState(pipeline_state_stream_desc);
    return result;
}

//TODO(Ray):Ensure thread safety
asset_material_store :: proc(ctx : ^AssetContext,name : string,material : RenderMaterial)
{
    //u64 result = ctx->asset_tables->material_count;
//    material.id = ctx->asset_tables->material_count;
//    fmj_anycache_add_to_free_list(&ctx->asset_tables->materials,(void*)&ctx->asset_tables->material_count,&material);
    //    ++ctx->asset_tables->material_count;
    ctx.asset_tables.materials[name] = material;
    ctx.asset_tables.material_count = ctx.asset_tables.material_count + 1;
}

set_arena_constant_buffer :: proc(device : rawptr,arena :^platform.GPUArena,heap_index : u32,heap : platform.ID3D12DescriptorHeap)
{
    srvDesc2 := platform.D3D12_SHADER_RESOURCE_VIEW_DESC{};
    //    srvDesc2.Shader4ComponentMapping = platform.D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING(0,1,2,3);
    srvDesc2.Shader4ComponentMapping = platform.D3D12_ENCODE_SHADER_4_COMPONENT_MAPPING(0,1,2,3);            
    srvDesc2.Format = platform.DXGI_FORMAT.DXGI_FORMAT_R32_TYPELESS;
    srvDesc2.ViewDimension = platform.D3D12_SRV_DIMENSION.D3D12_SRV_DIMENSION_BUFFER;//D3D12_SRV_DIMENSION_TEXTURE2D;
    srvDesc2.Buffer.Buffer.Flags = platform.D3D12_BUFFER_SRV_FLAGS.D3D12_BUFFER_SRV_FLAG_RAW;
    srvDesc2.Buffer.Buffer.FirstElement = 0;
    ele_num : u32 = cast(u32)arena.size / size_of(f32);
    srvDesc2.Buffer.Buffer.NumElements = ele_num;
        
    hmdh_size : u32 = GetDescriptorHandleIncrementSize(device,platform.D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

    hmdh := platform.GetCPUDescriptorHandleForHeapStart(heap.value);
    offset : u64 = cast(u64)hmdh_size * cast(u64)heap_index;
    hmdh.ptr = hmdh.ptr + cast(windows.SIZE_T)offset;

    CreateShaderResourceView(device,arena.resource, &srvDesc2, hmdh);            
}

add_material :: proc(ps : ^platform.PlatformState,stream : platform.PipelineStateStream,name : string)
{
    new_material : RenderMaterial;
    new_material.pipeline_state = create_pipeline_state(stream);
    new_material.name = name;
    new_material.viewport_rect = la.Vector4{0,0,ps.window.dim.x,ps.window.dim.y};
    new_material.scissor_rect = la.Vector4{0,0,max(f32),max(f32)};
    asset_material_store(&asset_ctx,name,new_material);
}

create_default_depth_stencil_buffer :: proc(dim : f2)
{
    using platform;
    
    hp : D3D12_HEAP_PROPERTIES =  
        {
		.D3D12_HEAP_TYPE_UPLOAD,
		.D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
		.D3D12_MEMORY_POOL_UNKNOWN,
            0,
            0
        };


    sd : DXGI_SAMPLE_DESC =
	{
	    1,0
	};
    
    res_d : D3D12_RESOURCE_DESC  = {
	.D3D12_RESOURCE_DIMENSION_TEXTURE2D,
        0,
  	cast(u64)dim.x,
	cast(u32)dim.y,
	1,0,
	.DXGI_FORMAT_D32_FLOAT,
	sd,
	.D3D12_TEXTURE_LAYOUT_UNKNOWN,
	.D3D12_RESOURCE_FLAG_ALLOW_DEPTH_STENCIL,
    };
    
    width : u32 = max(1, cast(u32)dim.x);
    height : u32 = max(1, cast(u32)dim.y);
    optimizedClearValue : D3D12_CLEAR_VALUE;
    optimizedClearValue.Format = .DXGI_FORMAT_D32_FLOAT;
    optimizedClearValue.clear_value.DepthStencil = { 1.0, 0 };
    
    CreateCommittedResource(device.device,
			    &hp,
			    //        &CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_DEFAULT),
			    .D3D12_HEAP_FLAG_NONE,
			    &res_d,			    
//        &CD3DX12_RESOURCE_DESC::Tex2D(DXGI_FORMAT_D32_FLOAT, width, height,
//                                      1, 0, 1, 0, D3D12_RESOURCE_FLAG_ALLOW_DEPTH_STENCIL),
        .D3D12_RESOURCE_STATE_DEPTH_WRITE,
        &optimizedClearValue,
			    //        IID_PPV_ARGS(&depth_buffer));
        &depth_buffer);			    
    
    // Update the depth-stencil view.
    dsv : platform.D3D12_DEPTH_STENCIL_VIEW_DESC;
    dsv.Format = .DXGI_FORMAT_D32_FLOAT;
    dsv.ViewDimension = .D3D12_DSV_DIMENSION_TEXTURE2D;
    dsv.depth_stencil.Texture2D.MipSlice = 0;
    dsv.Flags = .D3D12_DSV_FLAG_NONE;
    
    CreateDepthStencilView(device.device,depth_buffer, &dsv,GetCPUDescriptorHandleForHeapStart(depth_heap.value));
}

create_default_root_sig :: proc() -> rawptr
{
    using platform;
    dsv_h_d  :     D3D12_DESCRIPTOR_HEAP_DESC;
    dsv_h_d.NumDescriptors = 1;
    dsv_h_d.Type = .D3D12_DESCRIPTOR_HEAP_TYPE_DSV;
    dsv_h_d.Flags = .D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
    depth_heap := CreateDescriptorHeap(device.device,dsv_h_d);
        
    feature_data : D3D12_FEATURE_DATA_ROOT_SIGNATURE;
    feature_data.HighestVersion = .D3D_ROOT_SIGNATURE_VERSION_1_1;
    if CheckFeatureSupport(device.device, platform.D3D12_FEATURE.D3D12_FEATURE_ROOT_SIGNATURE , &feature_data, size_of(feature_data))
    {
        feature_data.HighestVersion = .D3D_ROOT_SIGNATURE_VERSION_1_0;
    }

    // Allow input layout and deny unnecessary access to certain pipeline stages.
    root_sig_flags : platform.D3D12_ROOT_SIGNATURE_FLAGS  =
        .D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT |
        .D3D12_ROOT_SIGNATURE_FLAG_DENY_HULL_SHADER_ROOT_ACCESS |
        .D3D12_ROOT_SIGNATURE_FLAG_DENY_DOMAIN_SHADER_ROOT_ACCESS |
        .D3D12_ROOT_SIGNATURE_FLAG_DENY_GEOMETRY_SHADER_ROOT_ACCESS;
    //|D3D12_ROOT_SIGNATURE_FLAG_DENY_PIXEL_SHADER_ROOT_ACCESS;
    
    // create a descriptor range (descriptor table) and fill it out
    // this is a range of descriptors inside a descriptor heap
    descriptorTableRanges : [1]platform.D3D12_DESCRIPTOR_RANGE1;
    
    descriptorTableRanges[0].RangeType = .D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
    descriptorTableRanges[0].NumDescriptors = max(u32); 
    descriptorTableRanges[0].BaseShaderRegister = 0; 
    descriptorTableRanges[0].RegisterSpace = 0;
    descriptorTableRanges[0].OffsetInDescriptorsFromTableStart = platform.D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND; 
    descriptorTableRanges[0].Flags = .D3D12_DESCRIPTOR_RANGE_FLAG_DESCRIPTORS_VOLATILE;

    // create a descriptor table
    descriptorTable : D3D12_ROOT_DESCRIPTOR_TABLE1;
    descriptorTable.NumDescriptorRanges = len(descriptorTableRanges);
    descriptorTable.pDescriptorRanges = &descriptorTableRanges[0];

    rc_1 : platform.D3D12_ROOT_CONSTANTS;
    rc_1.RegisterSpace = 0;
    rc_1.ShaderRegister = 0;
    rc_1.Num32BitValues = 16;
    
    rc_2 : D3D12_ROOT_CONSTANTS;
    rc_2.RegisterSpace = 0;
    rc_2.ShaderRegister = 1;
    rc_2.Num32BitValues = 16;
    
    rc_3 : D3D12_ROOT_CONSTANTS;
    rc_3.RegisterSpace = 0;
    rc_3.ShaderRegister = 2;
    rc_3.Num32BitValues = 4;
    
    rc_4 : D3D12_ROOT_CONSTANTS;
    rc_4.RegisterSpace = 0;
    rc_4.ShaderRegister = 0;
    rc_4.Num32BitValues = 4;

    root_params : [5]D3D12_ROOT_PARAMETER1;
    root_params[0].ParameterType = .D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
    root_params[0].ShaderVisibility = .D3D12_SHADER_VISIBILITY_VERTEX;
    root_params[0].root_parameter1_union.Constants = rc_1;

    // fill out the parameter for our descriptor table. Remember it's a good idea to sort parameters by frequency of change. Our constant
    // buffer will be changed multiple times per frame, while our descriptor table will not be changed at all.
    root_params[1].ParameterType = .D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
    root_params[1].root_parameter1_union.DescriptorTable = descriptorTable;
    root_params[1].ShaderVisibility = .D3D12_SHADER_VISIBILITY_ALL;
   
    root_params[2].ParameterType = .D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
    root_params[2].ShaderVisibility = .D3D12_SHADER_VISIBILITY_VERTEX;
    root_params[2].root_parameter1_union.Constants = rc_2;
    
    root_params[3].ParameterType = .D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
    root_params[3].ShaderVisibility = .D3D12_SHADER_VISIBILITY_VERTEX;
    root_params[3].root_parameter1_union.Constants = rc_3;
    
    root_params[4].ParameterType = .D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
    root_params[4].ShaderVisibility = .D3D12_SHADER_VISIBILITY_PIXEL;
    root_params[4].root_parameter1_union.Constants = rc_4;

    vs : D3D12_STATIC_SAMPLER_DESC;
    vs.Filter = .D3D12_FILTER_MIN_MAG_MIP_POINT;
    vs.AddressU = .D3D12_TEXTURE_ADDRESS_MODE_WRAP;
    vs.AddressV = .D3D12_TEXTURE_ADDRESS_MODE_WRAP;
    vs.AddressW = .D3D12_TEXTURE_ADDRESS_MODE_WRAP;
    vs.MipLODBias = 0.0;
    vs.MaxAnisotropy = 1;
    vs.ComparisonFunc = .D3D12_COMPARISON_FUNC_ALWAYS;
    vs.MinLOD = 0;
    vs.MaxLOD = D3D12_FLOAT32_MAX;
    vs.ShaderRegister = 1;
    vs.RegisterSpace = 0;
    vs.ShaderVisibility = .D3D12_SHADER_VISIBILITY_VERTEX;

    tex_static_samplers : [2]D3D12_STATIC_SAMPLER_DESC ;
    tex_static_samplers[0] = vs;

    ss : D3D12_STATIC_SAMPLER_DESC;
    ss.Filter = .D3D12_FILTER_MIN_MAG_MIP_POINT;
    ss.AddressU = .D3D12_TEXTURE_ADDRESS_MODE_WRAP;
    ss.AddressV = .D3D12_TEXTURE_ADDRESS_MODE_WRAP;
    ss.AddressW = .D3D12_TEXTURE_ADDRESS_MODE_WRAP;
    ss.MipLODBias = 0.0;
    ss.MaxAnisotropy = 1;
    ss.ComparisonFunc = .D3D12_COMPARISON_FUNC_ALWAYS;
    ss.MinLOD = 0;
    ss.MaxLOD = D3D12_FLOAT32_MAX;
    ss.ShaderRegister = 0;
    ss.RegisterSpace = 0;
    ss.ShaderVisibility = .D3D12_SHADER_VISIBILITY_PIXEL;
    
    tex_static_samplers[1] = ss;

    return CreatRootSignature(mem.raw_slice_data(root_params[:]),len(root_params),mem.raw_slice_data(tex_static_samplers[:]),2,root_sig_flags);
}

init :: proc(ps : ^platform.PlatformState) -> RenderState
{
    using platform;
    result : RenderState;

    ////////////////////////////////
    num_of_back_buffers := 2;
    
    graphics_command_queue = create_command_queue(device,.D3D12_COMMAND_LIST_TYPE_DIRECT);
    copy_command_queue = create_command_queue(device,.D3D12_COMMAND_LIST_TYPE_DIRECT);
    compute_command_queue = create_command_queue(device,.D3D12_COMMAND_LIST_TYPE_DIRECT);
    
    desc : D3D12_DESCRIPTOR_HEAP_DESC;
    desc.NumDescriptors = cast(u32)num_of_back_buffers;
    desc.Type = .D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    rtv_descriptor_heap := platform.CreateDescriptorHeap(device.device, desc);

    swap_chain := CreateSwapChain(cast(windows.HWND)ps.window.handle,graphics_command_queue,cast(u32)ps.window.dim.x, cast(u32)ps.window.dim.y, cast(u32)num_of_back_buffers);

    rtv_desc_size := GetDescriptorHandleIncrementSize(device.device,.D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    UpdateRenderTargetViews(device.device,swap_chain,rtv_descriptor_heap);
        
    fence = CreateFence(device.device);
    fence_event = CreateEventHandle();
    
    //////////////////////////////////

    
    result.command_buffer = make([dynamic]RenderCommand,0,1);
    default_root_sig = create_default_root_sig();//platform.CreateDefaultRootSig();
//    platform.CreateDefaultDepthStencilBuffer(ps.window.dim);
    create_default_depth_stencil_buffer(ps.window.dim);

    using fmj;
/*    
    input_layout :  [?]D3D12_INPUT_ELEMENT_DESC = {
        D3D12_INPUT_ELEMENT_DESC{ "POSITION", 0, .DXGI_FORMAT_R32G32B32_FLOAT,    0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        D3D12_INPUT_ELEMENT_DESC{ "COLOR"   , 0, .DXGI_FORMAT_R32G32B32A32_FLOAT, 0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        D3D12_INPUT_ELEMENT_DESC{ "TEXCOORD", 0, .DXGI_FORMAT_R32G32_FLOAT,       0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
    };
*/

    input_layout :=  [?]D3D12_INPUT_ELEMENT_DESC{
        { "POSITION", 0, .DXGI_FORMAT_R32G32B32_FLOAT,    0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "COLOR"   , 0, .DXGI_FORMAT_R32G32B32A32_FLOAT, 0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "TEXCOORD", 0, .DXGI_FORMAT_R32G32_FLOAT,       0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
    };

    fmt.println("sizeofinputlayout",size_of(input_layout));
    fmt.println("sizeofinputlayout elemenet: ",size_of(input_layout[0]));    
    input_layout_mesh : []D3D12_INPUT_ELEMENT_DESC = {
        { "POSITION", 0, .DXGI_FORMAT_R32G32B32_FLOAT,    0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "NORMAL"  , 0, .DXGI_FORMAT_R32G32B32_FLOAT,    1, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },        
//        { "COLOR"   , 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 1, D3D12_APPEND_ALIGNED_ELEMENT, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "TEXCOORD", 0, .DXGI_FORMAT_R32G32_FLOAT,       2, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
    };
    
    input_layout_pn_mesh : []D3D12_INPUT_ELEMENT_DESC = {
        { "POSITION", 0, .DXGI_FORMAT_R32G32B32_FLOAT,    0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "NORMAL"  , 0, .DXGI_FORMAT_R32G32B32_FLOAT,    1, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },        
    };
    
    input_layout_vu_mesh : []D3D12_INPUT_ELEMENT_DESC = {
        { "POSITION", 0, .DXGI_FORMAT_R32G32B32_FLOAT,    0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "TEXCOORD", 0, .DXGI_FORMAT_R32G32_FLOAT,       1, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
    };

    input_layout_count := len(input_layout);
    input_layout_count_mesh := len(input_layout_mesh);
    input_layout_vu_count_mesh := len(input_layout_vu_mesh);
    input_layout_pn_count_mesh := len(input_layout_pn_mesh);
    fmt.println("input layout count : ",input_layout_count);
    // Create a root/shader signature.

    vs_file_name : cstring = "vs_test.hlsl";
    vs_mesh_vu_name : cstring = "vs_vu.hlsl";
    vs_mesh_file_name : cstring = "vs_test_mesh.hlsl";
    vs_pn_file_name : cstring = "vs_pn.hlsl";
    
    fs_file_name : cstring = "ps_test.hlsl";
    fs_color_file_name : cstring = "fs_color.hlsl";
    
    rs := CreateRenderShader(vs_file_name,fs_file_name);
    mesh_rs := CreateRenderShader(vs_mesh_file_name,fs_file_name);
    mesh_vu_rs := CreateRenderShader(vs_mesh_vu_name,fs_file_name);
    rs_color := CreateRenderShader(vs_file_name,fs_color_file_name);
    mesh_pn_color := CreateRenderShader(vs_pn_file_name,fs_color_file_name);

//basic
    base_stream :  platform.PipelineStateStream =
	create_default_pipeline_state_stream_desc(default_root_sig,&input_layout[0],input_layout_count,rs.vs_blob,rs.fs_blob);

    add_material(ps,base_stream,"base");

    //mesh
    mesh_stream :  platform.PipelineStateStream =
	create_default_pipeline_state_stream_desc(default_root_sig,&input_layout_mesh[0],input_layout_count_mesh,mesh_rs.vs_blob,mesh_rs.fs_blob);

    add_material(ps,mesh_stream,"mesh");

        /*    

    PipelineStateStream color_ppss = D12RendererCode::CreateDefaultPipelineStateStreamDesc(input_layout,input_layout_count,rs.vs_blob,rs_color.fs_blob);
    ID3D12PipelineState* color_pipeline_state = D12RendererCode::CreatePipelineState(color_ppss);
    
    PipelineStateStream color_ppss_mesh = D12RendererCode::CreateDefaultPipelineStateStreamDesc(input_layout_mesh,input_layout_count_mesh,mesh_rs.vs_blob,mesh_rs.fs_blob,true);
    ID3D12PipelineState* color_pipeline_state_mesh = D12RendererCode::CreatePipelineState(color_ppss_mesh);

    PipelineStateStream vu_ppss_mesh = D12RendererCode::CreateDefaultPipelineStateStreamDesc(input_layout_vu_mesh,input_layout_vu_count_mesh,mesh_vu_rs.vs_blob,mesh_vu_rs.fs_blob,true);
    ID3D12PipelineState* vu_pipeline_state_mesh = D12RendererCode::CreatePipelineState(vu_ppss_mesh);        

    PipelineStateStream pn_ppss_mesh = D12RendererCode::CreateDefaultPipelineStateStreamDesc(input_layout_pn_mesh,input_layout_pn_count_mesh,mesh_pn_color.vs_blob,mesh_pn_color.fs_blob,true);
    ID3D12PipelineState* pn_pipeline_state_mesh = D12RendererCode::CreatePipelineState(pn_ppss_mesh);        
    
    FMJRenderMaterial base_render_material = {0};
    base_render_material.pipeline_state = (void*)pipeline_state;
    base_render_material.viewport_rect = f4_create(0,0,ps->window.dim.x,ps->window.dim.y);
    base_render_material.scissor_rect = f4_create(0,0,LONG_MAX,LONG_MAX);
    fmj_asset_material_add(&asset_ctx,base_render_material);

    FMJRenderMaterial color_render_material = base_render_material;
    color_render_material.pipeline_state = (void*)color_pipeline_state;
    color_render_material.viewport_rect = f4_create(0,0,ps->window.dim.x,ps->window.dim.y);
    color_render_material.scissor_rect = f4_create(0,0,LONG_MAX,LONG_MAX);    
    fmj_asset_material_add(&asset_ctx,color_render_material);

    FMJRenderMaterial color_render_material_mesh = color_render_material;
    color_render_material_mesh.pipeline_state = (void*)color_pipeline_state_mesh;
    color_render_material_mesh.viewport_rect = f4_create(0,0,ps->window.dim.x,ps->window.dim.y);
    color_render_material_mesh.scissor_rect = f4_create(0,0,LONG_MAX,LONG_MAX);    
    fmj_asset_material_add(&asset_ctx,color_render_material_mesh);

    FMJRenderMaterial vu_render_material_mesh = color_render_material;
    vu_render_material_mesh.pipeline_state = (void*)vu_pipeline_state_mesh;
    vu_render_material_mesh.viewport_rect = f4_create(0,0,ps->window.dim.x,ps->window.dim.y);
    vu_render_material_mesh.scissor_rect = f4_create(0,0,LONG_MAX,LONG_MAX);    
    fmj_asset_material_add(&asset_ctx,vu_render_material_mesh);

    FMJRenderMaterial pn_render_material_mesh = color_render_material;
    pn_render_material_mesh.pipeline_state = (void*)pn_pipeline_state_mesh;
    pn_render_material_mesh.viewport_rect = f4_create(0,0,ps->window.dim.x,ps->window.dim.y);
    pn_render_material_mesh.scissor_rect = f4_create(0,0,LONG_MAX,LONG_MAX);    
    fmj_asset_material_add(&asset_ctx,pn_render_material_mesh);

*/    
    return result;
}

add_free_command_allocator :: proc(type : platform.D3D12_COMMAND_LIST_TYPE) -> ^platform.D12CommandAllocatorEntry
{
    using con;
    entry : platform.D12CommandAllocatorEntry;
    entry.allocator = platform.CreateCommandAllocator(device.device, type);

    assert(entry.allocator != nil);

    entry.used_list_indexes = buf_init(1,u64);
    entry.fence_value = 0;
//    entry.thread_id = fmj_thread_get_thread_id();
    entry.type = type;

    entry.index = current_allocator_index;
    current_allocator_index += 1;
    
    key : platform.D12CommandAllocatorKey = {cast(u64)cast(uintptr)entry.allocator,entry.thread_id};
    //TODO(Ray):Why is the key parameter backwards here?
        
    //    fmj_anycache_add_to_free_list(&allocator_tables.fl_ca,&key,&entry);
    con.anycache_add_to_free_list(&allocator_tables.fl_ca,key,entry);
//        D12CommandAllocatorEntry* result = (D12CommandAllocatorEntry*)AnythingCacheCode::GetThing(&allocator_tables.fl_ca, &key);
    result : ^platform.D12CommandAllocatorEntry = con.anycache_get_ptr(&allocator_tables.fl_ca, key);
//    assert(result != nil);
    return  result;
}

get_free_command_allocator_entry :: proc(list_type : platform.D3D12_COMMAND_LIST_TYPE) -> ^platform.D12CommandAllocatorEntry
{
    using con;
    result : ^platform.D12CommandAllocatorEntry;
    //Forget the free list we will access the table directly and get the first free
    //remove and make a inflight allocator table.
    //This does not work with free lists due to the fact taht the top element might always be busy
    //in some cases causing the infinite allocation of command allocators.
    //result = GetFirstFreeWithPredicate(D12CommandAllocatorEntry,allocator_tables.fl_ca,GetCAPredicateDIRECT);
    table := get_table(list_type);
            
    if buf_len(table^) <= 0
    {
        result = nil;
    }
    else
    {
        // NOTE(Ray Garner): We assume if we get a free one you WILL use it.
        //otherwise we will need to do some other bookkeeping.
        //result = *YoyoPeekVectorElementPtr(D12CommandAllocatorEntry*,table);
	//        result = *(D12CommandAllocatorEntry**)fmj_stretch_buffer_get_(table,table->fixed.count - 1);
        result := buf_ptr(table,buf_len(table^) - 1)^;	
        if !platform.IsFenceComplete(fence,result.fence_value)
        {
            result = nil;
        }
        else
        {
            buf_pop(table);
        }
    }
    
    if result != nil
    {
        result = add_free_command_allocator(list_type);
    }
    assert(result != nil);
    return result;
}

texture_2d :: proc(lt : ^Texture,heap_index : u32,tex_resource : ^platform.D12Resource,heap : rawptr/*ID3D12DescriptorHeap* */)
{
    using platform;
    free_ca : ^platform.D12CommandAllocatorEntry = get_free_command_allocator_entry(platform.D3D12_COMMAND_LIST_TYPE.D3D12_COMMAND_LIST_TYPE_COPY);    
    resource_ca = free_ca.allocator;
        
    if !is_resource_cl_recording
    {
        ResetCommandAllocator(resource_ca);
	ResetCommandList(resource_cl,resource_ca,nil);
        is_resource_cl_recording = true;
    }
        
    hp : D3D12_HEAP_PROPERTIES =  
        {
            .D3D12_HEAP_TYPE_UPLOAD,
            .D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
            .D3D12_MEMORY_POOL_UNKNOWN,
            0,
            0
        };

    sd : DXGI_SAMPLE_DESC =
	{
	    1,0
	};

    req_size := GetIntermediateSize( tex_resource.state, 0, 1);            
    res_d : D3D12_RESOURCE_DESC  =  
        {
            .D3D12_RESOURCE_DIMENSION_BUFFER,
            0,
            req_size,
            1,
            1,
            1,
            .DXGI_FORMAT_UNKNOWN,
            sd,
            .D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
            .D3D12_RESOURCE_FLAG_NONE,
        };
    
    subresourceData : D3D12_SUBRESOURCE_DATA;
    subresourceData.pData = lt.texels;

    // TODO(Ray Garner): Handle minimum size for alignment.
    //This wont work for a smaller texture im pretty sure.
    subresourceData.RowPitch = cast(int)(cast(u32)lt.dim.x * lt.bytes_per_pixel);
    subresourceData.SlicePitch = subresourceData.RowPitch;

    // Create a temporary (intermediate) resource for uploading the subresources

    uop  : UploadOp;
    
    intermediate_resource : rawptr/*ID3D12Resource**/ ;
    hr : windows.HRESULT = CreateCommittedResource(
	device.device,
            &hp,
            .D3D12_HEAP_FLAG_NONE,
            &res_d,
            .D3D12_RESOURCE_STATE_GENERIC_READ,
        nil,
            &uop.temp_arena.resource);
        
//    uop.temp_arena.resource.SetName(L"TEMP_UPLOAD_TEXTURE");
//    ASSERT(SUCCEEDED(hr));

    hr = D3D12UpdateSubresources(resource_cl,tex_resource.state, uop.temp_arena.resource,0, 0, 1, &subresourceData);        

    CheckFeatureSupport(device.device, platform.D3D12_FEATURE.D3D12_FEATURE_FORMAT_SUPPORT,&tex_resource.format_support,size_of(platform.D3D12_FEATURE.D3D12_FEATURE_FORMAT_SUPPORT));
        
    lt.state = tex_resource.state;
    ticket_mutex_begin(&upload_operations.ticket_mutex);
    upload_operations.current_op_id += 1;
    k  : UploadOpKey = {uop.id};
    con.anycache_add_to_free_list(&upload_operations.table_cache,k,uop);

    // NOTE(Ray Garner): Implement this.
    //if(upload_ops.anythings.count > UPLOAD_OP_THRESHOLD)
    {
        if is_resource_cl_recording
        {
            CloseCommandList(resource_cl);
            is_resource_cl_recording = false;
        }
        command_lists : []rawptr = {
            resource_cl
        };
	
        //copy_command_queue->ExecuteCommandLists(_countof(command_lists), command_lists);
	ExecuteCommandLists(copy_command_queue,mem.raw_slice_data(command_lists[:]),cast(u32)len(command_lists));
        upload_operations.fence_value = Signal(copy_command_queue, upload_operations.fence, &upload_operations.fence_value);

        WaitForFenceValue(upload_operations.fence, upload_operations.fence_value, upload_operations.fence_event,math.F32_MAX);            

        //If we have gotten here we remove the temmp transient resource. and remove them from the cache
        for i := 0;i < cast(int)con.buf_len(upload_operations.table_cache.anythings);i += 1
        {
            finished_uop : ^UploadOp = con.buf_ptr(&upload_operations.table_cache.anythings,cast(u64)i);
            // NOTE(Ray Garner): Upload should always be a copy operation and so we cant/dont need to 
            //call discard resource.
                
            //finished_uop->temp_arena.resource->Release();
            k_ :UploadOpKey  = {finished_uop.id};
            con.anycache_remove_free_list(&upload_operations.table_cache,k_);
        }
        con.anycache_reset(&upload_operations.table_cache);
    }
    ticket_mutex_end(&upload_operations.ticket_mutex);
}

upload_buffer_data :: proc(g_arena : ^platform.GPUArena,data : rawptr,size : u64)
{
    using platform;
    free_ca : ^platform.D12CommandAllocatorEntry = get_free_command_allocator_entry(platform.D3D12_COMMAND_LIST_TYPE.D3D12_COMMAND_LIST_TYPE_COPY);
    resource_ca = free_ca.allocator;
        
    if !is_resource_cl_recording
    {
        ResetCommandAllocator(resource_ca);
	ResetCommandList(resource_cl,resource_ca,nil);
        is_resource_cl_recording = true;
    }
        
    hp : D3D12_HEAP_PROPERTIES =  
        {
            .D3D12_HEAP_TYPE_UPLOAD,
            .D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
            .D3D12_MEMORY_POOL_UNKNOWN,
            0,
            0
        };
        
    sample_d : DXGI_SAMPLE_DESC  =  
        {
            1,
            0
        };
        
    res_d : D3D12_RESOURCE_DESC  =  
        {
            .D3D12_RESOURCE_DIMENSION_BUFFER,
            0,
            size,
            1,
            1,
            1,
            .DXGI_FORMAT_UNKNOWN,
            sample_d,
            .D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
            .D3D12_RESOURCE_FLAG_NONE,
        };
        
    uop : UploadOp;
    uop.arena = g_arena^;
        
    hr : windows.HRESULT = CreateCommittedResource(
	device.device,
        &hp,
        .D3D12_HEAP_FLAG_NONE,
        &res_d,
        .D3D12_RESOURCE_STATE_GENERIC_READ,
        nil,
        &uop.temp_arena.resource);
        
//    uop.temp_arena.resource->SetName(L"TEMP_UPLOAD_BUFFER");
        
//    ASSERT(SUCCEEDED(hr));
        
    subresourceData : D3D12_SUBRESOURCE_DATA;
    subresourceData.pData = data;
    subresourceData.RowPitch = cast(int)size;
    subresourceData.SlicePitch = subresourceData.RowPitch;
        
    hr = D3D12UpdateSubresources(resource_cl,g_arena.resource, uop.temp_arena.resource,0, 0, 1, &subresourceData);
    // NOTE(Ray Garner): We will batch as many texture ops into one command list as possible 
    //and only after we have reached a signifigant amout flush the commands.
    //and do a final check at the end of the frame to flush any that were not flushed earlier.
    //meaning we batch as many as possible per frame but never wait long than one frame to batch.
        
    ticket_mutex_begin(&upload_operations.ticket_mutex);
    uop.id = upload_operations.current_op_id;
    upload_operations.current_op_id += 1;
    k : UploadOpKey = {uop.id};
    //AnythingCacheCode::AddThingFL(&upload_operations.table_cache,&k,&uop);
    con.anycache_add_to_free_list(&upload_operations.table_cache,k,uop);
    //if(upload_ops.anythings.count > UPLOAD_OP_THRESHOLD)
    {
        if is_resource_cl_recording
        {
            CloseCommandList(resource_cl);
            is_resource_cl_recording = false;
        }
	
        command_lists : []rawptr = {
            resource_cl
        };
	
        //copy_command_queue->ExecuteCommandLists(_countof(command_lists), command_lists);
	ExecuteCommandLists(copy_command_queue,mem.raw_slice_data(command_lists[:]),cast(u32)len(command_lists));

        upload_operations.fence_value = Signal(copy_command_queue, upload_operations.fence, &upload_operations.fence_value);
            
        WaitForFenceValue(upload_operations.fence, upload_operations.fence_value, upload_operations.fence_event,math.F32_MAX);

        //If we have gotten here we remove the temmp transient resource. and remove them from the cache
        for i := 0;i < cast(int)con.buf_len(upload_operations.table_cache.anythings);i += 1
        {
            finished_uop : ^UploadOp = con.buf_ptr(&upload_operations.table_cache.anythings,cast(u64)i);
            // NOTE(Ray Garner): Upload should always be a copy operation and so we cant/dont need to 
            //call discard resource.
                
            //finished_uop->temp_arena.resource->Release();
            k_ :UploadOpKey  = {finished_uop.id};
            con.anycache_remove_free_list(&upload_operations.table_cache,k_);
        }
        con.anycache_reset(&upload_operations.table_cache);
    }
    ticket_mutex_end(&upload_operations.ticket_mutex);
}

dx12_init :: proc(device : RenderDevice)
{
    using con;
    using platform;
    allocator_tables.free_allocator_table_direct = buf_init(1,^D12CommandAllocatorEntry);
    allocator_tables.free_allocator_table_copy = buf_init(1,^D12CommandAllocatorEntry);
    allocator_tables.free_allocator_table_compute = buf_init(1,^D12CommandAllocatorEntry);
        
    allocator_tables.free_allocators = buf_init(1, D12CommandAllocatorEntry);
    allocator_tables.command_lists = buf_init(1, D12CommandListEntry);
    allocator_tables.allocator_to_list_table = buf_init(1, D12CommandAlloctorToCommandListKeyEntry);
    temp_queue_command_list = buf_init(1, rawptr);

    allocator_tables.fl_ca = con.anycache_init(D12CommandAllocatorKey,D12CommandAllocatorEntry,true);
    
    //Resource bookkeeping
    resource_ca = CreateCommandAllocator(device.device,.D3D12_COMMAND_LIST_TYPE_COPY);
        
    resource_cl = 
        CreateCommandList(device.device,resource_ca,.D3D12_COMMAND_LIST_TYPE_COPY);
        
    upload_operations.table_cache = anycache_init(UploadOpKey,UploadOp,true);
        
    upload_operations.ticket_mutex = {};
    upload_operations.current_op_id = 1;
    upload_operations.fence_value = 0;
    upload_operations.fence = CreateFence(device.device);
    upload_operations.fence_event = CreateEventHandle();
}

get_table :: proc(type : platform.D3D12_COMMAND_LIST_TYPE) -> ^con.Buffer(^platform.D12CommandAllocatorEntry)
{
    #partial switch type
    {
	case .D3D12_COMMAND_LIST_TYPE_DIRECT :
           return &allocator_tables.free_allocator_table_direct;		
 	case .D3D12_COMMAND_LIST_TYPE_COPY :
           return &allocator_tables.free_allocator_table_copy;
	case .D3D12_COMMAND_LIST_TYPE_COMPUTE :
           return &allocator_tables.free_allocator_table_compute;
	case :
	   return nil;
    }
}

is_resource_cl_recording : bool;
resouce_cl : rawptr;//CommandList

CheckReuseCommandAllocators :: proc()
{
    using con;
    buf_clear(&allocator_tables.free_allocator_table_direct);
    buf_clear(&allocator_tables.free_allocator_table_compute);
    buf_clear(&allocator_tables.free_allocator_table_copy);                
    for i := 0;i < cast(int)buf_len(allocator_tables.fl_ca.anythings);i+=1
    {
        entry : ^platform.D12CommandAllocatorEntry = buf_ptr(&allocator_tables.fl_ca.anythings,cast(u64)i);
        //Check the fence values
        if platform.IsFenceComplete(fence,entry.fence_value)
        {
            table := get_table(entry.type);
            //if one put them on the free table for reuse.
            buf_push(table,entry);
        }
    }
}

get_cpu_handle_srv :: proc(device : RenderDevice,heap : rawptr,heap_index : u32) -> platform.D3D12_CPU_DESCRIPTOR_HANDLE
{
    using platform;
    result : platform.D3D12_CPU_DESCRIPTOR_HANDLE;

    hmdh_size : u32 = GetDescriptorHandleIncrementSize(device.device,platform.D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);    
    hmdh := platform.GetCPUDescriptorHandleForHeapStart(heap);
    offset : u64 = cast(u64)hmdh_size * cast(u64)heap_index;
    hmdh.ptr = hmdh.ptr + cast(windows.SIZE_T)offset;
    return result;    
}

get_first_associated_list :: proc(allocator : ^platform.D12CommandAllocatorEntry) -> CommandAllocToListResult
{
    using con;
    using platform;
    result : CommandAllocToListResult;
    found : bool = false;
    //Run through all the list that are associated with an allocator check for first available list
    for i := 0; i < cast(int)buf_len(allocator_tables.allocator_to_list_table); i+=1
    {
        entry : ^D12CommandAlloctorToCommandListKeyEntry = buf_ptr(&allocator_tables.allocator_to_list_table,cast(u64)i);
        if allocator.index == entry.command_list_index
        {
            e : ^D12CommandListEntry = buf_ptr(&allocator_tables.command_lists, entry.command_list_index);
            assert(e != nil);
            if e.is_encoding != false
            {
                result.list = e^;
                //Since at this point this allocator should have all command list associated with it finished processing we can just grab the first command list.
                //and use it.
                result.index = entry.command_list_index;
                found = true;
            }
            break;
        }
    }
    result.found = found;
    //TODO(Ray):Create some validation feedback here that can be removed at compile time. 
    return result;
}
    
//render encoder
get_associated_command_list :: proc(ca : ^platform.D12CommandAllocatorEntry)-> platform.D12CommandListEntry 
{
    using platform;
    using con;
    listandindex : CommandAllocToListResult  = get_first_associated_list(ca);
    command_list_entry : D12CommandListEntry  = listandindex.list;
    cl_index : u64  = listandindex.index;
    if listandindex.found == false
    {
        command_list_entry.list = CreateCommandList(device.device, ca.allocator, ca.type);
        command_list_entry.is_encoding = true;
        command_list_entry.index = buf_len(allocator_tables.command_lists);
        command_list_entry.temp_resources = buf_init(1,rawptr);
	
        cl_index = buf_push(&allocator_tables.command_lists,command_list_entry);
        a_t_l_e  : D12CommandAlloctorToCommandListKeyEntry;
        a_t_l_e.command_allocator_index = ca.index;
        a_t_l_e.command_list_index = cl_index;
        buf_push(&allocator_tables.allocator_to_list_table,a_t_l_e);
    }
    buf_push(&ca.used_list_indexes, cl_index);
    return command_list_entry;
}
    
end_command_list_encoding_and_execute :: proc(ca : ^platform.D12CommandAllocatorEntry,cl : platform.D12CommandListEntry)
{
    using platform;
    using con;
    //Render encoder end encoding
    index : u64 = cl.index;
    le : ^D12CommandListEntry =buf_ptr(&allocator_tables.command_lists, index);
    CloseCommandList(le.list);
    le.is_encoding = false;
        
    commandLists : []rawptr = {
        cl.list
    };
        
    for i := 0; i < cast(int)buf_len(ca.used_list_indexes); i+= 1
    {
        index_ : u64 = buf_get(&ca.used_list_indexes,cast(u64)i);//*((u64*)ca.used_list_indexes.fixed.base + i);
        cle : ^D12CommandListEntry = buf_ptr(&allocator_tables.command_lists,index_);
        buf_push(&temp_queue_command_list, cle.list);
    }
        
//    ID3D12CommandList* const* temp = (ID3D12CommandList * const*)temp_queue_command_list.fixed.base;
    temp : rawptr = mem.raw_slice_data(temp_queue_command_list.buffer[:]);
    ExecuteCommandLists(graphics_command_queue,temp,cast(u32)buf_len(temp_queue_command_list));

    //    HRESULT removed_reason = device.GetDeviceRemovedReason();
//    DWORD e = GetLastError();
        
    buf_clear(&temp_queue_command_list);
    buf_clear(&ca.used_list_indexes);
}

execute_frame :: proc()
{
    using platform;
    using con;
    ticket_mutex_begin(&upload_operations.ticket_mutex);
    current_backbuffer_index := GetCurrentBackBufferIndex();

    if is_resource_cl_recording == true
    {
	CloseCommandList(resource_cl);
        is_resource_cl_recording = false;
    }
    
    dsv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = GetCPUDescriptorHandleForHeapStart(depth_heap.value);
    rtv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE  = get_cpu_handle_srv(device,rtv_descriptor_heap,current_backbuffer_index);

    //D12Present the current framebuffer
    //Commandbuffer
    //GetFreeCommandAllocatorEntry(D3D12_COMMAND_LIST_TYPE_DIRECT);
    allocator_entry : ^D12CommandAllocatorEntry = get_free_command_allocator_entry(.D3D12_COMMAND_LIST_TYPE_DIRECT);

    command_list  : D12CommandListEntry = get_associated_command_list(allocator_entry);

    //Graphics
    back_buffer  :/* ID3D12Resource**/ rawptr = GetCurrentBackBuffer();
        
    fc : bool = platform.IsFenceComplete(fence,allocator_entry.fence_value);
        
    assert(fc == true);
//    allocator_entry.allocator.Reset();
    ResetCommandAllocator(allocator_entry.allocator);        
    //    command_list.list.Reset(allocator_entry.allocator, nullptr);
    ResetCommandList(command_list.list,allocator_entry.allocator,nil);
        
    // Clear the render target.
    TransitionResource(command_list,back_buffer,.D3D12_RESOURCE_STATE_PRESENT,.D3D12_RESOURCE_STATE_RENDER_TARGET);
        
    clearColor : [4]f32 = { 0.4, 0.6, 0.9,1.0};
        
//    command_list.list.ClearRenderTargetView(rtv, clearColor, 0, nullptr);
    ClearRenderTargetView(command_list.list,rtv_cpu_handle,clearColor,0,nil);
//    command_list.list.ClearDepthStencilView(dsv_cpu_handle, D3D12_CLEAR_FLAG_DEPTH, 1.0f, 0, 0, nullptr);
    ClearDepthStencilView(command_list.list,dsv_cpu_handle,.D3D12_CLEAR_FLAG_DEPTH,1.0,0,0,nil);
        
    //finish up
    end_command_list_encoding_and_execute(allocator_entry,command_list);
    //insert signal in queue to so we know when we have executed up to this point. 
    //which in this case is up to the command clear and tranition back to present transition 
    //for back buffer.
    allocator_entry.fence_value = Signal(graphics_command_queue, fence, &fence_value);
        
    WaitForFenceValue(fence, allocator_entry.fence_value, fence_event,max(f64));

    //D12Rendering
    current_ae : ^D12CommandAllocatorEntry;
    current_cl : D12CommandListEntry;
    
    //    at : rawptr = render_com_buf.arena.base;
    //    for i := 0;i < cast(int)buf_len(render_com_buf); i += 1
    for com in render_commands.buffer
    {
        //D12CommandHeader* header = (D12CommandHeader^)at;
	//        command_type : CommandType  = header->type;
	//        at = (uint8_t*)at + sizeof(D12CommandHeader);
	switch t in com
	{

	    case D12CommandStartCommandList :

            current_ae := get_free_command_allocator_entry(.D3D12_COMMAND_LIST_TYPE_DIRECT);
            
            current_cl := get_associated_command_list(current_ae);
            fcgeo : bool  = platform.IsFenceComplete(fence,current_ae.fence_value);
            assert(fcgeo == false);

	    ResetCommandAllocator(current_ae.allocator);	    
            ResetCommandList(current_cl.list,current_ae.allocator,nil);
	    
            OMSetRenderTargets(current_cl.list,1, &rtv_cpu_handle, false, &dsv_cpu_handle);

            continue;
	    
	    case D12CommandEndCommmandList :
            // NOTE(Ray Garner): For now we do this here but we need to do something else  setting render targets.
            
            //End D12 Renderering
            end_command_list_encoding_and_execute(current_ae,current_cl);
            current_ae.fence_value = Signal(graphics_command_queue, fence, &fence_value);
            // NOTE(Ray Garner): // TODO(Ray Garner): If there are dependencies from the last command list we need to enter a waitforfence value
            //so that we can finish executing this command list before and have the result ready for the next one.
            //If not we dont need to worry about this.
            
            //wait for the gpu to execute up until this point before we procede this is the allocators..
            //current fence value which we got when we signaled. 
            //the fence value that we give to each allocator is based on the fence value for the queue.
            WaitForFenceValue(fence, current_ae.fence_value, fence_event,max(f64));
            buf_clear(&current_ae.used_list_indexes);
            continue;
	    case D12CommandBasicDraw :
	    command := com.(D12CommandBasicDraw);	    
            IASetPrimitiveTopology(current_cl.list,command.topology);
            DrawInstanced(current_cl.list,command.count, 1, command.vertex_offset, 0);
            continue;
	    
	    case D12CommandIndexedDraw :
	    command := com.(D12CommandIndexedDraw);
            IASetIndexBuffer(current_cl.list,&command.index_buffer_view);
            // NOTE(Ray Garner): // TODO(Ray Garner): Get the heaps
            //that match with the pipeline state and root sig
            IASetPrimitiveTopology(current_cl.list,command.topology);
            DrawIndexedInstanced(current_cl.list,command.index_count,1,command.index_offset,0,0);
            continue;
	    
	    case D12CommandSetVertexBuffer :
	    command := com.(D12CommandSetVertexBuffer);
            IASetVertexBuffers(current_cl.list,command.slot, 1, &command.buffer_view);                
            continue;                	    
	    case D12CommandViewport :
	    command := com.(D12CommandViewport);
            new_viewport : D3D12_VIEWPORT = {0,0,command.viewport.z, command.viewport.w,0,1};
	    RSSetViewports(current_cl.list,1,&new_viewport);

            continue;	    
	    case D12CommandRootSignature :
	    command := com.(D12CommandRootSignature);	    
            SetGraphicsRootSignature(current_cl.list,command.root_sig);
            continue;
	    
	    case D12CommandPipelineState :
	    command := com.(D12CommandPipelineState);	    
            assert(command.pipeline_state != nil);
            SetPipelineState(current_cl.list,command.pipeline_state);
            continue;	    
	    case D12CommandScissorRect :
	    command := com.(D12CommandScissorRect);	    
            RSSetScissorRects(current_cl.list,1, &command.rect);
            continue;	    
	    case D12CommandGraphicsRootDescTable :
        command := com.(D12CommandGraphicsRootDescTable);   
                
            descriptorHeaps : []rawptr  = { command->heap };
            SetDescriptorHeaps(current_cl.list,1, descriptorHeaps);
            cSetGraphicsRootDescriptorTable(urrent_cl.list,command.index, command.gpu_handle);
            continue;	

	    case D12CommandGraphicsRoot32BitConstant :
        command := com.(D12CommandGraphicsRootDescTable);   
                
            SetGraphicsRoot32BitConstants(current_cl.list,com->index, command.num_values, command.gpuptr, command.offset);
            continue;	    
	    case D12RenderTargets :
	    
	    case : 

    }
    

}

