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

import con "../containers"

foreign import gfx"../../library/windows/build/win32.lib"
import enginemath "../math"

D3D12_APPEND_ALIGNED_ELEMENT: u32: 0xffffffff;

GPUHeap :: struct {
	heap:  platform.ID3D12DescriptorHeap,
	count: u32,
}

default_srv_desc_heap: GPUHeap; //platform.ID3D12DescriptorHeap;
depth_heap: platform.ID3D12DescriptorHeap;
depth_buffer: rawptr; /*ID3D12Resource**/

device:           RenderDevice;
default_root_sig: rawptr;

temp_queue_command_list: con.Buffer(rawptr);

graphics_command_queue: rawptr;
copy_command_queue:     rawptr;
compute_command_queue:  rawptr;

rtv_descriptor_heap: rawptr;
render_texture_heap: platform.ID3D12DescriptorHeap;

current_allocator_index: u64;
rtv_desc_size:           u64;

allocator_tables: platform.D12CommandAllocatorTables;
resource_ca: rawptr; //ID3D12CommandAllocator*
resource_cl: rawptr; //ID3D12GraphicsCommandList*
upload_operations: platform.UploadOperations;

fence:       rawptr;
fence_event: windows.HANDLE;
fence_value: u64 = 0;

swap_chain:          rawptr;
num_of_back_buffers: int: 3;
back_buffers: [num_of_back_buffers]rawptr; /*ID3D12Resource* */

//d12_resources : con.Buffer(platform.D12Resource);

//back_buffer_current_state : platform.D3D12_RESOURCE_STATES;

num_of_render_textures: int;

is_resource_cl_recording: bool;

resourceviews: con.Buffer(platform.D12Resource);

@(default_calling_convention = "c")
foreign gfx
{
	//    Texture2D  :: proc "c"(lt : ^Texture,heap_index : u32,tex_resource : ^platform.D12Resource,heap : rawptr) ---;
	AllocateStaticGPUArena :: proc "c" (device: rawptr, size: u64) -> platform.GPUArena ---
	AllocateGPUArena       :: proc "c" (device: rawptr, size: u64) -> platform.GPUArena ---
	//    UploadBufferData :: proc "c"(g_arena : ^platform.GPUArena,data : rawptr,size : u64 ) ---;    
	SetArenaToVertexBufferView       :: proc "c" (g_arena: ^platform.GPUArena, size: u64, stride: u32) ---
	SetArenaToIndexVertexBufferView  :: proc "c" (g_arena: ^platform.GPUArena, size: u64, format: platform.DXGI_FORMAT) ---
	GetDescriptorHandleIncrementSize :: proc "c" (device: rawptr, DescriptorHeapType: platform.D3D12_DESCRIPTOR_HEAP_TYPE) -> c.uint ---
	CreateShaderResourceView         :: proc "c" (device: rawptr, resource: rawptr, desc: ^platform.D3D12_SHADER_RESOURCE_VIEW_DESC, handle: platform.D3D12_CPU_DESCRIPTOR_HANDLE) ---
	CreateConstantbufferView         :: proc "c" (device: rawptr, desc: ^platform.D3D12_CONSTANT_BUFFER_VIEW_DESC, handle: platform.D3D12_CPU_DESCRIPTOR_HANDLE) ---
	Map                              :: proc "c" (resource: rawptr, sub_resource: u32, range: ^platform.D3D12_RANGE, data: ^rawptr) -> windows.HRESULT ---
	Unmap                            :: proc "c" (resource: rawptr, sub_resource: u32, range: ^platform.D3D12_RANGE) -> windows.HRESULT ---

	CreateCommittedResource :: proc "c" (device: rawptr,
	                                pHeapProperties: ^platform.D3D12_HEAP_PROPERTIES,
	                                HeapFlags: platform.D3D12_HEAP_FLAGS,
	                                pDesc: ^platform.D3D12_RESOURCE_DESC,
	                                InitialResourceState: platform.D3D12_RESOURCE_STATES,
	                                pOptimizedClearValue: ^platform.D3D12_CLEAR_VALUE,
									resource: ^rawptr) -> windows.HRESULT ---
	CreateCommandQueue :: proc "c" (device: rawptr, type: platform.D3D12_COMMAND_LIST_TYPE) -> rawptr ---
	CreateSwapChain    :: proc "c" (hWnd: windows.HWND, commandQueue: rawptr, width: u32, height: u32, bufferCount: u32) -> rawptr ---
	//    UpdateRenderTargetViews :: proc "c"(device : rawptr,swapChain : rawptr, descriptorHeap : rawptr) ---;
	ResetCommandAllocator :: proc "c" (a: rawptr) -> /*ID3D12CommandAllocator* */ windows.LONG ---
	ResetCommandList :: proc "c" (list: rawptr, pAllocator: rawptr, pInitialState: rawptr) -> windows.HRESULT ---

	//    Init :: proc "c" (window : ^window32.Hwnd,dim : la.Vector2) -> CreateDeviceResult ---;

	D3D12UpdateSubresources :: proc "c" (pCmdList: rawptr, /*^ID3D12GraphicsCommandList*/ pDestinationResource: rawptr, /*^ID3D12Resource*/ pIntermediate: rawptr, /*^ID3D12Resource*/ FirstSubresource: u32, NumSubresources: u32, RequiredSize: u64, pSrcData: ^platform.D3D12_SUBRESOURCE_DATA) -> windows.HRESULT ---
	CloseCommandList :: proc "c" ( /*ID3D12CommandList**/list: rawptr) -> windows.HRESULT ---
	

	//TODO(Ray):Use a multipointer or something to make sure the user understands need an array here!!
	ExecuteCommandLists :: proc "c" (queue: rawptr, /*ID3D12CommandList* takes array of lists*/ lists: rawptr, list_count: u32) ---
	SetEventOnCompletion :: proc "c"(fence : rawptr/*ID3D12Fence**/,Value  : u64,hEvent : windows.HANDLE) -> window32.Hresult ---;
	Signal :: proc "c" ( /*ID3D12CommandQueue**/commandQueue: rawptr, /*ID3D12Fence**/ fence: rawptr, fenceValue: ^u64) -> u64 ---
	SignalCommandQueue :: proc "c"(commandQueue : rawptr/*^platform.ID3D12CommandQueue*/,pFence : rawptr /*^platform.ID3D12Fence*/,Value : u64) -> window32.Hresult ---;
	WaitForFenceValue :: proc "c" ( /*ID3D12Fence**/fence: rawptr, fenceValue: u64, fenceEvent: windows.HANDLE, duration: f64) ---
	CheckFeatureSupport :: proc "c" (device: rawptr, Feature: platform.D3D12_FEATURE, pFeatureSupportData: rawptr, FeatureSupportDataSize: windows.UINT) -> bool ---
	GetIntermediateSize :: proc "c" (resource: rawptr, /*ID3D12Resource* */ firstSubResource: u32, NumSubresources: u32) -> u64 ---
	CreateDepthStencilView :: proc "c" (device: rawptr, pResource: rawptr, /*ID3D12Resource **/ pDesc: ^platform.D3D12_DEPTH_STENCIL_VIEW_DESC, DestDescriptor: platform.D3D12_CPU_DESCRIPTOR_HANDLE) ---
	CreateRootSignature :: proc "c" (device: rawptr, params: ^platform.D3D12_ROOT_PARAMETER1, param_count: int, samplers: ^platform.D3D12_STATIC_SAMPLER_DESC, sampler_count: int, flags: platform.D3D12_ROOT_SIGNATURE_FLAGS) -> rawptr --- /*ID3D12RootSignature* */
	TransitionResource :: proc "c" (cle: platform.D12CommandListEntry, resource: /*ID3D12Resource*  */ rawptr, from: platform.D3D12_RESOURCE_STATES, to: platform.D3D12_RESOURCE_STATES) ---
	ClearRenderTargetView :: proc "c" (list: rawptr, RenderTargetView: platform.D3D12_CPU_DESCRIPTOR_HANDLE, ColorRGBA: [4]f32, NumRects: windows.UINT, pRects: ^platform.D3D12_RECT) ---
	ClearDepthStencilView :: proc "c" (list: rawptr, /*ID3D12GraphicsCommandList**/ DepthStencilView: platform.D3D12_CPU_DESCRIPTOR_HANDLE, ClearFlags: platform.D3D12_CLEAR_FLAGS, Depth: f32, Stencil: u8, NumRects: u32, pRects: ^platform.D3D12_RECT) ---
	OMSetRenderTargets :: proc "c" (list: rawptr, /*ID3D12GraphicsCommandList* */ NumRenderTargetDescriptors: u32, pRenderTargetDescriptors: ^platform.D3D12_CPU_DESCRIPTOR_HANDLE, RTsSingleHandleToDescriptorRange: bool, pDepthStencilDescriptor: ^platform.D3D12_CPU_DESCRIPTOR_HANDLE) ---
	RSSetViewports :: proc "c" (list: rawptr, NumViewports: u32, pViewports: ^platform.D3D12_VIEWPORT) ---
	SetGraphicsRootSignature :: proc "c" (list: rawptr, /*^platform.ID3D12GraphicsCommandList*/ pRootSignature: rawptr) --- /*^ID3D12RootSignature*/
	RSSetScissorRects      :: proc "c" (list: rawptr, NumRects: u32, pRects: ^platform.D3D12_RECT) ---
	IASetPrimitiveTopology :: proc "c" (list: rawptr, PrimitiveTopology: platform.D3D12_PRIMITIVE_TOPOLOGY) ---
	DrawInstanced          :: proc "c" (list: rawptr, VertexCountPerInstance: u32, InstanceCount: u32, StartVertexLocation: u32, StartInstanceLocation: u32) ---
	IASetIndexBuffer       :: proc "c" (list: rawptr, pView: ^platform.D3D12_INDEX_BUFFER_VIEW) ---
	DrawIndexedInstanced :: proc "c" (list: rawptr, /*ID3D12GraphicsCommandList**/ IndexCountPerInstance: u32, InstanceCount: u32, StartIndexLocation: u32, BaseVertexLocation: i32, StartInstanceLocation: u32) ---
	IASetVertexBuffers :: proc "c" (list: rawptr, StartSlot: u32, NumViews: u32, pViews: ^platform.D3D12_VERTEX_BUFFER_VIEW) ---
	SetPipelineState :: proc "c" (list: rawptr, pPipelineState: /*^ID3D12PipelineState*/ rawptr) ---

	//TODO(Ray):Use a multipointer or something to make sure the user understands need an array here!!
	SetDescriptorHeaps :: proc "c" ( /*ID3D12GraphicsCommandList**/list: rawptr, NumDescriptorHeaps: u32, ppDescriptorHeaps: /*ID3D12DescriptorHeap**/ rawptr) ---
	SetGraphicsRootDescriptorTable :: proc "c" ( /*ID3D12GraphicsCommandList* */list: rawptr, RootParameterIndex: u32, BaseDescriptor: platform.D3D12_GPU_DESCRIPTOR_HANDLE) ---
	SetGraphicsRoot32BitConstants :: proc "c" ( /*ID3D12GraphicsCommandList* */list: rawptr, RootParameterIndex: u32, Num32BitValuesToSet: u32, pSrcData: rawptr, DestOffsetIn32BitValues: u32) ---
	Present :: proc "c" (swap_chain: rawptr, /*IDXGISwapChain4* */ SyncInterval: u32, Flags: u32) -> windows.HRESULT ---
	GetBuffer :: proc "c" (swapChain: /*IDXGISwapChain4**/ rawptr, Buffer: windows.UINT, ppSurface: ^rawptr) -> windows.HRESULT ---
	CreateRenderTargetView :: proc "c" (device: rawptr, pResource: rawptr, pDesc: ^platform.D3D12_RENDER_TARGET_VIEW_DESC, DestDescriptor: platform.D3D12_CPU_DESCRIPTOR_HANDLE) ---
	CreateDevice :: proc "c" (adapter: rawptr) -> /*IDXGIAdapter4* */ rawptr ---
	GetAdapter :: proc "c" (useWarp: bool) -> rawptr --- /*IDXGIAdapter4**/
	OMSetStencilRef  :: proc "c" (list: rawptr, ref: u32) ---
	OMSetBlendFactor :: proc "c" (list: rawptr, BlendFactor: [4]f32) ---
	ResourceBarrier  :: proc "c" (list: rawptr, NumBarriers: c.uint, pBarriers: ^platform.D3D12_RESOURCE_BARRIER) ---
	CreateGraphicsPipelineState :: proc(device : rawptr/* ID3D12Device2* */,pDesc : ^platform.D3D12_GRAPHICS_PIPELINE_STATE_DESC) -> rawptr /*ID3D12PipelineState* */---;
}

CommandAllocToListResult :: struct {
	list:  platform.D12CommandListEntry,
	index: u64,
	found: bool,
}

CreateDeviceResult :: struct {
	is_init:          bool,
	compatible_level: c.int,
	dim:              enginemath.f2,
	device:           RenderDevice,
}

RenderDevice :: struct {
	device:                            rawptr,
	device_context:                    rawptr,
	max_render_targets:                u32, //GRAPHICS_MAX_RENDER_TARGETS;
	profile:                           platform.CompatibilityProfile,
	//TODO(Ray):- newArgumentEncoderWithArguments:
	//Creates a new argument encoder for a specific array of arguments.
	//Required.
	//ArgumentBuffersTier argument_buffers_support;
	//This limit is only applicable to samplers that have their supportArgumentBuffers property set to YES.
	max_argument_buffer_sampler_count: u32,
}

RenderCameraProjectionType :: enum {
	perspective,
	orthographic,
	screen_space,
}

RenderCamera :: struct {
	ot:                                   Transform, //perspective and ortho only
	matrix:                               enginemath.f4x4,
	projection_matrix:                    enginemath.f4x4,
	spot_light_shadow_projection_matrix:  enginemath.f4x4,
	point_light_shadow_projection_matrix: enginemath.f4x4,
	projection_type:                      RenderCameraProjectionType,
	size:                                 f32, //ortho only
	fov:                                  f32, //perspective only
	near_far_planes:                      enginemath.f2,
	matrix_id:                            u64,
	projection_matrix_id:                 u64,
}

GPUMeshResource :: struct {
	vertex_buff:  platform.GPUArena,
	normal_buff:  platform.GPUArena,
	uv_buff:      platform.GPUArena,
	tangent_buff: platform.GPUArena,
	element_buff: platform.GPUArena,
	hash_key:     u64,
	buffer_range: enginemath.f2,
	index_id:     u32,
}

RenderGeometry :: struct {
	buffer_id_range: enginemath.f2,
	count:           u64,
	offset:          u64,
	index_id:        u64,
	index_count:     u64,
	is_indexed:      bool,
	base_color:      enginemath.f4,
}

RenderShader :: struct {
	vs_file_name: cstring,
	fs_file_name: cstring,
	vs_blob:      rawptr, //ID3DBlob*,
	fs_blob:      rawptr, //ID3DBlob*
}

CreateRenderShader :: proc(vs_file_name: cstring, fs_file_name: cstring) -> RenderShader {
	result: RenderShader;
	result.vs_file_name = vs_file_name;
	result.fs_file_name = fs_file_name;
	platform.CompileShader_(vs_file_name, &result.vs_blob, "vs_5_1");
	platform.CompileShader_(fs_file_name, &result.fs_blob, "ps_5_1");
	return result;
}

CreateRenderShaderText :: proc(vs_shader : cstring, fs_shader : cstring) -> RenderShader {
	result: RenderShader;
	//result.vs_file_name = vs_file_name;
	//result.fs_file_name = fs_file_name;l
	platform.CompileShaderText_(vs_shader,i32(len(vs_shader)), &result.vs_blob, "vs_5_1");
	platform.CompileShaderText_(fs_shader,i32(len(fs_shader)), &result.fs_blob, "ps_5_1");
	return result;
}

CompileShader :: proc(shader_text : cstring,version : cstring) -> rawptr{
	result : rawptr;
	platform.CompileShaderText_(shader_text,i32(len(shader_text)), &result, version);
	return result;
}


/*
	RenderState :: struct
	{
	command_buffer : [dynamic]RenderCommand,//FMJStretchBuffer,
	};
*/

SwapChain :: struct {
	value: rawptr,
}

CommandQueue :: struct {
	value: rawptr,
}

create_command_queue :: proc(device: RenderDevice, type: platform.D3D12_COMMAND_LIST_TYPE) -> rawptr {
	return CreateCommandQueue(device.device, type);
}

DefferedLighting1PipelineStateStream :: struct {
	root_sig:            platform.PipelineStateSubObject( /*ID3D12RootSignature*/rawptr),
	input_layout:        platform.PipelineStateSubObject(platform.D3D12_INPUT_LAYOUT_DESC),
	topology_type:       platform.PipelineStateSubObject(platform.D3D12_PRIMITIVE_TOPOLOGY_TYPE),
	vertex_shader:       platform.PipelineStateSubObject(platform.D3D12_SHADER_BYTECODE),
	//    fragment_shader : PipelineStateSubObject(D3D12_SHADER_BYTECODE),
	dsv_format:          platform.PipelineStateSubObject(platform.DXGI_FORMAT),
	//    rtv_formats : PipelineStateSubObject(D3D12_RT_FORMAT_ARRAY),

	rasterizer_state:    platform.PipelineStateSubObject(platform.D3D12_RASTERIZER_DESC),

	//    blend_state : PipelineStateSubObject(D3D12_BLEND_DESC),    
	depth_stencil_state: platform.PipelineStateSubObject(platform.D3D12_DEPTH_STENCIL_DESC1),
}

PipelineStateStreamDescriptor :: struct {
	size: u32,
	ptr:  rawptr,
}

create_pipeline_state :: proc(pss: PipelineStateStreamDescriptor) -> rawptr /*ID3D12PipelineState**/
                              {
	result: rawptr;
	using platform;
	//    psslocal_copy := pss;
	//    pipeline_state_stream_desc : D3D12_PIPELINE_STATE_STREAM_DESC = {size_of(PipelineStateStream), &psslocal_copy};
	pipeline_state_stream_desc: D3D12_PIPELINE_STATE_STREAM_DESC = {cast(u64)pss.size, pss.ptr};

	result = CreatePipelineState(device.device, pipeline_state_stream_desc);
	return result;
}

//TODO(Ray):Ensure thread safety
asset_material_store :: proc(ctx: ^AssetContext, name: string, material: RenderMaterial) {
	//u64 result = ctx->asset_tables->material_count;
	//    material.id = ctx->asset_tables->material_count;
	//    fmj_anycache_add_to_free_list(&ctx->asset_tables->materials,(void*)&ctx->asset_tables->material_count,&material);
	//    ++ctx->asset_tables->material_count;
	ctx.asset_tables.materials[name] = material;
	ctx.asset_tables.material_count = ctx.asset_tables.material_count + 1;
}

set_arena_constant_buffer :: proc(device: rawptr, arena: ^platform.GPUArena, heap_index: u32, heap: platform.ID3D12DescriptorHeap) {
	srvDesc2 := platform.D3D12_SHADER_RESOURCE_VIEW_DESC{};
	//    srvDesc2.Shader4ComponentMapping = platform.D3D12_DEFAULT_SHADER_4_COMPONENT_MAPPING(0,1,2,3);
	srvDesc2.Shader4ComponentMapping = platform.D3D12_ENCODE_SHADER_4_COMPONENT_MAPPING(0, 1, 2, 3);
	srvDesc2.Format = platform.DXGI_FORMAT.DXGI_FORMAT_R32_TYPELESS;
	srvDesc2.ViewDimension = platform.D3D12_SRV_DIMENSION.D3D12_SRV_DIMENSION_BUFFER; //D3D12_SRV_DIMENSION_TEXTURE2D;
	srvDesc2.Buffer.Buffer.Flags = platform.D3D12_BUFFER_SRV_FLAGS.D3D12_BUFFER_SRV_FLAG_RAW;
	srvDesc2.Buffer.Buffer.FirstElement = 0;
	ele_num: u32 = cast(u32)arena.size / size_of(f32);
	srvDesc2.Buffer.Buffer.NumElements = ele_num;

	hmdh_size: u32 = GetDescriptorHandleIncrementSize(device, platform.D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

	hmdh := platform.GetCPUDescriptorHandleForHeapStart(heap.value);
	offset: u64 = cast(u64)hmdh_size * cast(u64)heap_index;
	hmdh.ptr = hmdh.ptr + cast(windows.SIZE_T)offset;

	CreateShaderResourceView(device, arena.resource, &srvDesc2, hmdh);
}

add_material :: proc(ps: ^platform.PlatformState, state: rawptr, name: string) {
	assert(state != nil);
	new_material: RenderMaterial;
	new_material.name = name;
	new_material.pipeline_state = state;
	new_material.viewport_rect = la.Vector4f32{0, 0, ps.window.dim.x, ps.window.dim.y};
	new_material.scissor_rect = la.Vector4f32{0, 0, max(f32), max(f32)};
	asset_material_store(&asset_ctx, name, new_material);
}

create_default_depth_stencil_buffer :: proc(dim: enginemath.f2) {
	using platform;

	hp: D3D12_HEAP_PROPERTIES = {
		.D3D12_HEAP_TYPE_DEFAULT,
		.D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
		.D3D12_MEMORY_POOL_UNKNOWN,
		0,
		0,
	};

	sd: DXGI_SAMPLE_DESC = {
		1, 0,
	};

	res_d: D3D12_RESOURCE_DESC = {
		.D3D12_RESOURCE_DIMENSION_TEXTURE2D,
		0,
		cast(u64)dim.x,
		cast(u32)dim.y,
		1, 0,
		//	.DXGI_FORMAT_D32_FLOAT,
		.DXGI_FORMAT_D24_UNORM_S8_UINT,
		sd,
		.D3D12_TEXTURE_LAYOUT_UNKNOWN,
		.D3D12_RESOURCE_FLAG_ALLOW_DEPTH_STENCIL,
	};

	width:               u32 = max(1, cast(u32)dim.x);
	height:              u32 = max(1, cast(u32)dim.y);
	optimizedClearValue: D3D12_CLEAR_VALUE;
	optimizedClearValue.Format = .DXGI_FORMAT_D24_UNORM_S8_UINT; //DXGI_FORMAT_D32_FLOAT;
	optimizedClearValue.clear_value.DepthStencil = {1.0, 1.0};

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
	dsv: platform.D3D12_DEPTH_STENCIL_VIEW_DESC;
	dsv.Format = .DXGI_FORMAT_D24_UNORM_S8_UINT; //DXGI_FORMAT_D32_FLOAT;
	dsv.ViewDimension = .D3D12_DSV_DIMENSION_TEXTURE2D;
	dsv.depth_stencil.Texture2D.MipSlice = 0;
	dsv.Flags = .D3D12_DSV_FLAG_NONE;

	CreateDepthStencilView(device.device, depth_buffer, &dsv, GetCPUDescriptorHandleForHeapStart(depth_heap.value));
}

create_default_root_sig :: proc() -> rawptr {
	using platform;
	dsv_h_d: D3D12_DESCRIPTOR_HEAP_DESC;
	dsv_h_d.NumDescriptors = 1;
	dsv_h_d.Type = .D3D12_DESCRIPTOR_HEAP_TYPE_DSV;
	dsv_h_d.Flags = .D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
	depth_heap = create_descriptor_heap(device.device, dsv_h_d);

	feature_data: D3D12_FEATURE_DATA_ROOT_SIGNATURE;
	feature_data.HighestVersion = .D3D_ROOT_SIGNATURE_VERSION_1_1;
	if CheckFeatureSupport(device.device, platform.D3D12_FEATURE.D3D12_FEATURE_ROOT_SIGNATURE, &feature_data, size_of(feature_data)) {
		feature_data.HighestVersion = .D3D_ROOT_SIGNATURE_VERSION_1_0;
	}

	// Allow input layout and deny unnecessary access to certain pipeline stages. // Allow input layout and deny unnecessary access to certain pipeline stages. // Allow input layout and deny unnecessary access to certain pipeline stages. // Allow input layout and deny unnecessary access to certain pipeline stages.
	root_sig_flags: platform.D3D12_ROOT_SIGNATURE_FLAGS = .D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT |
	                                                      .D3D12_ROOT_SIGNATURE_FLAG_DENY_HULL_SHADER_ROOT_ACCESS |
	                                                      .D3D12_ROOT_SIGNATURE_FLAG_DENY_DOMAIN_SHADER_ROOT_ACCESS |
	                                                      .D3D12_ROOT_SIGNATURE_FLAG_DENY_GEOMETRY_SHADER_ROOT_ACCESS;
	//|D3D12_ROOT_SIGNATURE_FLAG_DENY_PIXEL_SHADER_ROOT_ACCESS;

	// create a descriptor range (descriptor table) and fill it out
	// this is a range of descriptors inside a descriptor heap
	descriptorTableRanges: [1]platform.D3D12_DESCRIPTOR_RANGE1;

	descriptorTableRanges[0].RangeType = .D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
	descriptorTableRanges[0].NumDescriptors = max(u32);
	descriptorTableRanges[0].BaseShaderRegister = 0;
	descriptorTableRanges[0].RegisterSpace = 0;
	descriptorTableRanges[0].OffsetInDescriptorsFromTableStart = platform.D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND;
	descriptorTableRanges[0].Flags = .D3D12_DESCRIPTOR_RANGE_FLAG_DESCRIPTORS_VOLATILE;

	// create a descriptor table
	descriptorTable: D3D12_ROOT_DESCRIPTOR_TABLE1;
	descriptorTable.NumDescriptorRanges = len(descriptorTableRanges);
	descriptorTable.pDescriptorRanges = &descriptorTableRanges[0];

	rc_1: platform.D3D12_ROOT_CONSTANTS;
	rc_1.RegisterSpace = 0;
	rc_1.ShaderRegister = 0;
	rc_1.Num32BitValues = 16;

	rc_2: D3D12_ROOT_CONSTANTS;
	rc_2.RegisterSpace = 0;
	rc_2.ShaderRegister = 1;
	rc_2.Num32BitValues = 16;

	rc_3: D3D12_ROOT_CONSTANTS;
	rc_3.RegisterSpace = 0;
	rc_3.ShaderRegister = 2;
	rc_3.Num32BitValues = 4;

	rc_4: D3D12_ROOT_CONSTANTS;
	rc_4.RegisterSpace = 0;
	rc_4.ShaderRegister = 0;
	rc_4.Num32BitValues = 4;

	root_params: [5]D3D12_ROOT_PARAMETER1;
	root_params[0].ParameterType = .D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
	root_params[0].ShaderVisibility = .D3D12_SHADER_VISIBILITY_VERTEX;
	root_params[0].root_parameter1_union.Constants = rc_1;

	// fill out the parameter for our descriptor table. Remember it's a good idea to sort parameters by frequency of change. Our constant
	// buffer will be changed multiple times per frame, while our descriptor table will not be changed at all.
	root_params[1].ParameterType = .D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
	root_params[1].root_parameter1_union.DescriptorTable = descriptorTable;
	root_params[1].ShaderVisibility = .D3D12_SHADER_VISIBILITY_ALL;

	root_params[2].ParameterType = .D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
	root_params[2].ShaderVisibility = .D3D12_SHADER_VISIBILITY_ALL;
	root_params[2].root_parameter1_union.Constants = rc_2;

	root_params[3].ParameterType = .D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
	root_params[3].ShaderVisibility = .D3D12_SHADER_VISIBILITY_VERTEX;
	root_params[3].root_parameter1_union.Constants = rc_3;

	root_params[4].ParameterType = .D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
	root_params[4].ShaderVisibility = .D3D12_SHADER_VISIBILITY_PIXEL;
	root_params[4].root_parameter1_union.Constants = rc_4;

	vs: D3D12_STATIC_SAMPLER_DESC;
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

	tex_static_samplers: [2]D3D12_STATIC_SAMPLER_DESC;
	tex_static_samplers[0] = vs;

	ss: D3D12_STATIC_SAMPLER_DESC;
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

	return CreateRootSignature(device.device, mem.raw_slice_data(root_params[:]), len(root_params), mem.raw_slice_data(tex_static_samplers[:]), 2, root_sig_flags);
}

update_render_target_views :: proc(device: rawptr, swapChain: rawptr, descriptorHeap: rawptr) {
	using platform;
	rtv_desc_size := GetDescriptorHandleIncrementSize(device, .D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
	rtv_handle: D3D12_CPU_DESCRIPTOR_HANDLE = GetCPUDescriptorHandleForHeapStart(descriptorHeap);
	for i := 0; i < num_of_back_buffers; i += 1 {
		back_buffer: rawptr;
		r:           windows.HRESULT = GetBuffer(swapChain, cast(u32)i, &back_buffer);
		assert(r == 0);
		//	    fmt.println("back_buffer : ",back_buffer, "\n");
		CreateRenderTargetView(device, back_buffer, nil, rtv_handle);
		back_buffers[i] = back_buffer;
		rtv_handle.ptr = rtv_handle.ptr + cast(windows.SIZE_T)rtv_desc_size; //cast(windows.SIZE_T)offset;

		tex_resource: platform.D12Resource;
		tex_resource.state = back_buffers[i];
		tex_resource.resource_state = .D3D12_RESOURCE_STATE_COMMON;
		con.buf_push(&resourceviews, tex_resource);
	}
}

init :: proc(ps: ^platform.PlatformState) -> CreateDeviceResult {
	using platform;
	result: CreateDeviceResult;
	adapter := GetAdapter(false);
	device.device = CreateDevice(adapter);
	result.device.device = device.device;
	result.is_init = true;

	////////////////////////////////
	graphics_command_queue = create_command_queue(device, .D3D12_COMMAND_LIST_TYPE_DIRECT);
	copy_command_queue = create_command_queue(device, .D3D12_COMMAND_LIST_TYPE_COPY);
	compute_command_queue = create_command_queue(device, .D3D12_COMMAND_LIST_TYPE_COMPUTE);

	desc: D3D12_DESCRIPTOR_HEAP_DESC;
	desc.NumDescriptors = cast(u32)num_of_back_buffers;
	desc.Type = .D3D12_DESCRIPTOR_HEAP_TYPE_RTV;

	swap_chain = CreateSwapChain(cast(windows.HWND)ps.window.handle, graphics_command_queue, cast(u32)ps.window.dim.x, cast(u32)ps.window.dim.y, cast(u32)num_of_back_buffers);

	rtv_desc_size := GetDescriptorHandleIncrementSize(device.device, .D3D12_DESCRIPTOR_HEAP_TYPE_RTV);

	rtv_descriptor_heap = create_descriptor_heap(device.device, desc).value;

	update_render_target_views(device.device, swap_chain, rtv_descriptor_heap);

	fence = CreateFence(device.device);
	fence_event = CreateEventHandle();

	//////////////////////////////////
	default_root_sig = create_default_root_sig();
	create_default_depth_stencil_buffer(ps.window.dim);

	using fmj;

	input_layout := [?]D3D12_INPUT_ELEMENT_DESC {
		{"POSITION", 0, .DXGI_FORMAT_R32G32B32_FLOAT, 0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
		{"COLOR", 0, .DXGI_FORMAT_R32G32B32A32_FLOAT, 0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
		{"TEXCOORD", 0, .DXGI_FORMAT_R32G32_FLOAT, 0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
	};

	fmt.println("sizeofinputlayout", size_of(input_layout));
	fmt.println("sizeofinputlayout elemenet: ", size_of(input_layout[0]));
	input_layout_mesh: []D3D12_INPUT_ELEMENT_DESC = {
		{"POSITION", 0, .DXGI_FORMAT_R32G32B32_FLOAT, 0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
		{"NORMAL", 0, .DXGI_FORMAT_R32G32B32_FLOAT, 1, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
		//        { "COLOR"   , 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 1, D3D12_APPEND_ALIGNED_ELEMENT, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
		{"TEXCOORD", 0, .DXGI_FORMAT_R32G32_FLOAT, 2, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
	};

	input_layout_pn_mesh: []D3D12_INPUT_ELEMENT_DESC = {
		{"POSITION", 0, .DXGI_FORMAT_R32G32B32_FLOAT, 0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
		{"NORMAL", 0, .DXGI_FORMAT_R32G32B32_FLOAT, 1, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
	};

	input_layout_vu_mesh: []D3D12_INPUT_ELEMENT_DESC = {
		{"POSITION", 0, .DXGI_FORMAT_R32G32B32_FLOAT, 0, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
		{"TEXCOORD", 0, .DXGI_FORMAT_R32G32_FLOAT, 1, D3D12_APPEND_ALIGNED_ELEMENT, .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
	};

	input_layout_count         := len(input_layout);
	input_layout_count_mesh    := len(input_layout_mesh);
	input_layout_vu_count_mesh := len(input_layout_vu_mesh);
	input_layout_pn_count_mesh := len(input_layout_pn_mesh);
	fmt.println("input layout count : ", input_layout_count);
	// Create a root/shader signature.

	vs_file_name:      cstring = "vs_test.hlsl";
	vs_mesh_vu_name:   cstring = "vs_vu.hlsl";
	vs_mesh_file_name: cstring = "vs_test_mesh.hlsl";
	vs_gbuffer_name:   cstring = "vs_gbuffer.hlsl";
	vs_pn_file_name:   cstring = "vs_pn.hlsl";
	vs_comp_file_name: cstring = "vs_comp.hlsl";

	fs_file_name:             cstring = "ps_test.hlsl";
	fs_gbuffer_file_name:     cstring = "ps_gbuffer.hlsl";
	fs_comp_file_name:        cstring = "ps_comp.hlsl";
	fs_color_file_name:       cstring = "fs_color.hlsl";
	fs_light_accum_file_name: cstring = "ps_light_accum.hlsl";

	rs            := CreateRenderShader(vs_file_name, fs_file_name);
	mesh_rs       := CreateRenderShader(vs_mesh_file_name, fs_file_name);
	mesh_vu_rs    := CreateRenderShader(vs_mesh_vu_name, fs_file_name);
	rs_color      := CreateRenderShader(vs_file_name, fs_color_file_name);
	mesh_pn_color := CreateRenderShader(vs_pn_file_name, fs_color_file_name);
	rs_gbuffer    := CreateRenderShader(vs_gbuffer_name, fs_gbuffer_file_name);

	rs_light_accum := CreateRenderShader(vs_gbuffer_name, fs_light_accum_file_name);
	rs_comp        := CreateRenderShader(vs_comp_file_name, fs_comp_file_name);

	//basic
	base_stream_pipeline_state := create_default_pipeline_state_stream_desc(default_root_sig, &input_layout[0], input_layout_count, rs.vs_blob, rs.fs_blob);
	add_material(&ps, base_stream_pipeline_state, "base");

	//mesh

	mesh_pipeline_state := create_default_pipeline_state_stream_desc(default_root_sig, &input_layout_mesh[0], input_layout_count_mesh, mesh_rs.vs_blob, mesh_rs.fs_blob);
	add_material(&ps, mesh_pipeline_state, "mesh");

	gbuff_pipeline_state := create_gbuffer_pipeline_state_stream_desc(default_root_sig, &input_layout_mesh[0], input_layout_count_mesh, rs_gbuffer.vs_blob, rs_gbuffer.fs_blob);
	add_material(&ps, gbuff_pipeline_state, "gbuffer");

	light_accum_stage1_pipeline_state, light_accum_stage2_pipeline_state := create_lighting_pipeline_state_stream_desc(default_root_sig, &input_layout_mesh[0], input_layout_count_mesh, rs_gbuffer.vs_blob, rs_light_accum.fs_blob);

	add_material(&ps, light_accum_stage1_pipeline_state, "light_accum_pass1");
	add_material(&ps, light_accum_stage2_pipeline_state, "light_accum_pass2");

	comp_pipeline_state := create_default_pipeline_state_stream_desc(default_root_sig, &input_layout_vu_mesh[0], input_layout_vu_count_mesh, rs_comp.vs_blob, rs_comp.fs_blob);
	add_material(&ps, comp_pipeline_state, "composite");


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
	constants = arena_init(1024 * 1024 * 4);
	dx12_init(device);
	result.is_init = true;

	return result;
}

add_free_command_allocator :: proc(type: platform.D3D12_COMMAND_LIST_TYPE) -> ^platform.D12CommandAllocatorEntry {
	using con;
	entry: platform.D12CommandAllocatorEntry;
	entry.allocator = platform.CreateCommandAllocator(device.device, type);

	assert(entry.allocator != nil);

	entry.used_list_indexes = buf_init(1, u64);
	entry.fence_value = 0;
	//    entry.thread_id = fmj_thread_get_thread_id();
	entry.type = type;

	entry.index = current_allocator_index;
	current_allocator_index += 1;

	key: platform.D12CommandAllocatorKey = {cast(u64)cast(uintptr)entry.allocator, entry.thread_id};
	//TODO(Ray):Why is the key parameter backwards here?

	//    fmj_anycache_add_to_free_list(&allocator_tables.fl_ca,&key,&entry);
	con.anycache_add_to_free_list(&allocator_tables.fl_ca, key, entry);
	//        D12CommandAllocatorEntry* result = (D12CommandAllocatorEntry*)AnythingCacheCode::GetThing(&allocator_tables.fl_ca, &key);
	result: ^platform.D12CommandAllocatorEntry = con.anycache_get_ptr(&allocator_tables.fl_ca, key);
	//    assert(result != nil);
	return result;
}

get_free_command_allocator_entry :: proc(list_type: platform.D3D12_COMMAND_LIST_TYPE) -> ^platform.D12CommandAllocatorEntry {
	using con;
	result: ^platform.D12CommandAllocatorEntry = nil;
	//Forget the free list we will access the table directly and get the first free
	//remove and make a inflight allocator table.
	//This does not work with free lists due to the fact taht the top element might always be busy
	//in some cases causing the infinite allocation of command allocators.
	//result = GetFirstFreeWithPredicate(D12CommandAllocatorEntry,allocator_tables.fl_ca,GetCAPredicateDIRECT);
	table := get_table(list_type);

	if buf_len(table^) <= 0 {
		result = nil;
	} else {
		// NOTE(Ray Garner): We assume if we get a free one you WILL use it.
		//otherwise we will need to do some other bookkeeping.
		result = buf_ptr(table, buf_len(table^) - 1)^;
		if !platform.IsFenceComplete(fence, result.fence_value) {
			result = nil;
		} else {
			buf_pop(table);
		}
	}

	if result == nil {
		result = add_free_command_allocator(list_type);
	}
	assert(result != nil);
	return result;
}

create_render_texture :: proc(ctx: ^AssetContext, dim: enginemath.f2, heap: platform.ID3D12DescriptorHeap, format: platform.DXGI_FORMAT = .DXGI_FORMAT_R8G8B8A8_UNORM) -> (int, int) {
	using platform;

	//texture heap
	hmdh_srv_size: u32 = GetDescriptorHandleIncrementSize(device.device, platform.D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

	hmdh_srv := platform.GetCPUDescriptorHandleForHeapStart(default_srv_desc_heap.heap.value);
	offset_srv: u64 = cast(u64)hmdh_srv_size * cast(u64)default_srv_desc_heap.count;
	hmdh_srv.ptr = hmdh_srv.ptr + cast(windows.SIZE_T)offset_srv;

	result_srv_heap_id := default_srv_desc_heap.count;
	default_srv_desc_heap.count += 1;

	//render target heap
	hmdh_size := GetDescriptorHandleIncrementSize(device.device, .D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
	hmdh      := platform.GetCPUDescriptorHandleForHeapStart(heap.value);
	offset: u64 = cast(u64)hmdh_size * cast(u64)num_of_render_textures;
	hmdh.ptr = hmdh.ptr + cast(windows.SIZE_T)offset;

	srvDesc2: platform.D3D12_SHADER_RESOURCE_VIEW_DESC;
	srvDesc2.Shader4ComponentMapping = platform.D3D12_ENCODE_SHADER_4_COMPONENT_MAPPING(0, 1, 2, 3);
	srvDesc2.Format = format;
	srvDesc2.ViewDimension = platform.D3D12_SRV_DIMENSION.D3D12_SRV_DIMENSION_TEXTURE2D;
	srvDesc2.Buffer.Texture2D.MipLevels = 1;

	tex_resource: platform.D12Resource;

	sd: DXGI_SAMPLE_DESC = {
		1, 0,
	};

	res_d: D3D12_RESOURCE_DESC = {
		.D3D12_RESOURCE_DIMENSION_TEXTURE2D,
		0,
		cast(u64)dim.x,
		cast(u32)dim.y,
		1, 0,
		format,
		sd,
		.D3D12_TEXTURE_LAYOUT_UNKNOWN,
		.D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET,
	};

	hp: D3D12_HEAP_PROPERTIES = {
		.D3D12_HEAP_TYPE_DEFAULT,
		.D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
		.D3D12_MEMORY_POOL_UNKNOWN,
		1,
		1,
	};

	CreateCommittedResource(device.device,
	                        &hp,
	                        .D3D12_HEAP_FLAG_NONE,
	                        &res_d,
	                        .D3D12_RESOURCE_STATE_RENDER_TARGET,
	                        nil,
	                        &tex_resource.state);

	CreateShaderResourceView(device.device, tex_resource.state, &srvDesc2, hmdh_srv);

	CreateRenderTargetView(device.device, tex_resource.state, nil, hmdh);

	result_render_texture_heap_id := num_of_render_textures;
	num_of_render_textures = num_of_render_textures + 1;

	tex_resource.resource_state = .D3D12_RESOURCE_STATE_RENDER_TARGET;
	trid := con.buf_push(&resourceviews, tex_resource);
	assert(trid != 0 || trid != 1 || trid != 2);

	return result_render_texture_heap_id, cast(int)result_srv_heap_id;
}

texture_2d :: proc(lt: ^Texture, heap_index: u32, tex_resource: ^platform.D12Resource, heap: rawptr, /*ID3D12DescriptorHeap* */ is_render_target: bool = false) {
	                   using platform;
	                   using enginemath;
	                   using math;
	                   free_ca: ^platform.D12CommandAllocatorEntry = get_free_command_allocator_entry(platform.D3D12_COMMAND_LIST_TYPE.D3D12_COMMAND_LIST_TYPE_COPY);
	                   resource_ca = free_ca.allocator;

	                   if !is_resource_cl_recording {
		ResetCommandAllocator(resource_ca);
		ResetCommandList(resource_cl, resource_ca, nil);
		is_resource_cl_recording = true;
	}

	hp: D3D12_HEAP_PROPERTIES = {
		.D3D12_HEAP_TYPE_UPLOAD,
		.D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
		.D3D12_MEMORY_POOL_UNKNOWN,
		0,
		0,
	};

	sd: DXGI_SAMPLE_DESC = {
		1, 0,
	};

	resource_flags: D3D12_RESOURCE_FLAGS;
	if is_render_target {
		resource_flags = .D3D12_RESOURCE_FLAG_ALLOW_RENDER_TARGET;
	} else {
		resource_flags = .D3D12_RESOURCE_FLAG_NONE;
	}

	req_size := GetIntermediateSize(tex_resource.state, 0, 1);
	res_d: D3D12_RESOURCE_DESC = {
		.D3D12_RESOURCE_DIMENSION_BUFFER,
		0,
		req_size,
		1,
		1,
		1,
		.DXGI_FORMAT_UNKNOWN,
		sd,
		.D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
		resource_flags,
	};

	subresourceData: D3D12_SUBRESOURCE_DATA;
	subresourceData.pData = lt.texels;

	// TODO(Ray Garner): Handle minimum size for alignment.
	//This wont work for a smaller texture im pretty sure.
	subresourceData.RowPitch = cast(int)(cast(u32)lt.dim.x * lt.bytes_per_pixel);
	subresourceData.SlicePitch = subresourceData.RowPitch;

	// Create a temporary (intermediate) resource for uploading the subresources

	uop: UploadOp;

	intermediate_resource: rawptr; /*ID3D12Resource**/
	hr: windows.HRESULT = CreateCommittedResource(
	                                              device.device,
	                                              &hp,
	                                              .D3D12_HEAP_FLAG_NONE,
	                                              &res_d,
	                                              .D3D12_RESOURCE_STATE_GENERIC_READ,
	                                              nil,
	                                              &uop.temp_arena.resource);

	//    uop.temp_arena.resource.SetName(L"TEMP_UPLOAD_TEXTURE");
	assert(hr == 0);

	hr = D3D12UpdateSubresources(resource_cl, tex_resource.state, uop.temp_arena.resource, 0, 0, 1, &subresourceData);

	CheckFeatureSupport(device.device, platform.D3D12_FEATURE.D3D12_FEATURE_FORMAT_SUPPORT, &tex_resource.format_support, size_of(platform.D3D12_FEATURE.D3D12_FEATURE_FORMAT_SUPPORT));

	lt.state = tex_resource.state;
	ticket_mutex_begin(&upload_operations.ticket_mutex);
	upload_operations.current_op_id += 1;
	k: UploadOpKey = {uop.id};
	con.anycache_add_to_free_list(&upload_operations.table_cache, k, uop);

	// NOTE(Ray Garner): Implement this.
	//if(upload_ops.anythings.count > UPLOAD_OP_THRESHOLD)
	{
		if is_resource_cl_recording {
			CloseCommandList(resource_cl);
			is_resource_cl_recording = false;
		}
		command_lists: []rawptr = {
			resource_cl,
		};

		//copy_command_queue->ExecuteCommandLists(_countof(command_lists), command_lists);
		ExecuteCommandLists(copy_command_queue, mem.raw_slice_data(command_lists[:]), cast(u32)len(command_lists));
		upload_operations.fence_value = Signal(copy_command_queue, upload_operations.fence, &upload_operations.fence_value);

		WaitForFenceValue(upload_operations.fence, upload_operations.fence_value, upload_operations.fence_event, F32_MAX);

		//If we have gotten here we remove the temmp transient resource. and remove them from the cache
		for i := 0; i < cast(int)con.buf_len(upload_operations.table_cache.anythings); i += 1 {
			finished_uop: ^UploadOp = con.buf_ptr(&upload_operations.table_cache.anythings, cast(u64)i);
			// NOTE(Ray Garner): Upload should always be a copy operation and so we cant/dont need to 
			//call discard resource.

			//finished_uop->temp_arena.resource->Release();
			k_: UploadOpKey = {finished_uop.id};
			con.anycache_remove_free_list(&upload_operations.table_cache, k_);
		}
		con.anycache_reset(&upload_operations.table_cache);
	}
	ticket_mutex_end(&upload_operations.ticket_mutex);
}

upload_buffer_data :: proc(g_arena: ^platform.GPUArena, data: rawptr, size: u64) {
	using platform;
	free_ca: ^platform.D12CommandAllocatorEntry = get_free_command_allocator_entry(platform.D3D12_COMMAND_LIST_TYPE.D3D12_COMMAND_LIST_TYPE_COPY);
	resource_ca = free_ca.allocator;

	if !is_resource_cl_recording {
		ResetCommandAllocator(resource_ca);
		ResetCommandList(resource_cl, resource_ca, nil);
		is_resource_cl_recording = true;
	}

	hp: D3D12_HEAP_PROPERTIES = {
		.D3D12_HEAP_TYPE_UPLOAD,
		.D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
		.D3D12_MEMORY_POOL_UNKNOWN,
		0,
		0,
	};

	sample_d: DXGI_SAMPLE_DESC = {
		1,
		0,
	};

	res_d: D3D12_RESOURCE_DESC = {
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

	uop: UploadOp;
	uop.arena = g_arena^;

	hr: windows.HRESULT = CreateCommittedResource(
	                                              device.device,
	                                              &hp,
	                                              .D3D12_HEAP_FLAG_NONE,
	                                              &res_d,
	                                              .D3D12_RESOURCE_STATE_GENERIC_READ,
	                                              nil,
	                                              &uop.temp_arena.resource);

	//    uop.temp_arena.resource->SetName(L"TEMP_UPLOAD_BUFFER");

	assert(hr == 0);

	subresourceData: D3D12_SUBRESOURCE_DATA;
	subresourceData.pData = data;
	subresourceData.RowPitch = cast(int)size;
	subresourceData.SlicePitch = subresourceData.RowPitch;

	hr = D3D12UpdateSubresources(resource_cl, g_arena.resource, uop.temp_arena.resource, 0, 0, 1, &subresourceData);
	// NOTE(Ray Garner): We will batch as many texture ops into one command list as possible 
	//and only after we have reached a signifigant amout flush the commands.
	//and do a final check at the end of the frame to flush any that were not flushed earlier.
	//meaning we batch as many as possible per frame but never wait long than one frame to batch.

	ticket_mutex_begin(&upload_operations.ticket_mutex);
	uop.id = upload_operations.current_op_id;
	upload_operations.current_op_id += 1;
	k: UploadOpKey = {uop.id};
	//AnythingCacheCode::AddThingFL(&upload_operations.table_cache,&k,&uop);
	con.anycache_add_to_free_list(&upload_operations.table_cache, k, uop);
	//if(upload_ops.anythings.count > UPLOAD_OP_THRESHOLD)
	{
		if is_resource_cl_recording {
			CloseCommandList(resource_cl);
			is_resource_cl_recording = false;
		}

		command_lists: []rawptr = {
			resource_cl,
		};

		//copy_command_queue->ExecuteCommandLists(_countof(command_lists), command_lists);
		ExecuteCommandLists(copy_command_queue, mem.raw_slice_data(command_lists[:]), cast(u32)len(command_lists));
		upload_operations.fence_value = Signal(copy_command_queue, upload_operations.fence, &upload_operations.fence_value);
		WaitForFenceValue(upload_operations.fence, upload_operations.fence_value, upload_operations.fence_event, math.F32_MAX);

		//If we have gotten here we remove the temmp transient resource. and remove them from the cache
		for i := 0; i < cast(int)con.buf_len(upload_operations.table_cache.anythings); i += 1 {
			finished_uop: ^UploadOp = con.buf_ptr(&upload_operations.table_cache.anythings, cast(u64)i);
			// NOTE(Ray Garner): Upload should always be a copy operation and so we cant/dont need to 
			//call discard resource.

			//finished_uop->temp_arena.resource->Release();
			k_: UploadOpKey = {finished_uop.id};
			con.anycache_remove_free_list(&upload_operations.table_cache, k_);
		}
		con.anycache_reset(&upload_operations.table_cache);
	}
	ticket_mutex_end(&upload_operations.ticket_mutex);
}

transition_resource_request :: proc(cle: platform.D12CommandListEntry, resource: ^platform.D12Resource, to: platform.D3D12_RESOURCE_STATES) {
	if (resource.resource_state != to) {
		TransitionResource(cle, resource.state, resource.resource_state, to);
		resource.resource_state = to;
	}
}

dx12_init :: proc(device: RenderDevice) {
	using con;
	using platform;
	allocator_tables.free_allocator_table_direct = buf_init(1, ^D12CommandAllocatorEntry);
	allocator_tables.free_allocator_table_copy = buf_init(1, ^D12CommandAllocatorEntry);
	allocator_tables.free_allocator_table_compute = buf_init(1, ^D12CommandAllocatorEntry);

	allocator_tables.free_allocators = buf_init(1, D12CommandAllocatorEntry);
	allocator_tables.command_lists = buf_init(1, D12CommandListEntry);
	allocator_tables.allocator_to_list_table = buf_init(1, D12CommandAlloctorToCommandListKeyEntry);
	temp_queue_command_list = buf_init(1, rawptr);

	allocator_tables.fl_ca = con.anycache_init(D12CommandAllocatorKey, D12CommandAllocatorEntry, true);

	//Resource bookkeeping
	resource_ca = CreateCommandAllocator(device.device, .D3D12_COMMAND_LIST_TYPE_COPY);

	resource_cl = CreateCommandList(device.device, resource_ca, .D3D12_COMMAND_LIST_TYPE_COPY);

	upload_operations.table_cache = anycache_init(UploadOpKey, UploadOp, true);

	upload_operations.ticket_mutex = {};
	upload_operations.current_op_id = 1;
	upload_operations.fence_value = 0;
	upload_operations.fence = CreateFence(device.device);
	upload_operations.fence_event = CreateEventHandle();
}

get_table :: proc(type: platform.D3D12_COMMAND_LIST_TYPE) -> ^con.Buffer(^platform.D12CommandAllocatorEntry) {
	#partial switch type
	                {
	case .D3D12_COMMAND_LIST_TYPE_DIRECT:
		return &allocator_tables.free_allocator_table_direct;
	case .D3D12_COMMAND_LIST_TYPE_COPY:
		return &allocator_tables.free_allocator_table_copy;
	case .D3D12_COMMAND_LIST_TYPE_COMPUTE:
		return &allocator_tables.free_allocator_table_compute;
	case:
		return nil;
	}
}

check_reuse_command_allocators :: proc() {
	using con;
	buf_clear(&allocator_tables.free_allocator_table_direct);
	buf_clear(&allocator_tables.free_allocator_table_compute);
	buf_clear(&allocator_tables.free_allocator_table_copy);
	for i := 0; i < cast(int)buf_len(allocator_tables.fl_ca.anythings); i += 1 {
		entry: ^platform.D12CommandAllocatorEntry = buf_ptr(&allocator_tables.fl_ca.anythings, cast(u64)i);
		if entry != nil {
			//Only assert for the direct as the copies execute directly //Only assert for the direct as the copies execute directly
			if entry.type == .D3D12_COMMAND_LIST_TYPE_DIRECT {
				assert(entry.executed == true);
			}


			//Check the fence values             //Check the fence values             //Check the fence values             //Check the fence values            
			if platform.IsFenceComplete(fence, entry.fence_value) {
				table := get_table(entry.type);
				//if one put them on the free table for reuse.
				buf_push(table, entry);
			}
		}

	}
}

get_cpu_handle_srv :: proc(device: RenderDevice, heap: rawptr, heap_index: u32) -> platform.D3D12_CPU_DESCRIPTOR_HANDLE {
	using platform;
	result:    platform.D3D12_CPU_DESCRIPTOR_HANDLE = platform.GetCPUDescriptorHandleForHeapStart(heap);
	hmdh_size: u32                                  = GetDescriptorHandleIncrementSize(device.device, platform.D3D12_DESCRIPTOR_HEAP_TYPE.D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV);

	offset: u64 = cast(u64)hmdh_size * cast(u64)heap_index;
	result.ptr = result.ptr + cast(windows.SIZE_T)offset;
	return result;
}

get_first_associated_list :: proc(allocator: ^platform.D12CommandAllocatorEntry) -> CommandAllocToListResult {
	using con;
	using platform;
	result: CommandAllocToListResult;
	found:  bool = false;
	//Run through all the list that are associated with an allocator check for first available list
	for i := 0; i < cast(int)buf_len(allocator_tables.allocator_to_list_table); i += 1 {
		entry: ^D12CommandAlloctorToCommandListKeyEntry = buf_ptr(&allocator_tables.allocator_to_list_table, cast(u64)i);
		if allocator.index == entry.command_list_index {
			e: ^D12CommandListEntry = buf_ptr(&allocator_tables.command_lists, entry.command_list_index);
			assert(e != nil);
			if e.is_encoding != false {
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
	return result;
}

//render encoder
get_associated_command_list :: proc(ca: ^platform.D12CommandAllocatorEntry) -> platform.D12CommandListEntry {
	using platform;
	using con;
	listandindex:       CommandAllocToListResult = get_first_associated_list(ca);
	command_list_entry: D12CommandListEntry      = listandindex.list;
	cl_index:           u64                      = listandindex.index;
	if listandindex.found == false {
		command_list_entry.list = CreateCommandList(device.device, ca.allocator, ca.type);
		command_list_entry.is_encoding = true;
		command_list_entry.temp_resources = buf_init(1, rawptr);

		cl_index = buf_push(&allocator_tables.command_lists, command_list_entry);
		command_list_entry.index = cl_index;

		a_t_l_e: D12CommandAlloctorToCommandListKeyEntry;
		a_t_l_e.command_allocator_index = ca.index;
		a_t_l_e.command_list_index = cl_index;
		buf_push(&allocator_tables.allocator_to_list_table, a_t_l_e);
	}
	buf_push(&ca.used_list_indexes, cl_index);
	return command_list_entry;
}

end_command_list_encoding_and_execute :: proc(ca: ^platform.D12CommandAllocatorEntry, cl: platform.D12CommandListEntry) {
	using platform;
	using con;
	//Render encoder end encoding
	index: u64 = cl.index;

	for i := 0; i < cast(int)buf_len(ca.used_list_indexes); i += 1 {
		index_: u64 = buf_get(&ca.used_list_indexes, cast(u64)i); //*((u64*)ca.used_list_indexes.fixed.base + i);
		cle: ^D12CommandListEntry = buf_ptr(&allocator_tables.command_lists, index_);
		cle.is_encoding = false;
		r := CloseCommandList(cle.list);

		buf_push(&temp_queue_command_list, cle.list);
	}

	temp: rawptr = mem.raw_slice_data(temp_queue_command_list.buffer[:]);
	ExecuteCommandLists(graphics_command_queue, temp, cast(u32)buf_len(temp_queue_command_list));
	ca.executed = true;
	//    HRESULT removed_reason = device.GetDeviceRemovedReason();
	//    DWORD e = GetLastError();

	buf_clear(&temp_queue_command_list);
	buf_clear(&ca.used_list_indexes);
}

add_set_vertex_buffer_command :: proc(slot: u32, buffer_view: platform.D3D12_VERTEX_BUFFER_VIEW) {
	com: D12CommandSetVertexBuffer;
	com.slot = slot;
	com.buffer_view = buffer_view;
	con.buf_push(&render_commands, com);
}

add_draw_indexed_command :: proc(index_count: u32, index_offset: u32, topology: platform.D3D12_PRIMITIVE_TOPOLOGY, index_buffer_view: platform.D3D12_INDEX_BUFFER_VIEW) {
	com: D12CommandIndexedDraw;
	com.index_count = index_count;
	com.index_offset = index_offset;
	com.topology = topology;
	com.index_buffer_view = index_buffer_view;
	con.buf_push(&render_commands, com);
}

add_draw_command :: proc(offset: u32, count: u32, topology: platform.D3D12_PRIMITIVE_TOPOLOGY) {
	assert(count != 0);
	com: D12CommandBasicDraw;
	com.count = count;
	com.vertex_offset = offset;
	com.topology = topology;
	con.buf_push(&render_commands, com);
}

add_viewport_command :: proc(vp: enginemath.f4) {
	com: D12CommandViewport;
	com.viewport = vp;
	con.buf_push(&render_commands, com);
}

add_root_signature_command :: proc(root: /*ID3D12RootSignature**/ rawptr) {
	com: D12CommandRootSignature;
	com.root_sig = root;
	con.buf_push(&render_commands, com);
}

add_pipeline_state_command :: proc(ps: /*ID3D12PipelineState**/ rawptr) {
	com: D12CommandPipelineState;
	com.pipeline_state = ps;
	con.buf_push(&render_commands, com);
}

add_scissor_command :: proc(rect: enginemath.f4) {
  com: D12CommandScissorRect;
  com.rect = platform.D3D12_RECT{cast(i32)rect.x, cast(i32)rect.y, cast(i32)rect.z, cast(i32)rect.w};
   con.buf_push(&render_commands, com);
}

//add_start_command_list_command :: proc(handles : ^platform.D3D12_CPU_DESCRIPTOR_HANDLE)
add_start_command_list_basic :: proc(disable_render_target: bool = false) {
   com: D12CommandStartCommandList;
   com.disable_render_target = disable_render_target;
   con.buf_push(&render_commands, com);
}

add_start_command_list_with_render_targets :: proc(render_target_count: int, render_targets: ^platform.D3D12_CPU_DESCRIPTOR_HANDLE) {
   com: D12CommandStartCommandList;
   com.render_targets = render_targets;
   com.render_target_count = render_target_count;
   con.buf_push(&render_commands, com);
}

add_start_command_list_command :: proc{add_start_command_list_basic, add_start_command_list_with_render_targets};

add_end_command_list_command :: proc() {
   com: D12CommandEndCommmandList;
   con.buf_push(&render_commands, com);
}

// TODO(Ray Garner): Replace these with something later
add_graphics_root_desc_table :: proc(index: u64, heaps: /*^ID3D12DescriptorHeap*/ rawptr, gpu_handle: platform.D3D12_GPU_DESCRIPTOR_HANDLE) {
    com: D12CommandGraphicsRootDescTable;
    com.index = index;
    com.heap = heaps;
    com.gpu_handle = gpu_handle;
    con.buf_push(&render_commands, com);
}

add_clear_command :: proc(color: enginemath.f4, render_target: platform.D3D12_CPU_DESCRIPTOR_HANDLE, resourceviewid: u64) {
    com: D12CommandClear;
    com.color = color;
    com.resource_id = resourceviewid;
    com.render_target = render_target;
    con.buf_push(&render_commands, com);
}

add_clear_depth_stencil_command :: proc(clear_depth: bool, depth: f32, clear_stencil: bool, stencil: u8, render_target: ^platform.D3D12_CPU_DESCRIPTOR_HANDLE, resource: rawptr) {
    com: D12CommandDepthStencilClear;
    com.clear_depth = clear_depth;
    com.clear_stencil = clear_stencil;
    com.depth = depth;
    com.stencil = stencil;
    com.resource = resource;
    con.buf_push(&render_commands, com);
}

add_stencil_ref_command :: proc(ref: u32) {
    com: D12CommandSetStencilReference;
    com.ref = ref;
    con.buf_push(&render_commands, com);
}

add_callback_command :: proc(callback : proc(data : rawptr,data2 : rawptr),param_data : $type){
	com : D12CommandCallback;
	com.callback = callback;
	com.data = param_data;
	con.buf_push(&render_commands,com);
}

arena_raw :: struct {
    base: ^u8,
    used: u64,
    size: u64,
}

constants: arena_raw;

arena_init :: proc(size: u64) -> arena_raw {
    result: arena_raw;
    result.base = cast(^u8)mem.alloc(int(size_of(u8) * size), cast(int)align_of(u8));
    result.size = size;
    return result;
}

push_size :: proc(arena_raw: ^arena_raw, size: u64) -> ^u8 {
    offset: u64 = 0; //fmj_arena_get_alignment_offset(arena,params.alignment);    
    result: ^u8 = mem.ptr_offset(arena_raw.base, cast(int)(arena_raw.used + offset));
    arena_raw.used = arena_raw.used + (size + offset);
    return result;
}

arena_clear :: proc(arena: ^arena_raw) {
    arena.used = 0;
}

add_graphics_root32_bit_constant :: proc(index: u32, num_values: u32, gpuptr: rawptr, offset: u32) {
    com: D12CommandGraphicsRoot32BitConstant;
    com.index = index;
    com.num_values = num_values;
    byte_count: u32 = num_values * size_of(u32);
    mem_ptr := push_size(&constants, cast(u64)byte_count);
    mem.copy(cast(rawptr)mem_ptr, gpuptr, cast(int)byte_count);

    com.gpuptr = mem_ptr;
    com.offset = offset;
    con.buf_push(&render_commands, com);
}


get_current_back_buffer_resource_view :: proc() -> ^platform.D12Resource {
    bbi: u32 = platform.GetCurrentBackBufferIndex(swap_chain);
    result := con.buf_ptr(&resourceviews, cast(u64)bbi);
    return result;
}

get_current_back_buffer_resource_view_id :: proc() -> u64 {
    return cast(u64)platform.GetCurrentBackBufferIndex(swap_chain);
}

get_current_back_buffer :: proc() -> rawptr {
    bbi:    u32    = platform.GetCurrentBackBufferIndex(swap_chain);
    result: rawptr = back_buffers[bbi];
    assert(result != nil);
    return result;
}

execute_frame :: proc() {
    using platform;
    using con;
    ticket_mutex_begin(&upload_operations.ticket_mutex);

    current_backbuffer_index := GetCurrentBackBufferIndex(swap_chain);

    if is_resource_cl_recording == true {
		CloseCommandList(resource_cl);
		is_resource_cl_recording = false;
	}

	dsv_cpu_handle: D3D12_CPU_DESCRIPTOR_HANDLE = GetCPUDescriptorHandleForHeapStart(depth_heap.value);
	rtv_cpu_handle: D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device, rtv_descriptor_heap, current_backbuffer_index);

//D12Present the current framebuffer
//Commandbuffer
//    allocator_entry : ^D12CommandAllocatorEntry = get_free_command_allocator_entry(.D3D12_COMMAND_LIST_TYPE_DIRECT);
//    command_list  : D12CommandListEntry = get_associated_command_list(allocator_entry);

/*
//Graphics
back_buffer  :/*ID3D12Resource**/rawptr = get_current_back_buffer();
fc : bool = platform.IsFenceComplete(fence,allocator_entry.fence_value);

assert(fc == true);
ResetCommandAllocator(allocator_entry.allocator);        
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
*/
//D12Rendering
	current_ae: ^D12CommandAllocatorEntry;
	current_cl: D12CommandListEntry;

//    for list in render_command_lists

	for com in render_commands.buffer {
		switch t in com{
		
			case D12CommandClear:{
					//D12Present the current framebuffer
					//Commandbuffer
					ae:           ^D12CommandAllocatorEntry = get_free_command_allocator_entry(.D3D12_COMMAND_LIST_TYPE_DIRECT);
					command_list: D12CommandListEntry       = get_associated_command_list(ae);

					//Graphics
					//        back_buffer  :/* ID3D12Resource**/ rawptr = get_current_back_buffer();
					fc: bool = platform.IsFenceComplete(fence, ae.fence_value);

					assert(fc == true);
					ResetCommandAllocator(ae.allocator);
					ResetCommandList(command_list.list, ae.allocator, nil);

					// Clear the render target.
					resource := con.buf_ptr(&resourceviews, t.resource_id);
					assert(resource.state != nil);
					if t.resource_id == 0 {
						resource.state = get_current_back_buffer();
					}

					transition_resource_request(command_list, resource, .D3D12_RESOURCE_STATE_RENDER_TARGET);

					//        back_buffer_current_state = .D3D12_RESOURCE_STATE_RENDER_TARGET;

					clear_color := t.color; //[4]f32 = { 0.4, 0.6, 0.9,1.0};

					//    dsv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = GetCPUDescriptorHandleForHeapStart(depth_heap.value);
					//        rtv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,rtv_descriptor_heap,current_backbuffer_index);

					//    command_list.list.ClearRenderTargetView(rtv, clearColor, 0, nullptr);
					ClearRenderTargetView(command_list.list, t.render_target, cast([4]f32)clear_color, 0, nil);
					//    command_list.list.ClearDepthStencilView(dsv_cpu_handle, D3D12_CLEAR_FLAG_DEPTH, 1.0f, 0, 0, nullptr);
					//        ClearDepthStencilView(command_list.list,dsv_cpu_handle,.D3D12_CLEAR_FLAG_DEPTH,1.0,0,0,nil);
					//        TransitionResource(command_list,t.resource,.D3D12_RESOURCE_STATE_RENDER_TARGET,.D3D12_RESOURCE_STATE_PRESENT);

					//finish up
					end_command_list_encoding_and_execute(ae, command_list);
					//insert signal in queue to so we know when we have executed up to this point. 
					//which in this case is up to the command clear and tranition back to present transition 
					//for back buffer.
					ae.fence_value = Signal(graphics_command_queue, fence, &fence_value);

					WaitForFenceValue(fence, ae.fence_value, fence_event, max(f64));

					//        ClearDepthStencilView(list.list,dsv_cpu_handle,.D3D12_CLEAR_FLAG_DEPTH,1.0,0,0,nil);            
					continue;
			}

			case D12CommandDepthStencilClear:{
					//D12Present the current framebuffer
					//Commandbuffer
					ae:           ^D12CommandAllocatorEntry = get_free_command_allocator_entry(.D3D12_COMMAND_LIST_TYPE_DIRECT);
					command_list: D12CommandListEntry       = get_associated_command_list(ae);

					//Graphics
					//        back_buffer  :/* ID3D12Resource**/ rawptr = get_current_back_buffer();
					fc: bool = platform.IsFenceComplete(fence, ae.fence_value);

					assert(fc == true);
					ResetCommandAllocator(ae.allocator);
					ResetCommandList(command_list.list, ae.allocator, nil);

					// Clear the render target.

					//        TransitionResource(command_list,t.resource,.D3D12_RESOURCE_STATE_PRESENT,.D3D12_RESOURCE_STATE_RENDER_TARGET);

					//        clearColor : com.color;//[4]f32 = { 0.4, 0.6, 0.9,1.0};

					//    dsv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = GetCPUDescriptorHandleForHeapStart(depth_heap.value);
					//        rtv_cpu_handle : D3D12_CPU_DESCRIPTOR_HANDLE = get_cpu_handle_srv(device,rtv_descriptor_heap,current_backbuffer_index);
					clear_flags: D3D12_CLEAR_FLAGS;
					if t.clear_depth {
						clear_flags |= .D3D12_CLEAR_FLAG_DEPTH;
					}
					if t.clear_stencil {
						clear_flags |= .D3D12_CLEAR_FLAG_STENCIL;
					}

					ClearDepthStencilView(command_list.list, dsv_cpu_handle, clear_flags, t.depth, t.stencil, 0, nil);
					//    command_list.list.ClearRenderTargetView(rtv, clearColor, 0, nullptr);
					//        ClearRenderTargetView(command_list.list,render_target,clearColor,0,nil);
					//    command_list.list.ClearDepthStencilView(dsv_cpu_handle, D3D12_CLEAR_FLAG_DEPTH, 1.0f, 0, 0, nullptr);
					//        ClearDepthStencilView(command_list.list,dsv_cpu_handle,.D3D12_CLEAR_FLAG_DEPTH,1.0,0,0,nil);
					//      TransitionResource(command_list,t.resource,.D3D12_RESOURCE_STATE_RENDER_TARGET,.D3D12_RESOURCE_STATE_PRESENT);                        
					//finish up
					end_command_list_encoding_and_execute(ae, command_list);
					//insert signal in queue to so we know when we have executed up to this point. 
					//which in this case is up to the command clear and tranition back to present transition 
					//for back buffer.

					ae.fence_value = Signal(graphics_command_queue, fence, &fence_value);

					WaitForFenceValue(fence, ae.fence_value, fence_event, max(f64));

					continue;
			}

			case D12CommandStartCommandList:{
					current_ae = get_free_command_allocator_entry(.D3D12_COMMAND_LIST_TYPE_DIRECT);

					current_cl = get_associated_command_list(current_ae);
					fcgeo: bool = platform.IsFenceComplete(fence, current_ae.fence_value);
					assert(fcgeo == true);

					ResetCommandAllocator(current_ae.allocator);
					ResetCommandList(current_cl.list, current_ae.allocator, nil);

					if t.render_target_count > 0 {
						OMSetRenderTargets(current_cl.list, cast(u32)t.render_target_count, t.render_targets, false, &dsv_cpu_handle);
					} else
					// if t.disable_render_target == false
					{
						OMSetRenderTargets(current_cl.list, 1, &rtv_cpu_handle, false, &dsv_cpu_handle);
					}
					//        else
					{
						//            fmt.println("No render target enabled on this command list.");
					}

					continue;
			}

			case D12CommandEndCommmandList:{
					// NOTE(Ray Garner): For now we do this here but we need to do something else  setting render targets.

					//End D12 Renderering
					end_command_list_encoding_and_execute(current_ae, current_cl);
					current_ae.fence_value = Signal(graphics_command_queue, fence, &fence_value);
					// NOTE(Ray Garner): // TODO(Ray Garner): If there are dependencies from the last command list we need to enter a waitforfence value
					//so that we can finish executing this command list before and have the result ready for the next one.
					//If not we dont need to worry about this.

					//wait for the gpu to execute up until this point before we procede this is the allocators..
					//current fence value which we got when we signaled. 
					//the fence value that we give to each allocator is based on the fence value for the queue.
					WaitForFenceValue(fence, current_ae.fence_value, fence_event, max(f64));
					buf_clear(&current_ae.used_list_indexes);
					continue;
			}
			case D12CommandSetStencilReference: {
					command := com.(D12CommandSetStencilReference);
					OMSetStencilRef(current_cl.list, command.ref);
					continue;

			}
			case D12CommandBasicDraw:{
					command := com.(D12CommandBasicDraw);
					IASetPrimitiveTopology(current_cl.list, command.topology);
					DrawInstanced(current_cl.list, command.count, 1, command.vertex_offset, 0);
					continue;

			}

			case D12CommandIndexedDraw:{
					command := com.(D12CommandIndexedDraw);
					IASetIndexBuffer(current_cl.list, &command.index_buffer_view);
					// NOTE(Ray Garner): // TODO(Ray Garner): Get the heaps
					//that match with the pipeline state and root sig
					IASetPrimitiveTopology(current_cl.list, command.topology);
					DrawIndexedInstanced(current_cl.list, command.index_count, 1, command.index_offset, 0, 0);
					continue;
			}

			case D12CommandSetVertexBuffer:{
					command := com.(D12CommandSetVertexBuffer);
					IASetVertexBuffers(current_cl.list, command.slot, 1, &command.buffer_view);
					continue;
			}

			case D12CommandViewport:{
					command := com.(D12CommandViewport);
					new_viewport: D3D12_VIEWPORT = {0, 0, command.viewport.z, command.viewport.w, 0, 1};
					RSSetViewports(current_cl.list, 1, &new_viewport);

					continue;
			}

			case D12CommandRootSignature:{
					command := com.(D12CommandRootSignature);
					SetGraphicsRootSignature(current_cl.list, command.root_sig);
					continue;

			}

			case D12CommandPipelineState:{
					command := com.(D12CommandPipelineState);
					assert(command.pipeline_state != nil);
					SetPipelineState(current_cl.list, command.pipeline_state);
					continue;
			}

			case D12CommandScissorRect:{
					command := com.(D12CommandScissorRect);
					RSSetScissorRects(current_cl.list, 1, &command.rect);
					continue;
			}

			case D12CommandGraphicsRootDescTable:{
					command := com.(D12CommandGraphicsRootDescTable);

					descriptorHeaps: []rawptr = {command.heap};
					SetDescriptorHeaps(current_cl.list, 1, mem.raw_slice_data(descriptorHeaps[:]));
					SetGraphicsRootDescriptorTable(current_cl.list, cast(u32)command.index, command.gpu_handle);
					continue;

			}

			case D12CommandGraphicsRoot32BitConstant:{
					command := com.(D12CommandGraphicsRoot32BitConstant);

					SetGraphicsRoot32BitConstants(current_cl.list, command.index, command.num_values, command.gpuptr, command.offset);
					continue;
			}

			case D12RenderTargets:{
				continue;
			}
			case D12CommandCallback:{
				command := com.(D12CommandCallback);
				command.callback(current_cl.list,command.data);
				continue;
			}
			case:{continue;}

		}
	}
	

	final_allocator_entry: ^platform.D12CommandAllocatorEntry = get_free_command_allocator_entry(.D3D12_COMMAND_LIST_TYPE_DIRECT);
	final_command_list:    D12CommandListEntry                = get_associated_command_list(final_allocator_entry);

	final_fc: bool = platform.IsFenceComplete(fence, final_allocator_entry.fence_value);
	assert(final_fc == true);
	ResetCommandAllocator(final_allocator_entry.allocator);
	ResetCommandList(final_command_list.list, final_allocator_entry.allocator, nil);

	cbb: rawptr = get_current_back_buffer();

	OMSetRenderTargets(final_command_list.list, 1, &rtv_cpu_handle, false, &dsv_cpu_handle);

	cbb_resource_view := get_current_back_buffer_resource_view();
	//tranistion the render target back to present mode. preparing for presentation.

	//    TransitionResource(final_command_list,cbb,.D3D12_RESOURCE_STATE_RENDER_TARGET,.D3D12_RESOURCE_STATE_PRESENT);
	transition_resource_request(final_command_list, cbb_resource_view, .D3D12_RESOURCE_STATE_PRESENT);

	//finish up
	end_command_list_encoding_and_execute(final_allocator_entry, final_command_list);

	//insert signal in queue to so we know when we have executed up to this point. 
	//which in this case is up to the command clear and tranition back to present transition 
	//for back buffer.
	final_allocator_entry.fence_value = Signal(graphics_command_queue, fence, &fence_value);
	WaitForFenceValue(fence, final_allocator_entry.fence_value, fence_event, max(f64));

	//execute the present flip
	sync_interval: windows.UINT;
	present_flags: windows.UINT = DXGI_PRESENT_ALLOW_TEARING;
	Present(swap_chain, sync_interval, present_flags);

	//wait for the gpu to execute up until this point before we procede this is the allocators..
	//current fence value which we got when we signaled. 
	//the fence value that we give to each allocator is based on the fence value for the queue.
	//D12RendererCode::WaitForFenceValue(fence, allocator_entry.fence_value, fence_event);
	//    buf_clear(&allocator_entry.used_list_indexes);

	is_resource_cl_recording = false;
	// NOTE(Ray Garner): Here we are doing bookkeeping for resuse of various resources.
	//If the allocators are not in flight add them to the free table
	check_reuse_command_allocators();
	ticket_mutex_end(&upload_operations.ticket_mutex);

	//Reset state of constant buffer
	//fmj_arena_deallocate(&constants_arena,false);
	buf_clear(&render_commands);
	arena_clear(&constants);
}
