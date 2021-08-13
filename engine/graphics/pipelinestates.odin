
package graphics;
import platform "../platform"

create_gbuffer_pipeline_state_stream_desc :: proc(root_sig : rawptr,input_layout : ^platform.D3D12_INPUT_ELEMENT_DESC,input_layout_count : int,vs_blob :  rawptr/*ID3DBlob**/,fs_blob : rawptr /*ID3DBlob* */,depth_enable := false) -> platform.PipelineStateStream
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
    rtv_formats.NumRenderTargets = 3;
    rtv_formats.RTFormats[0] = .DXGI_FORMAT_R8G8B8A8_UNORM;
    rtv_formats.RTFormats[1] = .DXGI_FORMAT_R8G8B8A8_UNORM;
    rtv_formats.RTFormats[2] = .DXGI_FORMAT_R8G8B8A8_UNORM;    
    
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

    return ppss;        
}
