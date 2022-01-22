// dear imgui: Renderer Backend for DirectX12
// This needs to be used along with a Platform Backend (e.g. Win32)

// Implemented features:
//  [X] Renderer: User texture binding. Use 'D3D12_GPU_DESCRIPTOR_HANDLE' as ImTextureID. Read the FAQ about ImTextureID!
//  [X] Renderer: Support for large meshes (64k+ vertices) with 16-bit indices.

// Important: to compile on 32-bit systems, this backend requires code to be compiled with '#define ImTextureID ImU64'.
// This is because we need ImTextureID to carry a 64-bit value and by default ImTextureID is defined as void*.
// This define is set in the example .vcxproj file and need to be replicated in your app or by adding it to your imconfig.h file.

// You can copy and use unmodified imgui_impl_* files in your project. See examples/ folder for examples of using this.
// If you are new to Dear ImGui, read documentation from the docs/ folder + read the top of imgui.cpp.
// Read online: https://github.com/ocornut/imgui/tree/master/docs

// CHANGELOG
// (minor and older changes stripped away, please see git history for details)
//  2021-02-18: DirectX12: Change blending equation to preserve alpha in output buffer.
//  2021-01-11: DirectX12: Improve Windows 7 compatibility (for D3D12On7) by loading d3d12.dll dynamically.
//  2020-09-16: DirectX12: Avoid rendering calls with zero-sized scissor rectangle since it generates a validation layer warning.
//  2020-09-08: DirectX12: Clarified support for building on 32-bit systems by redefining ImTextureID.
//  2019-10-18: DirectX12: *BREAKING CHANGE* Added extra ID3D12DescriptorHeap parameter to ImGui_ImplDX12_Init() function.
//  2019-05-29: DirectX12: Added support for large mesh (64K+ vertices), enable ImGuiBackendFlags_RendererHasVtxOffset flag.
//  2019-04-30: DirectX12: Added support for special ImDrawCallback_ResetRenderState callback to reset render state.
//  2019-03-29: Misc: Various minor tidying up.
//  2018-12-03: Misc: Added #pragma comment statement to automatically link with d3dcompiler.lib when using D3DCompile().
//  2018-11-30: Misc: Setting up io.BackendRendererName so it can be displayed in the About Window.
//  2018-06-12: DirectX12: Moved the ID3D12GraphicsCommandList* parameter from NewFrame() to RenderDrawData().
//  2018-06-08: Misc: Extracted imgui_impl_dx12.cpp/.h away from the old combined DX12+Win32 example.
//  2018-06-08: DirectX12: Use draw_data.DisplayPos and draw_data.DisplaySize to setup projection matrix and clipping rectangle (to ease support for future multi-viewport).
//  2018-02-22: Merged into master with all Win32 code synchronized to other examples.

//#include "imgui.h"
//#include "imgui_impl_dx12.h"
package graphics
import imgui "../external/odin-imgui"
import platform "../platform"
import "core:c"
import "core:mem"
import win32 "core:sys/win32"
import "core:runtime"
import "core:intrinsics"
// DirectX
//#include <d3d12.h>
//#include <dxgi1_4.h>
//#include <d3dcompiler.h>
//#ifdef _MSC_VER
//#pragma comment(lib, "d3dcompiler") // Automatically link with d3dcompiler.lib as we are using D3DCompile() below.
//#endif

// DirectX data
g_pd3dDevice:            rawptr = nil;
g_pRootSignature:        rawptr;
g_pPipelineState:        rawptr;
g_RTVFormat:             platform.DXGI_FORMAT;
g_pFontTextureResource:  rawptr;
g_hFontSrvCpuDescHandle: platform.D3D12_CPU_DESCRIPTOR_HANDLE;
g_hFontSrvGpuDescHandle: platform.D3D12_GPU_DESCRIPTOR_HANDLE;

//static ID3D12RootSignature*         g_pRootSignature = NULL;
//static ID3D12PipelineState*         g_pPipelineState = NULL;
//static DXGI_FORMAT                  g_RTVFormat = DXGI_FORMAT_UNKNOWN;
//static ID3D12Resource*              g_pFontTextureResource = NULL;
//static D3D12_CPU_DESCRIPTOR_HANDLE  g_hFontSrvCpuDescHandle = {};
//static D3D12_GPU_DESCRIPTOR_HANDLE  g_hFontSrvGpuDescHandle = {};

FrameResources :: struct {
	index_buffer:       rawptr,
	vertex_buffer:      rawptr,
	index_buffer_size:  int,
	vertex_buffer_size: int,
	//ID3D12Resource*     IndexBuffer;
	//ID3D12Resource*     VertexBuffer;
	//int                 IndexBufferSize;
	//int                 VertexBufferSize;
}
g_p_frame_resources:    FrameResources;
g_num_frames_in_flight: uint;
g_frame_index:          uint;

g_pFrameResources:   [dynamic]FrameResources;
g_numFramesInFlight: c.uint = 0;
g_frameIndex:        c.uint = max(c.uint);

//template<typename T>
//static void SafeRelease(T*& res)
//{
//   if (res)
//       res.Release();
//   res = NULL;
//}

VERTEX_CONSTANT_BUFFER :: struct {
	mvp: [4][4]f32,
}

ImGui_ImplDX12_SetupRenderState :: proc(draw_data: ^imgui.Draw_Data, ctx_list: rawptr, fr: ^FrameResources) {
	using platform;

	// Setup orthographic projection matrix into our constant buffer
	// Our visible imgui space lies from draw_data.DisplayPos (top left) to draw_data.DisplayPos+data_data.DisplaySize (bottom right).
	vertex_constant_buffer: VERTEX_CONSTANT_BUFFER;
	
	L:   f32       = draw_data.display_pos.x;
	R:   f32       = draw_data.display_pos.x + draw_data.display_size.x;
	T:   f32       = draw_data.display_pos.y;
	B:   f32       = draw_data.display_pos.y + draw_data.display_size.y;
	
	/*
	mvp: [4][4]f32 = {
		{2.0 / (R - L), 0.0, 0.0, 0.0},
		{0.0, 2.0 / (T - B), 0.0, 0.0},
		{0.0, 0.0, 0.5, 0.0},
		{(R + L) / (L - R), (T + B) / (B - T), 0.5, 1.0},
	};
*/

	mvp: [4][4]f32 = {
		{2.0 / (R - L), 0.0, 0.0, -1},
		{0.0, 2.0 / (T - B), 0.0, 1},
		{0.0, 0.0, 0.5, 0.0},
		{0, 0,0, 1.0},
	};

	mem.copy(&vertex_constant_buffer.mvp, mem.raw_slice_data(mvp[:]), size_of(mvp));

	// Setup viewport
	vp: platform.D3D12_VIEWPORT;
	mem.set(&vp, 0, size_of(D3D12_VIEWPORT));
	vp.Width = draw_data.display_size.x;
	vp.Height = draw_data.display_size.y;
	vp.MinDepth = 0.0;
	vp.MaxDepth = 1.0;
	vp.TopLeftX = 0.0;
	vp.TopLeftY = 0.0;

	RSSetViewports(ctx_list, 1, &vp);

	// Bind shader and vertex buffers
	//unsigned int stride = size_of(ImDrawVert);
	stride := size_of(imgui.Draw_Vert);
	offset: int = 0;
	vbv:    platform.D3D12_VERTEX_BUFFER_VIEW;
	//mem.set(&vbv, 0, size_of(D3D12_VERTEX_BUFFER_VIEW));
	vbv.BufferLocation = GetGPUVirtualAddress(fr.vertex_buffer) + cast(u64)offset;
	vbv.SizeInBytes = cast(u32)fr.vertex_buffer_size * cast(u32)stride;
	vbv.StrideInBytes = cast(u32)stride;
	IASetVertexBuffers(ctx_list, 0, 1, &vbv);
	//ctx.IASetVertexBuffers(0, 1, &vbv);
	ibv: platform.D3D12_INDEX_BUFFER_VIEW;
	//mem.set(&ibv, 0, size_of(D3D12_INDEX_BUFFER_VIEW));
	ibv.BufferLocation = GetGPUVirtualAddress(fr.index_buffer);
	ibv.SizeInBytes = cast(u32)(fr.index_buffer_size * size_of(imgui.Draw_Idx));
	ibv.Format = size_of(imgui.Draw_Idx) == 2  ? .DXGI_FORMAT_R16_UINT : .DXGI_FORMAT_R32_UINT;
	IASetIndexBuffer(ctx_list, &ibv);
	IASetPrimitiveTopology(ctx_list, .D3D_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
	SetPipelineState(ctx_list, g_pPipelineState);
	SetGraphicsRootSignature(ctx_list, g_pRootSignature);
	SetGraphicsRoot32BitConstants(ctx_list, 0, 16, &vertex_constant_buffer, 0);

	// Setup blend factor
	blend_factor: [4]f32 = {0, 0, 0, 0};
	OMSetBlendFactor(ctx_list, blend_factor);
}

// Render function
ImGui_ImplDX12_RenderDrawData :: proc(draw_data: ^imgui.Draw_Data, ctx_list: rawptr) {
	// Avoid rendering when minimized
	if draw_data.display_size.x <= 0.0 || draw_data.display_size.y <= 0.0 {
		return;
	}

	// FIXME: I'm assuming that this only gets called once per frame!                       // FIXME: I'm assuming that this only gets called once per frame!
	// If not, we can't just re-allocate the IB or VB, we'll have to do a proper allocator. // If not, we can't just re-allocate the IB or VB, we'll have to do a proper allocator.
	g_frameIndex = g_frameIndex + 1;
	fr := &g_pFrameResources[g_frameIndex % g_numFramesInFlight];

	// Create and grow vertex/index buffers if needed
	if fr.vertex_buffer == nil || cast(bool)(cast(i32)fr.vertex_buffer_size < draw_data.total_vtx_count) {
		//SafeRelease(fr.VertexBuffer);
		fr.vertex_buffer_size = cast(int)(draw_data.total_vtx_count + 5000);
		props: platform.D3D12_HEAP_PROPERTIES;
		//mem.set(&props, 0, size_of(platform.D3D12_HEAP_PROPERTIES));
		props.Type = .D3D12_HEAP_TYPE_UPLOAD;
		props.CPUPageProperty = .D3D12_CPU_PAGE_PROPERTY_UNKNOWN;
		props.MemoryPoolPreference = .D3D12_MEMORY_POOL_UNKNOWN;
		desc: platform.D3D12_RESOURCE_DESC;
		//mem.set(&desc, 0, size_of(platform.D3D12_RESOURCE_DESC));
		desc.Dimension = .D3D12_RESOURCE_DIMENSION_BUFFER;
		desc.Width = cast(u64)(fr.vertex_buffer_size * size_of(imgui.Draw_Vert));
		desc.Height = 1;
		desc.DepthOrArraySize = 1;
		desc.MipLevels = 1;
		desc.Format = .DXGI_FORMAT_UNKNOWN;
		desc.SampleDesc.Count = 1;
		desc.Layout = .D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
		desc.Flags = .D3D12_RESOURCE_FLAG_NONE;
		if CreateCommittedResource(g_pd3dDevice, &props, .D3D12_HEAP_FLAG_NONE, &desc, .D3D12_RESOURCE_STATE_GENERIC_READ, nil, (&fr.vertex_buffer)) < 0 {
			return;
		}
	}
	if fr.index_buffer == nil || (cast(i32)fr.index_buffer_size < draw_data.total_idx_count) {
		//        SafeRelease(fr.IndexBuffer); //        SafeRelease(fr.IndexBuffer);
		fr.index_buffer_size = cast(int)(draw_data.total_idx_count + 10000);
		props: platform.D3D12_HEAP_PROPERTIES;
		//mem.set(&props, 0, size_of(platform.D3D12_HEAP_PROPERTIES));
		props.Type = .D3D12_HEAP_TYPE_UPLOAD;
		props.CPUPageProperty = .D3D12_CPU_PAGE_PROPERTY_UNKNOWN;
		props.MemoryPoolPreference = .D3D12_MEMORY_POOL_UNKNOWN;
		desc: platform.D3D12_RESOURCE_DESC;
		//mem.set(&desc, 0, size_of(platform.D3D12_RESOURCE_DESC));
		desc.Dimension = .D3D12_RESOURCE_DIMENSION_BUFFER;
		desc.Width = cast(u64)(fr.index_buffer_size * size_of(imgui.Draw_Idx));
		desc.Height = 1;
		desc.DepthOrArraySize = 1;
		desc.MipLevels = 1;
		desc.Format = .DXGI_FORMAT_UNKNOWN;
		desc.SampleDesc.Count = 1;
		desc.Layout = .D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
		desc.Flags = .D3D12_RESOURCE_FLAG_NONE;
		if CreateCommittedResource(g_pd3dDevice, &props, .D3D12_HEAP_FLAG_NONE, &desc, .D3D12_RESOURCE_STATE_GENERIC_READ, nil, (&fr.index_buffer)) < 0 {
			return;
		}
	}

	using platform;
	// Upload vertex/index data into a single contiguous GPU buffer
	vtx_resource: rawptr;
	idx_resource: rawptr;
	range:        platform.D3D12_RANGE;
	//mem.set(&range, 0, size_of(D3D12_RANGE));
	if Map(fr.vertex_buffer, 0, &range, &vtx_resource) != S_OK {
		return;
	}

	if Map(fr.index_buffer, 0, &range, &idx_resource) != S_OK {
		return;
	}
	vtx_dst: ^imgui.Draw_Vert = cast(^imgui.Draw_Vert)vtx_resource;
	idx_dst: ^imgui.Draw_Idx  = cast(^imgui.Draw_Idx)idx_resource;

	vtx_resource_base := vtx_dst;
	idx_resource_base := idx_dst;
	lists             := mem.slice_ptr(draw_data.cmd_lists, int(draw_data.cmd_lists_count));
	i                 := 0;
	for list in lists {
		mem.copy(vtx_dst, list.vtx_buffer.data, int(list.vtx_buffer.size) * size_of(imgui.Draw_Vert));
		mem.copy(idx_dst, list.idx_buffer.data, int(list.idx_buffer.size) * size_of(imgui.Draw_Idx));
		//vtx_dst = (^imgui.Draw_Vert)(uintptr(vtx_dst) + uintptr(list.vtx_buffer.size) * size_of(imgui.Draw_Vert));
		//idx_dst = (^imgui.Draw_Idx)(uintptr(idx_dst) + uintptr(list.idx_buffer.size) * size_of(imgui.Draw_Idx));
		
		vtx_dst = mem.ptr_offset(vtx_dst,cast(int)list.vtx_buffer.size);
		idx_dst = mem.ptr_offset(idx_dst,cast(int)list.idx_buffer.size);
		//idx_dst = cast(^imgui.Draw_Idx)(uintptr(idx_resource_base) + uintptr(list.idx_buffer.size) * size_of(imgui.Draw_Idx));//mem.ptr_offset(vtx_resource_base, i);
		i += 1;
	}
	Unmap(fr.vertex_buffer, 0, &range);
	Unmap(fr.index_buffer, 0, &range);

	// Setup desired DX state
	ImGui_ImplDX12_SetupRenderState(draw_data, ctx_list, fr);

	// Render command lists
	// (Because we merged all buffers into a single one, we maintain our own offset into them)
	global_vtx_offset: int        = 0;
	global_idx_offset: int        = 0;
	clip_off:          imgui.Vec2 = draw_data.display_pos;
	for list in lists {
		//for n := 0; n < draw_data.CmdListsCount; n+=1{

		//const ImDrawList* cmd_list = draw_data.CmdLists[n];
		//for cmd_i := 0; cmd_i < cast(int)list.cmd_buffer.size; cmd_i+=1 {
		//const ImDrawCmd* pcmd = &cmd_list.CmdBuffer[cmd_i];
		cmds := mem.slice_ptr(list.cmd_buffer.data, int(list.cmd_buffer.size));
		for cmd, idx in cmds {
			if cmd.user_callback != nil {
			// User callback, registered via ImDrawList::AddCallback()
			// User callback, registered via ImDrawList::AddCallback()
			// (ImDrawCallback_ResetRenderState is a special callback value used by the user to request the renderer to reset render state.) 
			// (ImDrawCallback_ResetRenderState is a special callback value used by the user to request the renderer to reset render state.)
			//if cmd.user_callback == Im{
			//if cmd.user_callback == Im{
			//ImGui_ImplDX12_SetupRenderState(draw_data, ctx_list, fr); 
			//ImGui_ImplDX12_SetupRenderState(draw_data, ctx_list, fr);
			//}                                                                                                                              
			//}
			//{                                                                                                                              
			//{
				cmd.user_callback(list, &cmds[idx]);
				//}
			} else {
				// Apply Scissor, Bind texture, Draw
				r: platform.D3D12_RECT = {(c.long)(cmd.clip_rect.x - clip_off.x), (c.long)(cmd.clip_rect.y - clip_off.y), (c.long)(cmd.clip_rect.z - clip_off.x), (c.long)(cmd.clip_rect.w - clip_off.y)};
				if r.right > r.left && r.bottom > r.top {
					//SetGraphicsRootDescriptorTable(ctx_list,1, (cast(^platform.D3D12_GPU_DESCRIPTOR_HANDLE)&cmd.texture_id)^); //SetGraphicsRootDescriptorTable(ctx_list,1, (cast(^platform.D3D12_GPU_DESCRIPTOR_HANDLE)&cmd.texture_id)^);
					SetGraphicsRootDescriptorTable(ctx_list, 1, transmute(platform.D3D12_GPU_DESCRIPTOR_HANDLE)cmd.texture_id);
					RSSetScissorRects(ctx_list, 1, &r);
					DrawIndexedInstanced(ctx_list, cmd.elem_count, 1, cast(u32)(cmd.idx_offset + cast(u32)global_idx_offset), cast(i32)(cmd.vtx_offset + cast(u32)global_vtx_offset), 0);
				}
			}
		}

		global_idx_offset += cast(int)list.idx_buffer.size; //.IdxBuffer.Size;
		global_vtx_offset += cast(int)list.vtx_buffer.size; //.VtxBuffer.Size;
	}
}

ImGui_ImplDX12_CreateFontsTexture :: proc() {
	// Build texture atlas
	io:     ^imgui.IO = imgui.get_io();
	pixels: ^u8;
	width:  i32;
	height: i32;
	//io.Fonts.GetTexDataAsRGBA32(&pixels, &width, &height);
	imgui.font_atlas_get_tex_data_as_rgba32(io.fonts, &pixels, &width, &height);

	//imgui.font_atlas_get_tex_data_as_rgba32(&pixels,&width,&height);
	// Upload texture to graphics system
	{
		using platform;
		props: platform.D3D12_HEAP_PROPERTIES;
		mem.set(&props, 0, size_of(D3D12_HEAP_PROPERTIES));
		props.Type = .D3D12_HEAP_TYPE_DEFAULT;
		props.CPUPageProperty = .D3D12_CPU_PAGE_PROPERTY_UNKNOWN;
		props.MemoryPoolPreference = .D3D12_MEMORY_POOL_UNKNOWN;

		desc: platform.D3D12_RESOURCE_DESC;
		//ZeroMemory(&desc, size_of(desc));
		desc.Dimension = .D3D12_RESOURCE_DIMENSION_TEXTURE2D;
		desc.Alignment = 0;
		desc.Width = cast(u64)width;
		desc.Height = cast(u32)height;
		desc.DepthOrArraySize = 1;
		desc.MipLevels = 1;
		desc.Format = .DXGI_FORMAT_R8G8B8A8_UNORM;
		desc.SampleDesc.Count = 1;
		desc.SampleDesc.Quality = 0;
		desc.Layout = .D3D12_TEXTURE_LAYOUT_UNKNOWN;
		desc.Flags = .D3D12_RESOURCE_FLAG_NONE;

		pTexture: rawptr = nil; //D3D12_RANGE ;
		CreateCommittedResource(g_pd3dDevice, &props, .D3D12_HEAP_FLAG_NONE, &desc, .D3D12_RESOURCE_STATE_COPY_DEST, nil, &pTexture);

		uploadPitch: c.uint = cast(u32)(width * 4 + platform.D3D12_TEXTURE_DATA_PITCH_ALIGNMENT - 1) & ~cast(u32)(platform.D3D12_TEXTURE_DATA_PITCH_ALIGNMENT - 1);
		uploadSize:  c.uint = cast(c.uint)(cast(u32)height * uploadPitch);
		desc.Dimension = .D3D12_RESOURCE_DIMENSION_BUFFER;
		desc.Alignment = 0;
		desc.Width = cast(u64)uploadSize;
		desc.Height = 1;
		desc.DepthOrArraySize = 1;
		desc.MipLevels = 1;
		desc.Format = .DXGI_FORMAT_UNKNOWN;
		desc.SampleDesc.Count = 1;
		desc.SampleDesc.Quality = 0;
		desc.Layout = .D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
		desc.Flags = .D3D12_RESOURCE_FLAG_NONE;

		props.Type = .D3D12_HEAP_TYPE_UPLOAD;
		props.CPUPageProperty = .D3D12_CPU_PAGE_PROPERTY_UNKNOWN;
		props.MemoryPoolPreference = .D3D12_MEMORY_POOL_UNKNOWN;

		uploadBuffer: rawptr = nil;
		hr := CreateCommittedResource(g_pd3dDevice, &props, .D3D12_HEAP_FLAG_NONE, &desc, .D3D12_RESOURCE_STATE_GENERIC_READ, nil, &uploadBuffer);
		//IM_ASSERT(SUCCEEDED(hr));

		mapped: rawptr               = nil;
		range:  platform.D3D12_RANGE = {0, cast(uint)uploadSize};
		hr = Map(uploadBuffer, 0, &range, &mapped);
		//IM_ASSERT(SUCCEEDED(hr));
		for y: i32 = 0; y < height; y += 1 {
			mapped_ := cast(^u8)mapped;
			//mem.copy((void*) ((uintptr_t) mapped + y * uploadPitch), pixels + y * width * 4, width * 4);
			mem.copy(mem.ptr_offset(mapped_, int(cast(u32)y * cast(u32)uploadPitch)), mem.ptr_offset(pixels, int(y * width * 4)), int(width * 4)); // mapped_ + y * uploadPitch)
		}
		Unmap(uploadBuffer, 0, &range);

		srcLocation: platform.D3D12_TEXTURE_COPY_LOCATION = {};
		srcLocation.pResource = uploadBuffer;
		srcLocation.Type = .D3D12_TEXTURE_COPY_TYPE_PLACED_FOOTPRINT;
		srcLocation.copy_union.PlacedFootprint.Footprint.Format = .DXGI_FORMAT_R8G8B8A8_UNORM;
		srcLocation.copy_union.PlacedFootprint.Footprint.Width = cast(u32)width;
		srcLocation.copy_union.PlacedFootprint.Footprint.Height = cast(u32)height;
		srcLocation.copy_union.PlacedFootprint.Footprint.Depth = 1;
		srcLocation.copy_union.PlacedFootprint.Footprint.RowPitch = uploadPitch;

		dstLocation: platform.D3D12_TEXTURE_COPY_LOCATION;
		dstLocation.pResource = pTexture;
		dstLocation.Type = .D3D12_TEXTURE_COPY_TYPE_SUBRESOURCE_INDEX;
		dstLocation.copy_union.SubresourceIndex = 0;

		barrier: platform.D3D12_RESOURCE_BARRIER;
		barrier.Type = .D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
		barrier.Flags = .D3D12_RESOURCE_BARRIER_FLAG_NONE;
		barrier.barrier_union.Transition.pResource = pTexture;
		barrier.barrier_union.Transition.Subresource = platform.D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
		barrier.barrier_union.Transition.StateBefore = .D3D12_RESOURCE_STATE_COPY_DEST;
		barrier.barrier_union.Transition.StateAfter = .D3D12_RESOURCE_STATE_PIXEL_SHADER_RESOURCE;

		fence: rawptr = /*ID3D12Fence**/ nil;
		fence = CreateFence(g_pd3dDevice); //,0, .D3D12_FENCE_FLAG_NONE, &fence);
		                                   //IM_ASSERT(SUCCEEDED(hr));

		event := CreateEventHandle();
		//IM_ASSERT(event != NULL);

		//queueDesc : platform.D3D12_COMMAND_QUEUE_DESC;
		//queueDesc.Type     = .D3D12_COMMAND_LIST_TYPE_DIRECT;
		//queueDesc.Flags    = .D3D12_COMMAND_QUEUE_FLAG_NONE;
		//queueDesc.NodeMask = 1;

		//cmdQueue : rawptr= nil;//ID3D12CommandQueue* 
		cmdQueue := CreateCommandQueue(g_pd3dDevice, .D3D12_COMMAND_LIST_TYPE_DIRECT);
		//IM_ASSERT(SUCCEEDED(hr));

		//cmdAlloc : rawptr = nil;//ID3D12CommandAllocator* 
		cmdAlloc := CreateCommandAllocator(g_pd3dDevice, .D3D12_COMMAND_LIST_TYPE_DIRECT);
		//IM_ASSERT(SUCCEEDED(hr));

		//cmdList : rawptr = nil;//ID3D12GraphicsCommandList* = NULL;
		cmdList := CreateCommandList(g_pd3dDevice, cmdAlloc, .D3D12_COMMAND_LIST_TYPE_DIRECT);
		//IM_ASSERT(SUCCEEDED(hr));
		ResetCommandAllocator(cmdAlloc);
		ResetCommandList(cmdList, cmdAlloc, nil);

		CopyTextureRegion(cmdList,&dstLocation, 0, 0, 0, &srcLocation, nil);
		ResourceBarrier(cmdList,1, &barrier);


		hr = CloseCommandList(cmdList);
		if hr != S_OK{
			assert(false);
		}
		//IM_ASSERT(SUCCEEDED(hr));
		command_lists: []rawptr = {
			cmdList,
		};
		//cmdQueue.ExecuteCommandLists(1, (ID3D12CommandList* const*)&cmdList);
		ExecuteCommandLists(cmdQueue,mem.raw_slice_data(command_lists[:]), 1);
	
		//hr = cmdQueue.Signal(fence, 1);
		
		fence_value := SignalCommandQueue(cmdQueue, fence, 1);
		//IM_ASSERT(SUCCEEDED(hr));

		SetEventOnCompletion(fence,1,event);
		//fence.SetEventOnCompletion(1, event);
		WaitForSingleObject(event, win32.INFINITE);


		//cmdList.Release();
		//cmdAlloc.Release();
		//cmdQueue.Release();
		
		//CloseHandle(event);
		//fence.Release();
		//uploadBuffer.Release();

		// Create texture view
		srvDesc: platform.D3D12_SHADER_RESOURCE_VIEW_DESC;
		//ZeroMemory(&srvDesc, size_of(srvDesc));
		srvDesc.Format = .DXGI_FORMAT_R8G8B8A8_UNORM;
		srvDesc.ViewDimension = .D3D12_SRV_DIMENSION_TEXTURE2D;
		srvDesc.Buffer.Texture2D.MipLevels = cast(u32)desc.MipLevels;
		srvDesc.Buffer.Texture2D.MostDetailedMip = 0;
		srvDesc.Shader4ComponentMapping = platform.D3D12_ENCODE_SHADER_4_COMPONENT_MAPPING(0, 1, 2, 3);
		CreateShaderResourceView(g_pd3dDevice,pTexture, &srvDesc, g_hFontSrvCpuDescHandle);
		//SafeRelease(g_pFontTextureResource);
		g_pFontTextureResource = pTexture;
	}

	// Store our identifier
	//static_assert(size_of(ImTextureID) >= size_of(g_hFontSrvGpuDescHandle.ptr), "Can't pack descriptor handle into TexID, 32-bit not supported yet.");
	//io.Fonts.SetTexID((ImTextureID)g_hFontSrvGpuDescHandle.ptr);
	imgui.font_atlas_set_tex_id(io.fonts,transmute(imgui.Texture_ID)g_hFontSrvGpuDescHandle.ptr);
}

ImGui_ImplDX12_CreateDeviceObjects :: proc() -> bool {
	if g_pd3dDevice == nil {
		return false;
	}
	if g_pPipelineState != nil {
		ImGui_ImplDX12_InvalidateDeviceObjects();
	}

	// Create the root signature // Create the root signature
	{
		descRange: platform.D3D12_DESCRIPTOR_RANGE1;
		descRange.RangeType = .D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
		descRange.NumDescriptors = 1;
		descRange.BaseShaderRegister = 0;
		descRange.RegisterSpace = 0;
		descRange.OffsetInDescriptorsFromTableStart = 0;

		param: [2]platform.D3D12_ROOT_PARAMETER1;

		param[0].ParameterType = .D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;

		param[0].root_parameter1_union.Constants.ShaderRegister = 0;
		param[0].root_parameter1_union.Constants.RegisterSpace = 0;
		param[0].root_parameter1_union.Constants.Num32BitValues = 16;
		param[0].ShaderVisibility = .D3D12_SHADER_VISIBILITY_VERTEX;

		param[1].ParameterType = .D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
		param[1].root_parameter1_union.DescriptorTable.NumDescriptorRanges = 1;
		param[1].root_parameter1_union.DescriptorTable.pDescriptorRanges = &descRange;
		param[1].ShaderVisibility = .D3D12_SHADER_VISIBILITY_PIXEL;

		staticSampler: platform.D3D12_STATIC_SAMPLER_DESC;
		staticSampler.Filter = .D3D12_FILTER_MIN_MAG_MIP_POINT;
		staticSampler.AddressU = .D3D12_TEXTURE_ADDRESS_MODE_WRAP;
		staticSampler.AddressV = .D3D12_TEXTURE_ADDRESS_MODE_WRAP;
		staticSampler.AddressW = .D3D12_TEXTURE_ADDRESS_MODE_WRAP;
		staticSampler.MipLODBias = 0;
		staticSampler.MaxAnisotropy = 0;
		staticSampler.ComparisonFunc = .D3D12_COMPARISON_FUNC_ALWAYS;
		staticSampler.BorderColor = .D3D12_STATIC_BORDER_COLOR_TRANSPARENT_BLACK;
		staticSampler.MinLOD = 0;
		staticSampler.MaxLOD = 0;
		staticSampler.ShaderRegister = 0;
		staticSampler.RegisterSpace = 0;
		staticSampler.ShaderVisibility = .D3D12_SHADER_VISIBILITY_PIXEL;

/*
		desc: platform.D3D12_ROOT_SIGNATURE_DESC1;
		desc.NumParameters = len(param);
		desc.pParameters = mem.raw_slice_data(param[:]);
		desc.NumStaticSamplers = 1;
		desc.pStaticSamplers = &staticSampler;
		desc.Flags = .D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT |
		.D3D12_ROOT_SIGNATURE_FLAG_DENY_HULL_SHADER_ROOT_ACCESS |
		.D3D12_ROOT_SIGNATURE_FLAG_DENY_DOMAIN_SHADER_ROOT_ACCESS |
		.D3D12_ROOT_SIGNATURE_FLAG_DENY_GEOMETRY_SHADER_ROOT_ACCESS;
		
			// Load d3d12.dll and D3D12SerializeRootSignature() function address dynamically to facilitate using with D3D12On7.
			// See if any version of d3d12.dll is already loaded in the process. If so, give preference to that.
			//static HINSTANCE d3d12_dll = ::GetModuleHandleA("d3d12.dll");
			if d3d12_dll == NULL{
			// Attempt to load d3d12.dll from local directories. This will only succeed if
			// (1) the current OS is Windows 7, and
			// (2) there exists a version of d3d12.dll for Windows 7 (D3D12On7) in one of the following directories.
			// See https://github.com/ocornut/imgui/pull/3696 for details.
			//  const char* localD3d12Paths[] = { ".\\d3d12.dll", ".\\d3d12on7\\d3d12.dll", ".\\12on7\\d3d12.dll" }; // A. current directory, B. used by some games, C. used in Microsoft D3D12On7 sample
			for i := 0; i < IM_ARRAYSIZE(localD3d12Paths); i+=1{
			//if ((d3d12_dll = ::LoadLibraryA(localD3d12Paths[i])) != NULL)
			//    break;
			}
			
			// If failed, we are on Windows >= 10.
			if d3d12_dll == NULL{
			//d3d12_dll = ::LoadLibraryA("d3d12.dll");
			}
			
			if d3d12_dll == NULL{
			return false;
			}
			}
			
			//PFN_D3D12_SERIALIZE_ROOT_SIGNATURE D3D12SerializeRootSignatureFn = (PFN_D3D12_SERIALIZE_ROOT_SIGNATURE)::GetProcAddress(d3d12_dll, "D3D12SerializeRootSignature");
			if D3D12SerializeRootSignatureFn == NULL{
			return false;
			}
			
			ID3DBlob* blob = NULL;
			if D3D12SerializeRootSignatureFn(&desc, D3D_ROOT_SIGNATURE_VERSION_1, &blob, NULL) != S_OK{
			return false;
			}
		*/
// Allow input layout and deny unnecessary access to certain pipeline stages. // Allow input layout and deny unnecessary access to certain pipeline stages. // Allow input layout and deny unnecessary access to certain pipeline stages. // Allow input layout and deny unnecessary access to certain pipeline stages.
		root_sig_flags: platform.D3D12_ROOT_SIGNATURE_FLAGS = .D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT |
	                                                      .D3D12_ROOT_SIGNATURE_FLAG_DENY_HULL_SHADER_ROOT_ACCESS |
	                                                      .D3D12_ROOT_SIGNATURE_FLAG_DENY_DOMAIN_SHADER_ROOT_ACCESS |
	                                                      .D3D12_ROOT_SIGNATURE_FLAG_DENY_GEOMETRY_SHADER_ROOT_ACCESS;

		//CreateRootSignature(g_pd3dDevice,0, blob.GetBufferPointer(), blob.GetBufferSize(), &g_pRootSignature);
		g_pRootSignature = CreateRootSignature(g_pd3dDevice,mem.raw_slice_data(param[:]), len(param), &staticSampler, 1, root_sig_flags);
		// blob.Release();
	}

	// By using D3DCompile() from <d3dcompiler.h> / d3dcompiler.lib, we introduce a dependency to a given version of d3dcompiler_XX.dll (see D3DCOMPILER_DLL_A)
	// If you would like to use this DX12 sample code but remove this dependency you can:
	//  1) compile once, save the compiled shader blobs into a file or source code and pass them to CreateVertexShader()/CreatePixelShader() [preferred solution]
	//  2) use code to detect any version of the DLL and grab a pointer to D3DCompile from the DLL.
	// See https://github.com/ocornut/imgui/pull/638 for sources and details.

	psoDesc: platform.D3D12_GRAPHICS_PIPELINE_STATE_DESC;
	mem.set(&psoDesc, 0, size_of(platform.D3D12_GRAPHICS_PIPELINE_STATE_DESC));
	psoDesc.NodeMask = 1;
	psoDesc.PrimitiveTopologyType = .D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
	psoDesc.pRootSignature = g_pRootSignature;
	psoDesc.SampleMask = max(c.uint); //UINT_MAX;
	psoDesc.NumRenderTargets = 1;
	psoDesc.RTVFormats[0] = g_RTVFormat;
	psoDesc.SampleDesc.Count = 1;
	psoDesc.Flags = .D3D12_PIPELINE_STATE_FLAG_NONE;

	vertexShaderBlob: rawptr; //ID3DBlob* ;
	pixelShaderBlob: rawptr;  //ID3DBlob* 

	// Create the vertex shader
	{
		vertexShader: cstring = `
			#pragma pack_matrix( row_major )

			cbuffer vertexBuffer : register(b0) 
            {
              float4x4 ProjectionMatrix; 
            };

            struct VS_INPUT
            {
              float2 pos : POSITION;
              float4 col : COLOR0;
              float2 uv  : TEXCOORD0;
            };
            
            struct PS_INPUT
            {
              float4 pos : SV_POSITION;
              float4 col : COLOR0;
              float2 uv  : TEXCOORD0;
            };
            
            PS_INPUT main(VS_INPUT input)
            {
              PS_INPUT output;
              output.pos = mul( ProjectionMatrix, float4(input.pos.xy, 0.f, 1.f));
              output.col = input.col;
              output.uv  = input.uv;
              return output;
            }`;


		//if FAILED(D3DCompile(vertexShader, strlen(vertexShader), NULL, NULL, NULL, "main", "vs_5_0", 0, 0, &vertexShaderBlob, NULL)){
		//if (D3DCompile(vertexShader, strlen(vertexShader), NULL, NULL, NULL, "main", "vs_5_0", 0, 0, &vertexShaderBlob, NULL)){
		//    return false; // NB: Pass ID3D10Blob* pErrorBlob to D3DCompile() to get error showing in (const char*)pErrorBlob.GetBufferPointer(). Make sure to Release() the blob!
		//}
		//psoDesc.VS = { vertexShaderBlob.GetBufferPointer(), vertexShaderBlob.GetBufferSize() };
		
		shader_blob := CompileShader(vertexShader,"vs_5_1");//platform.CompileShader_(vertexShader);SHADER_BYTECODE
		psoDesc.VS = platform.GetShaderByteCode(shader_blob);

		// Create the input layout
		local_layout: []platform.D3D12_INPUT_ELEMENT_DESC = {
			{"POSITION", 0, .DXGI_FORMAT_R32G32_FLOAT, 0, cast(c.uint)offset_of(imgui.Draw_Vert, pos), .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
			{"TEXCOORD", 0, .DXGI_FORMAT_R32G32_FLOAT, 0, cast(c.uint)offset_of(imgui.Draw_Vert, uv), .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
			{"COLOR", 0, .DXGI_FORMAT_R8G8B8A8_UNORM, 0, cast(c.uint)offset_of(imgui.Draw_Vert, col), .D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0},
		};
		psoDesc.InputLayout = {mem.raw_slice_data(local_layout[:]), 3};
	}

	// Create the pixel shader
	{
		pixelShader: cstring = `
			struct PS_INPUT
            {
              float4 pos : SV_POSITION;
              float4 col : COLOR0;
              float2 uv  : TEXCOORD0;
            };

            SamplerState sampler0 : register(s0);
            Texture2D texture0 : register(t0);
            
            float4 main(PS_INPUT input) : SV_Target
            {
              float4 out_col = input.col * texture0.Sample(sampler0, input.uv); 
              return out_col; 
            }`;


		//if FAILED(D3DCompile(pixelShader, strlen(pixelShader), NULL, NULL, NULL, "main", "ps_5_0", 0, 0, &pixelShaderBlob, NULL)){
		//    vertexShaderBlob.Release();
		//    return false; // NB: Pass ID3D10Blob* pErrorBlob to D3DCompile() to get error showing in (const char*)pErrorBlob.GetBufferPointer(). Make sure to Release() the blob!
		//}
		//psoDesc.PS = { pixelShaderBlob.GetBufferPointer(), pixelShaderBlob.GetBufferSize() };
		ps_blob := CompileShader(pixelShader,"ps_5_1");
		psoDesc.PS = platform.GetShaderByteCode(ps_blob);
	}

	// Create the blending setup
	{
		desc: ^platform.D3D12_BLEND_DESC = &psoDesc.BlendState;
		desc.AlphaToCoverageEnable = false;
		desc.RenderTarget[0].BlendEnable = true;
		desc.RenderTarget[0].SrcBlend = .D3D12_BLEND_SRC_ALPHA;
		desc.RenderTarget[0].DestBlend = .D3D12_BLEND_INV_SRC_ALPHA;
		desc.RenderTarget[0].BlendOp = .D3D12_BLEND_OP_ADD;
		desc.RenderTarget[0].SrcBlendAlpha = .D3D12_BLEND_ONE;
		desc.RenderTarget[0].DestBlendAlpha = .D3D12_BLEND_INV_SRC_ALPHA;
		desc.RenderTarget[0].BlendOpAlpha = .D3D12_BLEND_OP_ADD;
		desc.RenderTarget[0].RenderTargetWriteMask = .D3D12_COLOR_WRITE_ENABLE_ALL;
	}
	using platform;
	// Create the rasterizer state
	{
		desc: ^platform.D3D12_RASTERIZER_DESC = &psoDesc.RasterizerState;
		desc.FillMode = .D3D12_FILL_MODE_SOLID;
		desc.CullMode = .D3D12_CULL_MODE_NONE;
		desc.FrontCounterClockwise = false;
		desc.DepthBias = D3D12_DEFAULT_DEPTH_BIAS;
		desc.DepthBiasClamp = D3D12_DEFAULT_DEPTH_BIAS_CLAMP;
		desc.SlopeScaledDepthBias = D3D12_DEFAULT_SLOPE_SCALED_DEPTH_BIAS;
		desc.DepthClipEnable = true;
		desc.MultisampleEnable = false;
		desc.AntialiasedLineEnable = false;
		desc.ForcedSampleCount = 0;
		desc.ConservativeRaster = .D3D12_CONSERVATIVE_RASTERIZATION_MODE_OFF;
	}

	// Create depth-stencil State
	{
		desc: ^D3D12_DEPTH_STENCIL_DESC = &psoDesc.DepthStencilState;
		desc.DepthEnable = false;
		desc.DepthWriteMask = .D3D12_DEPTH_WRITE_MASK_ALL;
		desc.DepthFunc = .D3D12_COMPARISON_FUNC_ALWAYS;
		desc.StencilEnable = false;
		desc.FrontFace.StencilFailOp = .D3D12_STENCIL_OP_KEEP;
		desc.FrontFace.StencilDepthFailOp = .D3D12_STENCIL_OP_KEEP;
		desc.FrontFace.StencilPassOp = .D3D12_STENCIL_OP_KEEP;
		desc.FrontFace.StencilFunc = .D3D12_COMPARISON_FUNC_ALWAYS;
		desc.BackFace = desc.FrontFace;
	}

	//HRESULT result_pipeline_state = g_pd3dDevice.CreateGraphicsPipelineState(&psoDesc, IID_PPV_ARGS(&g_pPipelineState));
	//vertexShaderBlob.Release();
	//pixelShaderBlob.Release();
	//if result_pipeline_state != S_OK{
	//    return false;
	//}

	g_pPipelineState = CreateGraphicsPipelineState(g_pd3dDevice,&psoDesc);

	ImGui_ImplDX12_CreateFontsTexture();

	return true;
}

ImGui_ImplDX12_InvalidateDeviceObjects :: proc() {
	if g_pd3dDevice == nil {
		return;
	}

	                                       //SafeRelease(g_pRootSignature);       //SafeRelease(g_pRootSignature);
	                                       //SafeRelease(g_pPipelineState);       //SafeRelease(g_pPipelineState);
	                                       //SafeRelease(g_pFontTextureResource); //SafeRelease(g_pFontTextureResource);

	                                                                                                          //ImGuiIO& io = ImGui::GetIO();                                                                           //ImGuiIO& io = ImGui::GetIO();
	                                                                                                          //io.Fonts.SetTexID(NULL); // We copied g_pFontTextureView to io.Fonts.TexID so let's clear that as well. //io.Fonts.SetTexID(NULL); // We copied g_pFontTextureView to io.Fonts.TexID so let's clear that as well.
	/* /*
		for i := 0; i < g_numFramesInFlight; i+=1{ for i := 0; i < g_numFramesInFlight; i+=1{
		FrameResources* fr = &g_pFrameResources[i]; FrameResources* fr = &g_pFrameResources[i];
		SafeRelease(fr.IndexBuffer); SafeRelease(fr.IndexBuffer);
		SafeRelease(fr.VertexBuffer); SafeRelease(fr.VertexBuffer);
		} }
	*/ */
}

ImGui_ImplDX12_Init :: proc(device: rawptr, num_frames_in_flight: int, rtv_format: platform.DXGI_FORMAT, cbv_srv_heap: rawptr,
                            font_srv_cpu_desc_handle: platform.D3D12_CPU_DESCRIPTOR_HANDLE, font_srv_gpu_desc_handle: platform.D3D12_GPU_DESCRIPTOR_HANDLE) -> bool {
	// Setup backend capabilities flags
	io: ^imgui.IO = imgui.get_io(); // imgui.getio();//ImGui::GetIO();
	io.backend_renderer_name = "imgui_impl_dx12";
	io.backend_flags |= imgui.Backend_Flags.RendererHasVtxOffset; // ImGuiBackendFlags_RendererHasVtxOffset;  // We can honor the ImDrawCmd::VtxOffset field, allowing for large meshes.

	g_pd3dDevice = device;
	g_RTVFormat = rtv_format;
	g_hFontSrvCpuDescHandle = font_srv_cpu_desc_handle;
	g_hFontSrvGpuDescHandle = font_srv_gpu_desc_handle;
	
	g_numFramesInFlight = cast(u32)num_frames_in_flight;
	g_frameIndex = max(c.uint); //UINT_MAX;
	                            // IM_UNUSED(cbv_srv_heap); // Unused in master branch (will be used by multi-viewports)

	// Create buffers with a default size (they will later be grown as needed)
	for i := 0; i < num_frames_in_flight; i += 1 {
		fr: FrameResources;
		//FrameResources* fr = &g_pFrameResources[i];
		//fr = g_pFrameResources[i];
		fr.index_buffer = nil;
		fr.vertex_buffer = nil;
		fr.index_buffer_size = 10000;
		fr.vertex_buffer_size = 5000;
		append(&g_pFrameResources, fr);
	}

	return true;
}

ImGui_ImplDX12_Shutdown :: proc() {
	ImGui_ImplDX12_InvalidateDeviceObjects();
	//delete[] g_pFrameResources;
	g_pFrameResources = nil;
	g_pd3dDevice = nil;
	g_hFontSrvCpuDescHandle.ptr = 0;
	g_hFontSrvGpuDescHandle.ptr = 0;
	g_numFramesInFlight = 0;
	g_frameIndex = max(c.uint);
}

ImGui_ImplDX12_NewFrame :: proc() {
	if g_pPipelineState == nil {
		ImGui_ImplDX12_CreateDeviceObjects();
	}
}
