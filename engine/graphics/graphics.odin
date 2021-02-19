 package graphics

import "core:fmt"
import "core:c"

import platform "../platform"
import fmj "../fmj"
import la "core:math/linalg"

import windows "core:sys/windows"
import window32 "core:sys/win32"

foreign import gfx "../../library/windows/build/win32.lib"

@(default_calling_convention="c")
foreign gfx
{
    Texture2D  :: proc "c"(lt : ^Texture,heap_index : u32) ---;
    AllocateStaticGPUArena :: proc "c"(size : u64 ) -> GPUArena ---;
    UploadBufferData :: proc "c"(g_arena : ^GPUArena,data : rawptr,size : u64 ) ---;    
    SetArenaToVertexBufferView :: proc "c"(g_arena  : ^GPUArena,size : u64 ,stride : u32) ---;    
    SetArenaToIndexVertexBufferView :: proc "c"(g_arena : ^GPUArena,size : u64 ,format : platform.DXGI_FORMAT) ---;        
}

asset_ctx : AssetContext;

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

BufferView :: struct #raw_union
{
    vertex_buffer_view : platform.D3D12_VERTEX_BUFFER_VIEW,
    index_buffer_view : platform.D3D12_INDEX_BUFFER_VIEW,
};

GPUArena :: struct
{
    size : u64,
    heap : rawptr,//    ID3D12Heap* 
    resource : rawptr, //    ID3D12Resource* 
    slot : u32,
    buffer_view : BufferView,    
};

GPUMeshResource :: struct
{
    vertex_buff : GPUArena ,
    normal_buff : GPUArena ,
    uv_buff : GPUArena ,
    tangent_buff : GPUArena ,
    element_buff : GPUArena ,
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


RenderCommand :: struct
{
    geometry : RenderGeometry,
    material_id : u64,
    model_matrix_id : u64,
    camera_matrix_id : u64,
    perspective_matrix_id : u64,
    
    //TODO(Ray):Create a mapping between pipeline state root sig slots..
    //and inputs from the application ie textures buffers etc..
    //for now we just throw on the simple ones we are using now. 
    texture_id : u64,
    is_indexed : bool
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

    test : PipelineRasterizerStateSubObjectTest;
    test.type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_RASTERIZER;
    test.value = raster_desc;    
//    test.value.FillMode = .D3D12_FILL_MODE_SOLID;
//    test.value.CullMode = .D3D12_CULL_MODE_BACK;
//    ppss.rasterizer_state.value = test.value;

    //NOTE(Ray):Compiler error here
//    bdx : D3D12_BLEND_DESC = { AlphaToCoverageEnable = false, IndependentBlendEnable = false, RenderTarget = DEFAULT_D3D12_RENDER_TARGET_BLEND_DESC};

    bdx : D3D12_BLEND_DESC;
    bdx.AlphaToCoverageEnable = false;
    bdx.IndependentBlendEnable = false;
    bdx.RenderTarget = DEFAULT_D3D12_RENDER_TARGET_BLEND_DESC;
    bdx.RenderTarget[0].BlendEnable = true;
    bdx.RenderTarget[0].SrcBlend = .D3D12_BLEND_SRC_ALPHA;
    bdx.RenderTarget[0].DestBlend = .D3D12_BLEND_INV_SRC_ALPHA;

    ppss.blend_state = PipelineStateSubObject(D3D12_BLEND_DESC){type = .D3D12_PIPELINE_STATE_SUBOBJECT_TYPE_BLEND, value = bdx};

    dss1 : D3D12_DEPTH_STENCIL_DESC1 = DEFAULT_D3D12_DEPTH_STENCIL_DESC1;
//    dss1.DepthEnable = depth_enable;
/*
    dss_1 : D3D12_DEPTH_STENCIL_DESC1;
    dss_1.DepthEnable = true;
    dss_1.DepthWriteMask = .D3D12_DEPTH_WRITE_MASK_ALL;
    dss_1.DepthFunc = .D3D12_COMPARISON_FUNC_LESS;
    dss_1.StencilEnable = false;
    dss_1.StencilReadMask = DEFAULT_D3D12_STENCIL_READ_MASK;
    dss_1.StencilWriteMask = DEFAULT_D3D12_STENCIL_WRITE_MASK;

    dsd : D3D12_DEPTH_STENCILOP_DESC;
    dsd.StencilFailOp = .D3D12_STENCIL_OP_KEEP;
    dsd.StencilDepthFailOp = .D3D12_STENCIL_OP_KEEP;
    dsd.StencilPassOp = .D3D12_STENCIL_OP_KEEP;
    dsd.StencilFunc = .D3D12_COMPARISON_FUNC_ALWAYS;

    dss_1.FrontFace = dsd;
    dss_1.BackFace = dsd;
*/    

//    dss_1.DepthEnable = depth_enable;
    
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


D3D12_APPEND_ALIGNED_ELEMENT : u32 : 0xffffffff;

default_root_sig : rawptr;

init :: proc(ps : ^platform.PlatformState) -> RenderState
{
    result : RenderState;
    
    result.command_buffer = make([dynamic]RenderCommand,0,1);
    default_root_sig = platform.CreateDefaultRootSig();
    platform.CreateDefaultDepthStencilBuffer(ps.window.dim);

    using platform;
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

//    input_layoutptr : ^D3D12_INPUT_ELEMENT_DESC = &input_layout[0];
//    root_sig_ptr  : ^rawptr = &default_root_sig;
//    CreateDefaultPipelineStateStreamDesc(&input_layout[0],cast(c.int)input_layout_count,rs.vs_blob,rs.fs_blob,false);    
    default_pipeline_state_stream :  platform.PipelineStateStream = create_default_pipeline_state_stream_desc(default_root_sig,&input_layout[0],input_layout_count,rs.vs_blob,rs.fs_blob);

//    test_pipeline_state := platform.CreateDefaultPipelineStateStreamDesc(&input_layout[0],cast(i32)input_layout_count,rs.vs_blob,rs.fs_blob,false);
    //ID3D12PipelineState* pipeline_state = D12RendererCode::CreatePipelineState(ppss);    
//    FMJRenderMaterial base_render_material = {0};
    base_render_material : RenderMaterial;
    base_render_material.pipeline_state = create_pipeline_state(default_pipeline_state_stream);

    base_render_material.viewport_rect = la.Vector4{0,0,ps.window.dim.x,ps.window.dim.y};
    base_render_material.scissor_rect = la.Vector4{0,0,max(f32),max(f32)};
    
    asset_material_store(&asset_ctx,"base",base_render_material);

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
