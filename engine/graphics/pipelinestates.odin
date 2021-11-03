
package graphics;
import platform "../platform"
import windows "core:sys/windows"

create_default_pipeline_state_stream_desc :: proc(root_sig : rawptr,input_layout : ^platform.D3D12_INPUT_ELEMENT_DESC,
    input_layout_count : int,vs_blob :  rawptr,fs_blob : rawptr,depth_enable :windows.BOOL= false,blend_enable :windows.BOOL= false,
    src_blend_alpha : platform.D3D12_BLEND = .D3D12_BLEND_SRC_ALPHA,dst_blend_alpha : platform.D3D12_BLEND = .D3D12_BLEND_INV_SRC_ALPHA,front_ccw : windows.BOOL = true) -> rawptr
{
    using platform;
    ppss : PipelineStateStream; 
    
    ppss.root_sig = PipelineStateSubObject(rawptr){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_ROOT_SIGNATURE, value = root_sig};

    input_layout_desc : D3D12_INPUT_LAYOUT_DESC = {input_layout,cast(u32)input_layout_count};

    ppss.input_layout  = PipelineStateSubObject(D3D12_INPUT_LAYOUT_DESC){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_INPUT_LAYOUT, value = input_layout_desc};

    ppss.topology_type = PipelineStateSubObject(platform.D3D12_PRIMITIVE_TOPOLOGY_TYPE){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_PRIMITIVE_TOPOLOGY,value = .D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE};

    ppss.vertex_shader = PipelineStateSubObject(D3D12_SHADER_BYTECODE){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_VS,value = GetShaderByteCode(vs_blob)};
    ppss.fragment_shader = PipelineStateSubObject(D3D12_SHADER_BYTECODE){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_PS,value = GetShaderByteCode(fs_blob)};    

    ppss.dsv_format = PipelineStateSubObject(DXGI_FORMAT){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_DEPTH_STENCIL_FORMAT , value = .DXGI_FORMAT_D24_UNORM_S8_UINT};//.DXGI_FORMAT_D32_FLOAT};

    rtv_formats : D3D12_RT_FORMAT_ARRAY;
    rtv_formats.NumRenderTargets = 1;
    rtv_formats.RTFormats[0] = .DXGI_FORMAT_R8G8B8A8_UNORM;
    ppss.rtv_formats = PipelineStateSubObject(D3D12_RT_FORMAT_ARRAY){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_RENDER_TARGET_FORMATS, value = rtv_formats};
    
    //    CD3DX12_RASTERIZER_DESC raster_desc = CD3DX12_RASTERIZER_DESC(d);
    raster_desc := DEFAULT_D3D12_RASTERIZER_DESC;
    raster_desc.FrontCounterClockwise = front_ccw;
    ppss.rasterizer_state = PipelineStateSubObject(D3D12_RASTERIZER_DESC){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_RASTERIZER, value = raster_desc};

    bdx : D3D12_BLEND_DESC;
    bdx.AlphaToCoverageEnable = false;
    bdx.IndependentBlendEnable = false;
    bdx.RenderTarget = DEFAULT_D3D12_RENDER_TARGET_BLEND_DESC;
    bdx.RenderTarget[0].BlendEnable = blend_enable; 
    bdx.RenderTarget[0].SrcBlend = src_blend_alpha;
    bdx.RenderTarget[0].DestBlend = dst_blend_alpha;

    ppss.blend_state = PipelineStateSubObject(D3D12_BLEND_DESC){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_BLEND, value = bdx};

    dss1 : D3D12_DEPTH_STENCIL_DESC1 = DEFAULT_D3D12_DEPTH_STENCIL_DESC1;
    dss1.DepthEnable = depth_enable
    ppss.depth_stencil_state = PipelineStateSubObject(D3D12_DEPTH_STENCIL_DESC1){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_DEPTH_STENCIL1, value = dss1};

    mesh_stream_desc : PipelineStateStreamDescriptor = {size_of(ppss),&ppss};
    pipeline_state := create_pipeline_state(mesh_stream_desc);
    assert(pipeline_state != nil);
    return pipeline_state;        
}

create_gbuffer_pipeline_state_stream_desc :: proc(root_sig : rawptr,input_layout : ^platform.D3D12_INPUT_ELEMENT_DESC,input_layout_count : int,vs_blob :  rawptr/*ID3DBlob**/,fs_blob : rawptr /*ID3DBlob* */,depth_enable := false) -> rawptr
{
    using platform;
    ppss : PipelineStateStream; 
    
    ppss.root_sig = PipelineStateSubObject(rawptr){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_ROOT_SIGNATURE, value = root_sig};

    input_layout_desc : D3D12_INPUT_LAYOUT_DESC = {input_layout,cast(u32)input_layout_count};

    ppss.input_layout  = PipelineStateSubObject(D3D12_INPUT_LAYOUT_DESC){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_INPUT_LAYOUT, value = input_layout_desc};

    ppss.topology_type = PipelineStateSubObject(platform.D3D12_PRIMITIVE_TOPOLOGY_TYPE){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_PRIMITIVE_TOPOLOGY,value = .D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE};

    ppss.vertex_shader = PipelineStateSubObject(D3D12_SHADER_BYTECODE){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_VS,value = GetShaderByteCode(vs_blob)};
    ppss.fragment_shader = PipelineStateSubObject(D3D12_SHADER_BYTECODE){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_PS,value = GetShaderByteCode(fs_blob)};    

    ppss.dsv_format = PipelineStateSubObject(DXGI_FORMAT){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_DEPTH_STENCIL_FORMAT , value = .DXGI_FORMAT_D24_UNORM_S8_UINT};//DXGI_FORMAT_D32_FLOAT};

    rtv_formats : D3D12_RT_FORMAT_ARRAY;
    rtv_formats.NumRenderTargets = 3;
    rtv_formats.RTFormats[0] = .DXGI_FORMAT_R8G8B8A8_UNORM;
    rtv_formats.RTFormats[1] = .DXGI_FORMAT_R32G32B32A32_FLOAT;
    rtv_formats.RTFormats[2] = .DXGI_FORMAT_R32G32B32A32_FLOAT;    
    
    ppss.rtv_formats = PipelineStateSubObject(D3D12_RT_FORMAT_ARRAY){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_RENDER_TARGET_FORMATS, value = rtv_formats};
    
    //    CD3DX12_RASTERIZER_DESC raster_desc = CD3DX12_RASTERIZER_DESC(d);
    raster_desc := DEFAULT_D3D12_RASTERIZER_DESC;
    raster_desc.FrontCounterClockwise = true;
    ppss.rasterizer_state = PipelineStateSubObject(D3D12_RASTERIZER_DESC){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_RASTERIZER, value = raster_desc};

    bdx : D3D12_BLEND_DESC;
    bdx.AlphaToCoverageEnable = false;
    bdx.IndependentBlendEnable = false;
    bdx.RenderTarget = DEFAULT_D3D12_RENDER_TARGET_BLEND_DESC;
    bdx.RenderTarget[0].BlendEnable = false;
    bdx.RenderTarget[0].SrcBlend = .D3D12_BLEND_SRC_ALPHA;
    bdx.RenderTarget[0].DestBlend = .D3D12_BLEND_INV_SRC_ALPHA;

    ppss.blend_state = PipelineStateSubObject(D3D12_BLEND_DESC){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_BLEND, value = bdx};

    dss1 : D3D12_DEPTH_STENCIL_DESC1 = DEFAULT_D3D12_DEPTH_STENCIL_DESC1;
    
    ppss.depth_stencil_state = PipelineStateSubObject(D3D12_DEPTH_STENCIL_DESC1){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_DEPTH_STENCIL1, value = dss1};

    mesh_stream_desc : PipelineStateStreamDescriptor = {size_of(ppss),&ppss};
    pipeline_state := create_pipeline_state(mesh_stream_desc);
    assert(pipeline_state != nil);
    return pipeline_state;        
}

create_lighting_pipeline_state_stream_desc :: proc(root_sig : rawptr,input_layout : ^platform.D3D12_INPUT_ELEMENT_DESC,input_layout_count : int,vs_blob :  rawptr/*ID3DBlob**/,fs_blob : rawptr /*ID3DBlob* */,depth_enable := false) -> (light_accum_stage_1 : rawptr,light_accum_stage_2 : rawptr)
{
    using platform;
    ppss : DefferedLighting1PipelineStateStream;
    ppss2 : PipelineStateStream;     
    
    ppss.root_sig = PipelineStateSubObject(rawptr){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_ROOT_SIGNATURE, value = root_sig};
    ppss2.root_sig = ppss.root_sig;
    
    input_layout_desc : D3D12_INPUT_LAYOUT_DESC = {input_layout,cast(u32)input_layout_count};

    //shared subobjects
    ppss.input_layout  = PipelineStateSubObject(D3D12_INPUT_LAYOUT_DESC){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_INPUT_LAYOUT, value = input_layout_desc};
    ppss.topology_type = PipelineStateSubObject(platform.D3D12_PRIMITIVE_TOPOLOGY_TYPE){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_PRIMITIVE_TOPOLOGY,value = .D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE};
    ppss.dsv_format = PipelineStateSubObject(DXGI_FORMAT){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_DEPTH_STENCIL_FORMAT , value = .DXGI_FORMAT_D24_UNORM_S8_UINT};//DXGI_FORMAT_D32_FLOAT};

    ppss.vertex_shader = PipelineStateSubObject(D3D12_SHADER_BYTECODE){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_VS,value = GetShaderByteCode(vs_blob)};

    ppss2.input_layout = ppss.input_layout;    
    ppss2.topology_type = ppss.topology_type;
    ppss2.dsv_format = ppss.dsv_format;
    ppss2.vertex_shader = ppss.vertex_shader;

    //different subobjects
    //raster state
    raster_desc := DEFAULT_D3D12_RASTERIZER_DESC;
    raster_desc.FrontCounterClockwise = true;
    raster_desc.DepthClipEnable = false;    
    raster_desc.CullMode = .D3D12_CULL_MODE_BACK;
    ppss.rasterizer_state = PipelineStateSubObject(D3D12_RASTERIZER_DESC){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_RASTERIZER, value = raster_desc};

    raster_desc.CullMode = .D3D12_CULL_MODE_FRONT;
    raster_desc.DepthClipEnable = false;
    ppss2.rasterizer_state = PipelineStateSubObject(D3D12_RASTERIZER_DESC){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_RASTERIZER, value = raster_desc};    

    //depth stencil state
    dss1 : D3D12_DEPTH_STENCIL_DESC1 = DEFAULT_D3D12_DEPTH_STENCIL_DESC1;
//    dss1.DepthWriteMask = .D3D12_DEPTH_WRITE_MASK_ZERO;
    dss1.DepthEnable = true;
    dss1.DepthFunc = .D3D12_COMPARISON_FUNC_GREATER;
    dss1.StencilEnable = true;
    depth_stencil_op_desc : D3D12_DEPTH_STENCILOP_DESC = {
        .D3D12_STENCIL_OP_KEEP,
        .D3D12_STENCIL_OP_KEEP,
        .D3D12_STENCIL_OP_DECR_SAT,
        .D3D12_COMPARISON_FUNC_ALWAYS};
    dss1.FrontFace = depth_stencil_op_desc;
//    dss1.BackFace = depth_stencil_op_desc;    
    ppss.depth_stencil_state = PipelineStateSubObject(D3D12_DEPTH_STENCIL_DESC1){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_DEPTH_STENCIL1, value = dss1};
    
    dss1.DepthFunc = .D3D12_COMPARISON_FUNC_GREATER_EQUAL;     
    depth_stencil_op_desc_stage2 : D3D12_DEPTH_STENCILOP_DESC = {
        .D3D12_STENCIL_OP_KEEP,
        .D3D12_STENCIL_OP_KEEP,
        .D3D12_STENCIL_OP_KEEP,
        .D3D12_COMPARISON_FUNC_EQUAL};
  //  dss1.FrontFace = depth_stencil_op_desc_stage2;
    dss1.BackFace  = depth_stencil_op_desc_stage2;   
    ppss2.depth_stencil_state = PipelineStateSubObject(D3D12_DEPTH_STENCIL_DESC1){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_DEPTH_STENCIL1, value = dss1};    

    //second stage only subobjects
    ppss2.fragment_shader = PipelineStateSubObject(D3D12_SHADER_BYTECODE){ type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_PS,value = GetShaderByteCode(fs_blob)};        
    rtv_formats : D3D12_RT_FORMAT_ARRAY;
    rtv_formats.NumRenderTargets = 1;
    rtv_formats.RTFormats[0] = .DXGI_FORMAT_R32G32B32A32_FLOAT;
    ppss2.rtv_formats = PipelineStateSubObject(D3D12_RT_FORMAT_ARRAY){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_RENDER_TARGET_FORMATS, value = rtv_formats};
    
    bdx : D3D12_BLEND_DESC;
    bdx.AlphaToCoverageEnable = false;
    bdx.IndependentBlendEnable = false;
    bdx.RenderTarget = DEFAULT_D3D12_RENDER_TARGET_BLEND_DESC;
    bdx.RenderTarget[0].BlendEnable = false;
    bdx.RenderTarget[0].SrcBlend = .D3D12_BLEND_SRC_ALPHA;
    bdx.RenderTarget[0].DestBlend = .D3D12_BLEND_INV_SRC_ALPHA;
    ppss2.blend_state = PipelineStateSubObject(D3D12_BLEND_DESC){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_BLEND, value = bdx};

    mesh_stream_desc : PipelineStateStreamDescriptor = {size_of(ppss),&ppss};
    pipeline_state := create_pipeline_state(mesh_stream_desc);
    assert(pipeline_state != nil);

    mesh_stream_desc2 : PipelineStateStreamDescriptor = {size_of(ppss2),&ppss2};
    pipeline_state2 := create_pipeline_state(mesh_stream_desc2);
    assert(pipeline_state2 != nil);    
    return pipeline_state,pipeline_state2;        
}


