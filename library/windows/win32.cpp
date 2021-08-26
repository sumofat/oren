#include "win32.h"
using namespace Microsoft::WRL;
#define USE_DEBUG_LAYER 1
//WINDOWS SETUP FUNCTIONS
f2 GetWin32WindowDim(PlatformState* ps)
{
    RECT client_rect;
    GetClientRect(ps->window.handle, &client_rect);
	return f2_create(client_rect.right - client_rect.left, client_rect.bottom - client_rect.top);
}

void Map(ID3D12Resource* resource,u32 sub_resource,D3D12_RANGE* range,void** data)
{
    resource->Map(sub_resource,range,data);
}

void SetDescriptorHeaps(ID3D12GraphicsCommandList* list,u32 NumDescriptorHeaps,ID3D12DescriptorHeap* const* ppDescriptorHeaps)
{
    ASSERT(list);
    list->SetDescriptorHeaps(NumDescriptorHeaps,ppDescriptorHeaps); 
}

HRESULT Present(IDXGISwapChain4* swap_chain,u32 SyncInterval,u32 Flags)
{
    return swap_chain->Present(SyncInterval,Flags);    
}

void OMSetStencilRef(ID3D12GraphicsCommandList* list,UINT ref)
{
    list->OMSetStencilRef(ref);
}

void SetGraphicsRootDescriptorTable(ID3D12GraphicsCommandList* list, u32 RootParameterIndex,D3D12_GPU_DESCRIPTOR_HANDLE BaseDescriptor)
{
    ASSERT(list);
    list->SetGraphicsRootDescriptorTable(RootParameterIndex,BaseDescriptor);
}

void SetGraphicsRoot32BitConstants(ID3D12GraphicsCommandList* list,u32 RootParameterIndex,u32 Num32BitValuesToSet,void *pSrcData,u32 DestOffsetIn32BitValues)
{
    ASSERT(list);
    list->SetGraphicsRoot32BitConstants(RootParameterIndex,Num32BitValuesToSet,pSrcData,DestOffsetIn32BitValues);
}

void IASetVertexBuffers(ID3D12GraphicsCommandList* list,u32 StartSlot,u32 NumViews,D3D12_VERTEX_BUFFER_VIEW *pViews)
{
    ASSERT(list);
    list->IASetVertexBuffers(StartSlot,NumViews,pViews);    
}

void DrawInstanced(ID3D12GraphicsCommandList* list,u32 VertexCountPerInstance,u32 InstanceCount,u32 StartVertexLocation,u32 StartInstanceLocation)
{
    ASSERT(list);
    list->DrawInstanced(VertexCountPerInstance,InstanceCount,StartVertexLocation,StartInstanceLocation);    
}

void SetPipelineState(ID3D12GraphicsCommandList* list,ID3D12PipelineState *pPipelineState)
{
    ASSERT(list);
    list->SetPipelineState(pPipelineState);
}

void DrawIndexedInstanced(ID3D12GraphicsCommandList* list,u32 IndexCountPerInstance,u32 InstanceCount,u32 StartIndexLocation,s32  BaseVertexLocation,u32 StartInstanceLocation)
{
    ASSERT(list);
    list->DrawIndexedInstanced(IndexCountPerInstance,InstanceCount,StartIndexLocation,BaseVertexLocation,StartInstanceLocation);    
}

void SetGraphicsRootSignature(ID3D12GraphicsCommandList* list,ID3D12RootSignature *pRootSignature)
{
    ASSERT(list);
    list->SetGraphicsRootSignature(pRootSignature);
}

void RSSetViewports(ID3D12GraphicsCommandList* list,u32 NumViewports,D3D12_VIEWPORT *pViewports)
{
    list->RSSetViewports(NumViewports, pViewports);    
}

void RSSetScissorRects(ID3D12GraphicsCommandList* list,u32 NumRects,D3D12_RECT *pRects)
{
    ASSERT(list);
    list->RSSetScissorRects(NumRects,pRects);    
}

void ClearRenderTargetView(ID3D12GraphicsCommandList* list,D3D12_CPU_DESCRIPTOR_HANDLE RenderTargetView,FLOAT ColorRGBA[4] ,UINT NumRects,D3D12_RECT *pRects)
{
    list->ClearRenderTargetView(RenderTargetView,ColorRGBA,NumRects,pRects);
}

void OMSetRenderTargets(ID3D12GraphicsCommandList* list,u32 NumRenderTargetDescriptors,D3D12_CPU_DESCRIPTOR_HANDLE *pRenderTargetDescriptors,bool RTsSingleHandleToDescriptorRange,D3D12_CPU_DESCRIPTOR_HANDLE *pDepthStencilDescriptor)
{
    ASSERT(list);
    list->OMSetRenderTargets(NumRenderTargetDescriptors,pRenderTargetDescriptors,RTsSingleHandleToDescriptorRange,pDepthStencilDescriptor);
}

void IASetPrimitiveTopology(ID3D12GraphicsCommandList*list,D3D12_PRIMITIVE_TOPOLOGY PrimitiveTopology)
{
    ASSERT(list);
    list->IASetPrimitiveTopology(PrimitiveTopology);
}

void IASetIndexBuffer(ID3D12GraphicsCommandList* list,D3D12_INDEX_BUFFER_VIEW *pView)
{
    ASSERT(list);
    list->IASetIndexBuffer(pView);    
}

void ClearDepthStencilView(ID3D12GraphicsCommandList* list,
                           D3D12_CPU_DESCRIPTOR_HANDLE DepthStencilView,
                           D3D12_CLEAR_FLAGS           ClearFlags,
                           f32                       Depth,
                           u8                       Stencil,
                           u32                        NumRects,
                           D3D12_RECT            *pRects)
{
    list->ClearDepthStencilView(DepthStencilView,ClearFlags,Depth,Stencil,NumRects,pRects);    
}

HRESULT CloseCommandList(ID3D12GraphicsCommandList* list)
{
    ASSERT(list);
    return list->Close();
}

void ExecuteCommandLists(ID3D12CommandQueue* queue, ID3D12CommandList*  const* lists,u32 list_count)
{
    queue->ExecuteCommandLists(list_count, lists);    
}

u64 GetIntermediateSize(ID3D12Resource* resource,u32 firstSubResource,u32 NumSubresources)
{
    return GetRequiredIntermediateSize(resource,firstSubResource,NumSubresources);
}

void CreateDepthStencilView(ID3D12Device2* device,ID3D12Resource *pResource,D3D12_DEPTH_STENCIL_VIEW_DESC *pDesc,  D3D12_CPU_DESCRIPTOR_HANDLE DestDescriptor)
{
    device->CreateDepthStencilView(pResource,
                               pDesc,
                               DestDescriptor);
}

HRESULT D3D12UpdateSubresources(
ID3D12GraphicsCommandList* pCmdList,
 ID3D12Resource* pDestinationResource,
 ID3D12Resource* pIntermediate,
u32 FirstSubresource,
u32 NumSubresources,
u64 RequiredSize,
D3D12_SUBRESOURCE_DATA* pSrcData)
{
    return UpdateSubresources(pCmdList, 
                       pDestinationResource,
                       pIntermediate,
                       FirstSubresource,
                       NumSubresources,
                       RequiredSize,
                       pSrcData);    
}


ID3D12CommandAllocator* CreateCommandAllocator(ID3D12Device2* device, D3D12_COMMAND_LIST_TYPE type)
{
    ID3D12CommandAllocator* commandAllocator;
    HRESULT result = (device->CreateCommandAllocator(type, IID_PPV_ARGS(&commandAllocator)));
#if 1
    HRESULT removed_reason = device->GetDeviceRemovedReason();
    DWORD e = GetLastError();
#endif
    ASSERT(SUCCEEDED(result));
    return commandAllocator;
}

HRESULT CreateCommittedResource(ID3D12Device2* device,D3D12_HEAP_PROPERTIES *pHeapProperties,
                             D3D12_HEAP_FLAGS HeapFlags,
                             D3D12_RESOURCE_DESC *pDesc,
                             D3D12_RESOURCE_STATES InitialResourceState,
                             D3D12_CLEAR_VALUE *pOptimizedClearValue,
                             ID3D12Resource** resource)

{
    HRESULT r = (device->CreateCommittedResource(
                     pHeapProperties,
                     HeapFlags,
                     pDesc,
                     InitialResourceState,
                     pOptimizedClearValue,
                     IID_PPV_ARGS(resource)));
    ASSERT(SUCCEEDED(r));
    return r;
}

ID3D12RootSignature* CreateRootSignature(ID3D12Device2* device,D3D12_ROOT_PARAMETER1* params,int param_count,D3D12_STATIC_SAMPLER_DESC* samplers,int sampler_count,D3D12_ROOT_SIGNATURE_FLAGS flags)
{
    ID3D12RootSignature* result;
        
    CD3DX12_VERSIONED_ROOT_SIGNATURE_DESC root_sig_d = {};
    root_sig_d.Init_1_1(param_count, params, sampler_count, samplers, flags);
        
    D3D12_FEATURE_DATA_ROOT_SIGNATURE feature_data = {};
    feature_data.HighestVersion = D3D_ROOT_SIGNATURE_VERSION_1_1;
    if (FAILED(device->CheckFeatureSupport(D3D12_FEATURE_ROOT_SIGNATURE, &feature_data, sizeof(feature_data))))
    {
        feature_data.HighestVersion = D3D_ROOT_SIGNATURE_VERSION_1_0;
    }
        
    // Serialize the root signature.
    ID3DBlob* root_sig_blob;
    ID3DBlob* err_blob;
    D3DX12SerializeVersionedRootSignature(&root_sig_d,
                                          feature_data.HighestVersion, &root_sig_blob, &err_blob);
    if ( err_blob )
    {
        OutputDebugStringA( (const char*)err_blob->GetBufferPointer());
        ASSERT(false);
    }
    // Create the root signature.
    HRESULT r = device->CreateRootSignature(0, root_sig_blob->GetBufferPointer(), 
                                            root_sig_blob->GetBufferSize(), IID_PPV_ARGS(&result));
    ASSERT(SUCCEEDED(r));
    return result;
}

/*
FMJStretchBuffer* GetTableForType(D3D12_COMMAND_LIST_TYPE type)
{
    FMJStretchBuffer* table;
    if(type == D3D12_COMMAND_LIST_TYPE_DIRECT)
    {
        table = &allocator_tables.free_allocator_table;
    }
    else if(type == D3D12_COMMAND_LIST_TYPE_COPY)
    {
        table = &allocator_tables.free_allocator_table_copy;
    }
    else if(type == D3D12_COMMAND_LIST_TYPE_COMPUTE)
    {
        table = &allocator_tables.free_allocator_table_compute;
    }
    return table;
}

D12CommandAllocatorEntry* AddFreeCommandAllocatorEntry(D3D12_COMMAND_LIST_TYPE type)
{
    D12CommandAllocatorEntry entry = {};
    entry.allocator = CreateCommandAllocator(device, type);
    ASSERT(entry.allocator);
    entry.used_list_indexes = fmj_stretch_buffer_init(1, sizeof(u64),8);
    entry.fence_value = 0;
    entry.thread_id = fmj_thread_get_thread_id();
    entry.type = type;
    entry.index = current_allocator_index++;
    D12CommandAllocatorKey key = {(u64)entry.allocator,entry.thread_id};
    //TODO(Ray):Why is the key parameter backwards here?
        
    fmj_anycache_add_to_free_list(&allocator_tables.fl_ca,&key,&entry);
//        D12CommandAllocatorEntry* result = (D12CommandAllocatorEntry*)AnythingCacheCode::GetThing(&allocator_tables.fl_ca, &key);
    D12CommandAllocatorEntry* result = (D12CommandAllocatorEntry*)fmj_anycache_get_(&allocator_tables.fl_ca, &key);
    ASSERT(result);
    return  result;
}
*/

u64 Signal(ID3D12CommandQueue* commandQueue, ID3D12Fence* fence,u64* fenceValue)
{
    ASSERT(commandQueue);
    ASSERT(fence);
    *fenceValue = (*fenceValue) + 1;
    u64 fenceValueForSignal = *fenceValue;
    commandQueue->Signal(fence, fenceValueForSignal);
    return fenceValueForSignal;
}
    
bool IsFenceComplete(ID3D12Fence* fence,u64 fence_value)
{
    return fence->GetCompletedValue() >= fence_value;
}
    
void WaitForFenceValue(ID3D12Fence* fence, u64 fenceValue, HANDLE fenceEvent,double duration = FLT_MAX)
{
    if (IsFenceComplete(fence,fenceValue))
    {
        (fence->SetEventOnCompletion(fenceValue, fenceEvent));
        ::WaitForSingleObject(fenceEvent, duration);
    }
}

GPUArena AllocateGPUArena(ID3D12Device2* device,u64 size)
{
    GPUArena result = {};
    size_t bufferSize = size;
    D3D12_HEAP_PROPERTIES hp =  
        {
            D3D12_HEAP_TYPE_UPLOAD,
            D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
            D3D12_MEMORY_POOL_UNKNOWN,
            0,
            0
        };
        
    DXGI_SAMPLE_DESC sample_d =  
        {
            1,
            0
        };
        
    D3D12_RESOURCE_DESC res_d =  
        {
            D3D12_RESOURCE_DIMENSION_BUFFER,
            0,
            size,
            1,
            1,
            1,
            DXGI_FORMAT_UNKNOWN,
            sample_d,
            D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
            D3D12_RESOURCE_FLAG_NONE,
        };
    result.size = size;        
    // Create a committed resource for the GPU resource in a default heap.
    HRESULT r = (device->CreateCommittedResource(
                     &hp,
                     D3D12_HEAP_FLAG_NONE,
                     &res_d,
                     D3D12_RESOURCE_STATE_GENERIC_READ,            
                     nullptr,
                     IID_PPV_ARGS(&result.resource)));
    ASSERT(SUCCEEDED(r));
    return result;
}


GPUArena AllocateStaticGPUArena(ID3D12Device2* device,u64 size)
{
    GPUArena result = {};
    size_t bufferSize = size;
    D3D12_HEAP_PROPERTIES hp =  
        {
            D3D12_HEAP_TYPE_DEFAULT,
            D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
            D3D12_MEMORY_POOL_UNKNOWN,
            0,
            0
        };
        
    DXGI_SAMPLE_DESC sample_d =  
        {
            1,
            0
        };
        
    D3D12_RESOURCE_DESC res_d =  
        {
            D3D12_RESOURCE_DIMENSION_BUFFER,
            0,
            size,
            1,
            1,
            1,
            DXGI_FORMAT_UNKNOWN,
            sample_d,
            D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
            D3D12_RESOURCE_FLAG_NONE,
        };
        
    result.size = size;                
    // Create a committed resource for the GPU resource in a default heap.
    HRESULT r = (device->CreateCommittedResource(
                     &hp,
                     D3D12_HEAP_FLAG_NONE,
                     &res_d,
                     D3D12_RESOURCE_STATE_COPY_DEST,
                     nullptr,
                     IID_PPV_ARGS(&result.resource)));
    ASSERT(SUCCEEDED(r));
    return result;
}

void WINSetScreenMode(PlatformState* ps,bool is_full_screen)
{
    HWND Window = ps->window.handle;
    LONG Style = GetWindowLong(Window, GWL_STYLE);
    ps->window.is_full_screen_mode = is_full_screen;
    ps->window.global_window_p.length = sizeof(WINDOWPLACEMENT);
    if(ps->window.is_full_screen_mode)
    {
        MONITORINFO mi = { sizeof(mi) };
        if (GetWindowPlacement(Window, &ps->window.global_window_p) &&
            GetMonitorInfo(MonitorFromWindow(Window,MONITOR_DEFAULTTOPRIMARY), &mi))
        {
            SetWindowLong(Window, GWL_STYLE,Style& ~WS_OVERLAPPEDWINDOW);
            SetWindowPos(Window, HWND_TOP,
                         mi.rcMonitor.left, mi.rcMonitor.top,
                         mi.rcMonitor.right - mi.rcMonitor.left,
                         mi.rcMonitor.bottom - mi.rcMonitor.top,
                         SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
            ps->window.is_full_screen_mode = true;
			ps->window.dim = f2_create(mi.rcMonitor.right - mi.rcMonitor.left, mi.rcMonitor.bottom - mi.rcMonitor.top);
        }
    }
    else
    {
        ps->window.is_full_screen_mode = false;
        SetWindowLong(Window, GWL_STYLE,Style& ~WS_OVERLAPPEDWINDOW);
        SetWindowPlacement(Window, &ps->window.global_window_p);
        SetWindowPos(Window,0, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                     SWP_NOOWNERZORDER | SWP_FRAMECHANGED);
    }
}
/*
D12CommandAllocatorEntry* GetFreeCommandAllocatorEntry(D3D12_COMMAND_LIST_TYPE  type)
{
    D12CommandAllocatorEntry* result;
    //Forget the free list we will access the table directly and get the first free
    //remove and make a inflight allocator table.
    //This does not work with free lists due to the fact taht the top element might always be busy
    //in some cases causing the infinite allocation of command allocators.
    //result = GetFirstFreeWithPredicate(D12CommandAllocatorEntry,allocator_tables.fl_ca,GetCAPredicateDIRECT);
    FMJStretchBuffer* table = GetTableForType(type);
            
    if(table->fixed.count <= 0)
    {
        result = 0;
    }
    else
    {
        // NOTE(Ray Garner): We assume if we get a free one you WILL use it.
        //otherwise we will need to do some other bookkeeping.
        //result = *YoyoPeekVectorElementPtr(D12CommandAllocatorEntry*,table);
        result = *(D12CommandAllocatorEntry**)fmj_stretch_buffer_get_(table,table->fixed.count - 1);
        if(!IsFenceComplete(fence,(result)->fence_value))
        {
            result = 0;
        }
        else
        {
            fmj_stretch_buffer_pop(table);
        }
    }
    if (!result)
    {
        result = AddFreeCommandAllocatorEntry(type);
    }
    ASSERT(result);
    return result;
}
*/

HRESULT ResetCommandAllocator(ID3D12CommandAllocator* a)
{
    ASSERT(a);
    return a->Reset();
}

HRESULT ResetCommandList(ID3D12GraphicsCommandList* list,ID3D12CommandAllocator *pAllocator,ID3D12PipelineState *pInitialState)
{
    ASSERT(list);
    ASSERT(pAllocator);
    return list->Reset(pAllocator,pInitialState);
}

/*
void UploadBufferData(GPUArena* g_arena,void* data,u64 size)
{
    D12CommandAllocatorEntry* free_ca  = GetFreeCommandAllocatorEntry(D3D12_COMMAND_LIST_TYPE_COPY);
    resource_ca = free_ca->allocator;
        
    if(!is_resource_cl_recording)
    {
        resource_ca->Reset();
        resource_cl->Reset(resource_ca,nullptr);
        is_resource_cl_recording = true;
    }
        
    D3D12_HEAP_PROPERTIES hp =  
        {
            D3D12_HEAP_TYPE_UPLOAD,
            D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
            D3D12_MEMORY_POOL_UNKNOWN,
            0,
            0
        };
        
    DXGI_SAMPLE_DESC sample_d =  
        {
            1,
            0
        };
        
    D3D12_RESOURCE_DESC res_d =  
        {
            D3D12_RESOURCE_DIMENSION_BUFFER,
            0,
            size,
            1,
            1,
            1,
            DXGI_FORMAT_UNKNOWN,
            sample_d,
            D3D12_TEXTURE_LAYOUT_ROW_MAJOR,
            D3D12_RESOURCE_FLAG_NONE,
        };
        
    UploadOp uop = {};
    uop.arena = *g_arena;
        
    HRESULT hr = device->CreateCommittedResource(
        &hp,
        D3D12_HEAP_FLAG_NONE,
        &res_d,
        D3D12_RESOURCE_STATE_GENERIC_READ,
        nullptr,
        IID_PPV_ARGS(&uop.temp_arena.resource));
        
    uop.temp_arena.resource->SetName(L"TEMP_UPLOAD_BUFFER");
        
    ASSERT(SUCCEEDED(hr));
        
    D3D12_SUBRESOURCE_DATA subresourceData = {};
    subresourceData.pData = data;
    subresourceData.RowPitch = size;
    subresourceData.SlicePitch = subresourceData.RowPitch;
        
    hr = UpdateSubresources(resource_cl, 
                            g_arena->resource, uop.temp_arena.resource,
                            (u32)0, (u32)0, (u32)1, &subresourceData);
    // NOTE(Ray Garner): We will batch as many texture ops into one command list as possible 
    //and only after we have reached a signifigant amout flush the commands.
    //and do a final check at the end of the frame to flush any that were not flushed earlier.
    //meaning we batch as many as possible per frame but never wait long than one frame to batch.
        
    fmj_thread_begin_ticket_mutex(&upload_operations.ticket_mutex);
    uop.id = upload_operations.current_op_id++;
    UploadOpKey k = {uop.id};
    //AnythingCacheCode::AddThingFL(&upload_operations.table_cache,&k,&uop);
    fmj_anycache_add_to_free_list(&upload_operations.table_cache,&k,&uop);
    //if(upload_ops.anythings.count > UPLOAD_OP_THRESHOLD)
    {
        if(is_resource_cl_recording)
        {
            resource_cl->Close();
            is_resource_cl_recording = false;
        }
        ID3D12CommandList* const command_lists[] = {
            resource_cl
        };
        copy_command_queue->ExecuteCommandLists(_countof(command_lists), command_lists);
        upload_operations.fence_value = Signal(copy_command_queue, upload_operations.fence, upload_operations.fence_value);
            
        WaitForFenceValue(upload_operations.fence, upload_operations.fence_value, upload_operations.fence_event);
            
        //If we have gotten here we remove the temmp transient resource. and remove them from the cache
        for(int i = 0;i < upload_operations.table_cache.anythings.fixed.count;++i)
        {
            UploadOp *finished_uop = (UploadOp*)fmj_stretch_buffer_get_(&upload_operations.table_cache.anythings,i);
            // NOTE(Ray Garner): Upload should always be a copy operation and so we cant/dont need to 
            //call discard resource.
                
            //finished_uop->temp_arena.resource->Release();
            UploadOpKey k_ = {finished_uop->id};
            fmj_anycache_remove_free_list(&upload_operations.table_cache,&k_);
        }
        fmj_anycache_reset(&upload_operations.table_cache);
    }
    fmj_thread_end_ticket_mutex(&upload_operations.ticket_mutex);
}
*/

void SetArenaToVertexBufferView(GPUArena* g_arena,u64 size,u32 stride)
{
    g_arena->buffer_view = 
        {
            g_arena->resource->GetGPUVirtualAddress(),
            (UINT)size,
            (UINT)stride//(UINT)24
        };
}
    
void SetArenaToIndexVertexBufferView(GPUArena* g_arena,u64 size,DXGI_FORMAT format)
{
    D3D12_INDEX_BUFFER_VIEW index_buffer_view;
    index_buffer_view.BufferLocation = g_arena->resource->GetGPUVirtualAddress();
    index_buffer_view.SizeInBytes = size;
    index_buffer_view.Format = format;
    g_arena->index_buffer_view = index_buffer_view;
}

LRESULT CALLBACK MainWindowCallbackFunc(HWND Window,
                   UINT Message,
                   WPARAM WParam,
                   LPARAM LParam)
{

    //if (ImGui_ImplWin32_WndProcHandler(Window, Message, WParam, LParam))
//        return true;
    
    LRESULT Result = 0;
    switch(Message)
    {
        case WM_PAINT:
        {
            PAINTSTRUCT pss;
            HDC hDc = BeginPaint(Window, &pss);
//            FillRect(hDc, &pss.rcPaint, (HBRUSH) (COLOR_WINDOW + 1));
            EndPaint(Window, &pss);
//            return 0;
        }break;
//NOTE(Ray): We do not allow resizing at the moment.
//        case WM_SIZE:
//        {
//            if (dev != NULL && WParam != SIZE_MINIMIZED)
//            {
//            ImGui_ImplDX11_InvalidateDeviceObjects();
//            CleanupRenderTarget();
//            swapchain->ResizeBuffers(0, (UINT)LOWORD(lParam), (UINT)HIWORD(lParam), DXGI_FORMAT_UNKNOWN, 0);
//            CreateRenderTarget();
//            ImGui_ImplDX11_CreateDeviceObjects();
//            }
//            return 0;
//        }
        case WM_CLOSE:
        case WM_DESTROY:
        {
            local_copy_ps.is_running = false;
        } break;
        case WM_ACTIVATEAPP:
        {

        } break;
        case WM_SYSKEYDOWN:
        case WM_SYSKEYUP:
        case WM_KEYDOWN:
        case WM_KEYUP:
        {
            //u32 VKCode = (u32)Message.wParam;
            
        }break;
        default:
        {
//            OutputDebugStringA("default\n");
            Result = DefWindowProcA(Window, Message, WParam, LParam);
        } break;
    }
    return Result;
}

void HandleWindowsMessages(PlatformState* ps)
{
    MSG message;
    while(PeekMessage(&message, 0, 0, 0, PM_REMOVE))
    {
        if(message.message == WM_QUIT || message.message == WM_CLOSE || message.message == WM_DESTROY)
        {
            local_copy_ps.is_running = false;
        }
        TranslateMessage(&message);
        DispatchMessageA(&message);
    }
    ps->is_running = local_copy_ps.is_running;
}

void PullTimeState(PlatformState* ps)
{
#if WINDOWS
    LARGE_INTEGER li;
#endif

    if(ps->time.frame_index == 0)
   {

#if OSX || IOS
       ps->time.initial_ticks =  mach_absolute_time();
       ps->time.prev_ticks = ps->time.initial_ticks;
#elif WINDOWS
       QueryPerformanceCounter(&li);
       ps->time.initial_ticks =  li.QuadPart;
       ps->time.prev_ticks = ps->time.initial_ticks;
#endif
   }

#if WINDOWS
    QueryPerformanceCounter(&li);
    u64 current_ticks = li.QuadPart;
#elif OSX || IOS
    u64 current_ticks = mach_absolute_time();
#endif
    
    ps->time.delta_ticks = current_ticks - ps->time.prev_ticks;//ps->time.time_ticks;
    ps->time.time_ticks = current_ticks - ps->time.initial_ticks;
    ps->time.prev_ticks = current_ticks;    

#if OSX || IOS
    if(ps->time.ticks_per_second == 1000)
    {
        ps->time.delta_nanoseconds = (ps->time.delta_ticks);
    }
    else
    {
        //NOTE(RAY):Untested!!!
        ps->time.delta_nanoseconds = (ps->time.delta_ticks) * ps->time.ticks_per_second;
        ps->time.delta_nanoseconds = ps->time.delta_nanoseconds;
    }
#elif WINDOWS
    ps->time.delta_nanoseconds = (1000 * 1000 * 1000 * ps->time.delta_ticks) / ps->time.ticks_per_second;
#endif
    
    ps->time.delta_microseconds = ps->time.delta_nanoseconds / 1000;
    ps->time.delta_miliseconds = ps->time.delta_microseconds / 1000;
#if WINDOWS
    ps->time.delta_seconds = ((f32)ps->time.delta_ticks / (f32)ps->time.ticks_per_second);
#elif OSX
    ps->time.delta_seconds = ((f32)ps->time.delta_miliseconds / (f32)1000);
#endif

#if OSX || IOS
        ps->time.time_nanoseconds = (ps->time.time_ticks) * ps->time.ticks_per_second * 10;
#elif WINDOWS
        ps->time.time_nanoseconds = (1000 * 1000 * 1000 * ps->time.time_ticks) / ps->time.ticks_per_second;
#endif
    ps->time.time_microseconds = ps->time.time_nanoseconds / 1000;
    ps->time.time_miliseconds = ps->time.time_microseconds / 1000;
    ps->time.time_seconds = (f64)ps->time.time_ticks / (f64)ps->time.ticks_per_second;
    ps->time.frame_index++;
}

void UpdateDigitalButton(DigitalButton* button,u32 state)
{
    bool was_down = button->down;
    bool down = state >> 7;
    button->pressed = !was_down && down;
    button->released = was_down && !down;
    button->down = down;    
}

void PullMouseState(PlatformState* ps)
{
    Input* input = &ps->input;
    if(input)
    {
         POINT MouseP;
         GetCursorPos(&MouseP);
         ScreenToClient(ps->window.handle, &MouseP);
         //TODO(Ray):Account for non full screen mode header 
         f2 window_dim = GetWin32WindowDim(ps);
		 f2 current_mouse_p = f2_create(MouseP.x, (window_dim.y) - MouseP.y);
         f2 delta_mouse_p = f2_sub(input->mouse.prev_p,current_mouse_p);
		if(ps->input.mouse.wrap_mode)
		{
			if (MouseP.x > window_dim.x - 1)
			{
				POINT new_p;
				new_p.x = 1;
				new_p.y = MouseP.y;
				if (ClientToScreen(ps->window.handle, &new_p))
				{
					SetCursorPos(new_p.x, new_p.y);
					ScreenToClient(ps->window.handle, &new_p);
					current_mouse_p.x = 1;
					delta_mouse_p.x = 1;
				}
			}
			if (MouseP.y > window_dim.y - 1)
			{
				POINT new_p;
				new_p.x = current_mouse_p.x;
				new_p.y = 1;
				if (ClientToScreen(ps->window.handle, &new_p))
				{
					SetCursorPos(new_p.x, new_p.y);
					ScreenToClient(ps->window.handle, &new_p);
					current_mouse_p.y = ((window_dim.y) - new_p.y);
					delta_mouse_p.y = -1;
				}
			}
			if (MouseP.x < 1)
			{
				POINT new_p;
				new_p.x = window_dim.x - 1;
				new_p.y = MouseP.y;
				if (ClientToScreen(ps->window.handle, &new_p))
				{
					SetCursorPos(new_p.x, new_p.y);
					ScreenToClient(ps->window.handle, &new_p);
					current_mouse_p.x = window_dim.x - 1;
					delta_mouse_p.x = -1;
				}
			}
			if (MouseP.y < 1)
			{
				POINT new_p;
				new_p.x = (int)current_mouse_p.x;
				new_p.y = window_dim.y - 1;
				if (ClientToScreen(ps->window.handle, &new_p))
				{
					SetCursorPos(new_p.x, new_p.y);
					ScreenToClient(ps->window.handle, &new_p);
					current_mouse_p.y = window_dim.y - new_p.y;
					delta_mouse_p.y = -1;
				}
			}
		}
        input->mouse.p = current_mouse_p;
        input->mouse.delta_p = delta_mouse_p;
        input->mouse.prev_uv = input->mouse.uv;
        input->mouse.uv = f2_create(input->mouse.p.x / ps->window.dim.x, input->mouse.p.y / ps->window.dim.y);
        input->mouse.delta_uv = f2_sub(input->mouse.prev_uv,input->mouse.uv);
        input->mouse.prev_p = input->mouse.p;

        u32 lmbstate = GetAsyncKeyState(VK_LBUTTON);
        UpdateDigitalButton(&input->mouse.lmb,lmbstate);
        u32 rmbstate = GetAsyncKeyState(VK_RBUTTON);
        UpdateDigitalButton(&input->mouse.rmb,rmbstate);         
    }
}

void PullDigitalButtons(PlatformState* ps)
{
    Input* input = &ps->input;
    BYTE keyboard_state[MAX_KEYS];
    if(GetKeyboardState(keyboard_state))
    {
        for(int i = 0;i < MAX_KEYS;++i)
        {
            DigitalButton* button = &input->keyboard.keys[i];
            bool was_down = button->down;
            bool down = keyboard_state[i] >> 7;
            button->pressed = !was_down && down;
            button->released = was_down && !down;
            button->down = down;
        }
    }
}

void SetButton(DigitalButton* button,u32 button_type,XINPUT_STATE state)
{
    bool was_down = button->down;
    bool down = ((state.Gamepad.wButtons & button_type) != 0);
    button->pressed = !was_down && down;
    button->released = was_down && !down;
    button->down = down;
}

void PullGamePads(PlatformState* ps)
{
    for (DWORD i = 0; i < MAX_CONTROLLER_SUPPORT; i++)
    {
        XINPUT_STATE state;
        ZeroMemory(&state, sizeof(XINPUT_STATE));

        GamePad* game_pad = &ps->input.game_pads[i];
        if (XInputGetState(i, &state) == ERROR_SUCCESS)
        {
            game_pad[i].state = state;
            SetButton(&game_pad[i].a,XINPUT_GAMEPAD_A,state);
            SetButton(&game_pad[i].b,XINPUT_GAMEPAD_B,state);
            SetButton(&game_pad[i].x,XINPUT_GAMEPAD_X,state);
            SetButton(&game_pad[i].y,XINPUT_GAMEPAD_Y,state);
            SetButton(&game_pad[i].l,XINPUT_GAMEPAD_LEFT_SHOULDER,state);
            SetButton(&game_pad[i].r,XINPUT_GAMEPAD_RIGHT_SHOULDER,state);
            SetButton(&game_pad[i].select,XINPUT_GAMEPAD_BACK,state);
            SetButton(&game_pad[i].start,XINPUT_GAMEPAD_START,state);

            game_pad[i].left_shoulder.value = (f32)state.Gamepad.bLeftTrigger / 255;
            game_pad[i].right_shoulder.value = (f32) state.Gamepad.bRightTrigger / 255;

            game_pad[i].left_stick.X.value = clamp((float)state.Gamepad.sThumbLX / 32767 ,-1,1);
            game_pad[i].left_stick.Y.value = clamp((float)state.Gamepad.sThumbLY / 32767 ,-1,1);

            game_pad[i].right_stick.X.value = clamp((float)state.Gamepad.sThumbRX / 32767 ,-1,1);
            game_pad[i].right_stick.Y.value = clamp((float)state.Gamepad.sThumbRY / 32767 ,-1,1);
        }
    } 
}

int PlatformInit(PlatformState* ps,f2 window_dim,f2 window_p,int n_show_cmd)
{
//    GetSystemInfo(&ps->info);

/*
    STARTUPINFOA start_up_info = {0};
    GetStartupInfo(&start_up_info);
    n_show_cmd = start_up_info.wShowWindow;
    
    f2 dim = window_dim;
    f2 p = window_p;

    ps->is_running = true;
	ps->window.dim = dim;
    ps->window.p = p;
    
    HINSTANCE h_instance = GetModuleHandle(NULL);
    WNDCLASS WindowClass =  {0};

    WindowClass.style = CS_HREDRAW|CS_VREDRAW|CS_OWNDC;
    WindowClass.lpfnWndProc = MainWindowCallbackFunc;
    WindowClass.hInstance = h_instance;
    WindowClass.hCursor = LoadCursor(0, IDC_ARROW);
    WindowClass.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);
    WindowClass.lpszClassName = "Chip8Class";    
    
    DWORD ErrorCode = GetLastError();
    //ImGuiIO& io;
    if(RegisterClass(&WindowClass))
    {
        HWND created_window =
            CreateWindowExA(
                0,//WS_EX_TOPMOST|WS_EX_LAYERED,
                WindowClass.lpszClassName,
                "Chip8",
                WS_OVERLAPPEDWINDOW,
                ps->window.p.x,
                ps->window.p.y,
                ps->window.dim.x,
                ps->window.dim.y,
                0,
                0,
                h_instance,
                0);
        ErrorCode = GetLastError();
        if(created_window)
        {
            ps->window.handle = created_window;
//            WINSetScreenMode(ps,false);            
            ShowWindow(created_window, n_show_cmd);
        }
        else
        {
            //TODO(Ray):Could not attain window gracefully let the user know and shut down.
            //Could not start window.
            return 0;
        }
    }
*/
    
//time
    LARGE_INTEGER li;
    QueryPerformanceFrequency((LARGE_INTEGER*)&li);
    ps->time.ticks_per_second = li.QuadPart;
    QueryPerformanceCounter((LARGE_INTEGER*)&li);
    ps->time.initial_ticks = li.QuadPart;
    ps->time.prev_ticks = ps->time.initial_ticks;

//keys
    //TODO(Ray):Propery check for layouts
    HKL layout =  LoadKeyboardLayout((LPCSTR)"00000409",0x00000001);
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

    local_copy_ps = *ps;
    
    return 1;    
}

bool platformtest(PlatformState* ps,f2 window_dim,f2 window_p)
{
    return PlatformInit(ps,window_dim,window_p,5);
}
/*
#define Pop(ptr,type) (type*)Pop_(ptr,sizeof(type));ptr = (uint8_t*)ptr + (sizeof(type));
inline void* Pop_(void* ptr,u32 size)
{
    return ptr;
}

inline void AddHeader(CommandType type)
{
    FMJMemoryArenaPushParams def = fmj_arena_push_params_default();
    def.alignment = 0;
    D12CommandHeader* header = PUSHSTRUCT(&render_com_buf.arena,D12CommandHeader,def);
    header->type = type;
}
    
#define AddCommand(type) (type*)AddCommand_(sizeof(type));
inline void* AddCommand_(u32 size)
{
    ++render_com_buf.count;
    FMJMemoryArenaPushParams def = fmj_arena_push_params_default();
    def.alignment = 0;
    return PUSHSIZE(&render_com_buf.arena,size,def);
}

void AddSetVertexBufferCommand(u32 slot,D3D12_VERTEX_BUFFER_VIEW buffer_view)
{
    AddHeader(CommandType_SetVertexBuffer);
    D12CommandSetVertexBuffer* com = AddCommand(D12CommandSetVertexBuffer);
    com->slot = slot;
    com->buffer_view = buffer_view;
}
    
void AddDrawIndexedCommand(u32 index_count,u32 index_offset,D3D12_PRIMITIVE_TOPOLOGY topology,D3D12_INDEX_BUFFER_VIEW index_buffer_view)
{
    AddHeader(CommandType_DrawIndexed);
    D12CommandIndexedDraw* com = AddCommand(D12CommandIndexedDraw);
    com->index_count = index_count;
    com->index_offset = index_offset;
    com->topology = topology;
    com->index_buffer_view = index_buffer_view;
}
    
void AddDrawCommand(u32 offset,u32 count,D3D12_PRIMITIVE_TOPOLOGY topology)
{
    ASSERT(count != 0);
    AddHeader(CommandType_Draw);
    D12CommandBasicDraw* com = AddCommand(D12CommandBasicDraw);
    com->count = count;
    com->vertex_offset = offset;
    com->topology = topology;
}
    
void AddViewportCommand(f4 vp)
{
    AddHeader(CommandType_Viewport);
    D12CommandViewport* com = AddCommand(D12CommandViewport);
    com->viewport = vp;
}
    
void AddRootSignatureCommand(ID3D12RootSignature* root)
{
    AddHeader(CommandType_RootSignature);
    D12CommandRootSignature* com = AddCommand(D12CommandRootSignature);
    com->root_sig = root;
}
    
void AddPipelineStateCommand(ID3D12PipelineState* ps)
{
    AddHeader(CommandType_PipelineState);
    D12CommandPipelineState* com = AddCommand(D12CommandPipelineState);
    com->pipeline_state = ps;
}
    
void AddScissorRectCommand(f4 rect)
{
    AddHeader(CommandType_ScissorRect);
    D12CommandScissorRect* com = AddCommand(D12CommandScissorRect);
    com->rect = CD3DX12_RECT(rect.x,rect.y,rect.z,rect.w);
}
    
void AddStartCommandListCommand(D3D12_CPU_DESCRIPTOR_HANDLE* handles)
{
    AddHeader(CommandType_StartCommandList);
    D12CommandStartCommandList* com = AddCommand(D12CommandStartCommandList);
    com->handles = handles;
}
    
void AddEndCommandListCommand()
{
    AddHeader(CommandType_EndCommandList);
    D12CommandEndCommmandList* com = AddCommand(D12CommandEndCommmandList);
}
    
// TODO(Ray Garner): Replace these with something later
void AddGraphicsRootDescTable(u64 index,ID3D12DescriptorHeap* heaps,D3D12_GPU_DESCRIPTOR_HANDLE gpu_handle)
{
    AddHeader(CommandType_GraphicsRootDescTable);
    D12CommandGraphicsRootDescTable* com = AddCommand(D12CommandGraphicsRootDescTable);
    com->index = index;
    com->heap = heaps;
    com->gpu_handle = gpu_handle;
};
    
void AddGraphicsRoot32BitConstant(u32 index,u32 num_values,void* gpuptr,u32 offset)
{
    AddHeader(CommandType_GraphicsRootConstant);
    D12CommandGraphicsRoot32BitConstant* com = AddCommand(D12CommandGraphicsRoot32BitConstant);
    com->index = index;
    com->num_values = num_values;
    u32 byte_count = num_values*sizeof(u32);
    void* mem_ptr = PUSHSIZE(&constants_arena,byte_count,fmj_arena_push_params_no_clear());
    uint8_t* ptr = (uint8_t*)mem_ptr;
    for(int i = 0;i < byte_count;++i)
    {
        *ptr++ = *((uint8_t*)gpuptr + i);
    }
        
    com->gpuptr = mem_ptr;
    com->offset = offset;
};


GPUMemoryResult QueryGPUFastMemory()
{
    DXGI_QUERY_VIDEO_MEMORY_INFO info = {};
    // NOTE(Ray Garner): Zero is only ok if we are single GPUAdaptor
    HRESULT r = dxgiAdapter4->QueryVideoMemoryInfo(
        0,
        DXGI_MEMORY_SEGMENT_GROUP_LOCAL,
        &info);
    ASSERT(SUCCEEDED(r));
    GPUMemoryResult result = {info.Budget,info.CurrentUsage,info.AvailableForReservation,info.CurrentReservation};
    return result;
}
*/

IDXGIAdapter4* GetAdapter(bool useWarp)
{
    IDXGIFactory4* dxgifactory;
    UINT create_fac_flags = 0;
#if defined(_DEBUG)
    //create_fac_flags = DXGI_CREATE_FACTORY_DEBUG;
#endif
        
    CreateDXGIFactory2(create_fac_flags, IID_PPV_ARGS(&dxgifactory));
    IDXGIAdapter1* dxgi_adapter1;
    IDXGIAdapter4* dxgi_adapter4;
        
    if (useWarp)
    {
        dxgifactory->EnumWarpAdapter(IID_PPV_ARGS(&dxgi_adapter1));
        dxgi_adapter4 = (IDXGIAdapter4*)dxgi_adapter1;
        //dxgi_adapter1->As(&dxgi_adapter4);
    }
    else
    {
        SIZE_T maxDedicatedVideoMemory = 0;
        for (UINT i = 0; dxgifactory->EnumAdapters1(i, &dxgi_adapter1) != DXGI_ERROR_NOT_FOUND; ++i)
        {
            DXGI_ADAPTER_DESC1 dxgiAdapterDesc1;
            dxgi_adapter1->GetDesc1(&dxgiAdapterDesc1);
                
            // Check to see if the adapter can create a D3D12 device without actually 
            // creating it. The adapter with the largest dedicated video memory
            // is favored.
            if ((dxgiAdapterDesc1.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) == 0 && 
                SUCCEEDED(D3D12CreateDevice(dxgi_adapter1,D3D_FEATURE_LEVEL_11_0, __uuidof(ID3D12Device), nullptr)) &&
                dxgiAdapterDesc1.DedicatedVideoMemory > maxDedicatedVideoMemory)
            {
                maxDedicatedVideoMemory = dxgiAdapterDesc1.DedicatedVideoMemory;
                dxgi_adapter4 = (IDXGIAdapter4*)dxgi_adapter1;
            }
        }
    }
    return dxgi_adapter4;
}

    
bool EnableDebugLayer()
{
#if defined(_DEBUG)
    // Always enable the debug layer before doing anything DX12 related
    // so all possible errors generated while creating DX12 objects
    // are caught by the debug layer.
    ID3D12Debug* debugInterface;
    D3D12GetDebugInterface(IID_PPV_ARGS(&debugInterface));
    if (!debugInterface)
    {
        ASSERT(false);
    }
    debugInterface->EnableDebugLayer();
    return true;
#endif
}
    
ID3D12Device2* CreateDevice(IDXGIAdapter4* adapter)
{
        
#if USE_DEBUG_LAYER
    EnableDebugLayer();
#endif
    ID3D12Device2* d3d12Device2;
    D3D12CreateDevice(adapter, D3D_FEATURE_LEVEL_11_0, IID_PPV_ARGS(&d3d12Device2));
        
    HRESULT WINAPI D3D12CreateDevice(
        _In_opt_  IUnknown          *pAdapter,
        D3D_FEATURE_LEVEL MinimumFeatureLevel,
        _In_      REFIID            riid,
        _Out_opt_ void              **ppDevice
                                     );
        
    // Enable debug messages in debug mode.
#if USE_DEBUG_LAYER
    ID3D12InfoQueue* pInfoQueue;
    HRESULT result = d3d12Device2->QueryInterface(&pInfoQueue);
    if (SUCCEEDED(result))
    {
        pInfoQueue->SetBreakOnSeverity(D3D12_MESSAGE_SEVERITY_CORRUPTION, TRUE);
        pInfoQueue->SetBreakOnSeverity(D3D12_MESSAGE_SEVERITY_ERROR, TRUE);
        pInfoQueue->SetBreakOnSeverity(D3D12_MESSAGE_SEVERITY_WARNING, TRUE);
        // Suppress whole categories of messages
        //D3D12_MESSAGE_CATEGORY Categories[] = {};
            
        // Suppress messages based on their severity level
        D3D12_MESSAGE_SEVERITY Severities[] =
            {
                D3D12_MESSAGE_SEVERITY_INFO
            };
            
        // Suppress individual messages by their ID
        D3D12_MESSAGE_ID DenyIds[] = {
            D3D12_MESSAGE_ID_CLEARRENDERTARGETVIEW_MISMATCHINGCLEARVALUE,   // I'm really not sure how to avoid this message.
            D3D12_MESSAGE_ID_MAP_INVALID_NULLRANGE,                         // This warning occurs when using capture frame while graphics debugging.
            D3D12_MESSAGE_ID_UNMAP_INVALID_NULLRANGE,                       // This warning occurs when using capture frame while graphics debugging.
        };
            
        D3D12_INFO_QUEUE_FILTER NewFilter = {};
        //NewFilter.DenyList.NumCategories = _countof(Categories);
        //NewFilter.DenyList.pCategoryList = Categories;
        NewFilter.DenyList.NumSeverities = _countof(Severities);
        NewFilter.DenyList.pSeverityList = Severities;
        NewFilter.DenyList.NumIDs = _countof(DenyIds);
        NewFilter.DenyList.pIDList = DenyIds;
            
        pInfoQueue->PushStorageFilter(&NewFilter);
    }
    else
    {
        ASSERT(false);
    }
#endif
    return d3d12Device2;
}

    
ID3D12CommandQueue* CreateCommandQueue(ID3D12Device2* device, D3D12_COMMAND_LIST_TYPE type)
{
    ID3D12CommandQueue* d3d12CommandQueue;
        
    D3D12_COMMAND_QUEUE_DESC desc = {};
    desc.Type =     type;
    desc.Priority = D3D12_COMMAND_QUEUE_PRIORITY_NORMAL;
    desc.Flags =    D3D12_COMMAND_QUEUE_FLAG_NONE;
    desc.NodeMask = 0;
    DWORD error = GetLastError();
    HRESULT r = device->CreateCommandQueue(&desc, IID_PPV_ARGS(&d3d12CommandQueue));
    if(!SUCCEEDED(r))
    {
        ASSERT(false);
    }
    error = GetLastError();
    /*
      ID3D12CommandQueue* d3d12CommandQueue;
      D3D12_COMMAND_QUEUE_DESC desc = {};
      desc.Type = type;
      desc.Flags = D3D12_COMMAND_QUEUE_FLAG_NONE;
      desc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
      DWORD error = GetLastError();
      (device->CreateCommandQueue(&desc, IID_PPV_ARGS(&d3d12CommandQueue)));
      error = GetLastError();
    */
    return d3d12CommandQueue;
}
    
static bool CheckTearingSupport()
{
    BOOL allowTearing = FALSE;
    // Rather than create the DXGI 1.5 factory interface directly, we create the
    // DXGI 1.4 interface and query for the 1.5 interface. This is to enable the 
    // graphics debugging tools which will not support the 1.5 factory interface 
    // until a future update.
    IDXGIFactory4* factory4;
    if (SUCCEEDED(CreateDXGIFactory1(IID_PPV_ARGS(&factory4))))
    {
        IDXGIFactory5* factory5;
        HRESULT r = factory4->QueryInterface(&factory5);
        if (SUCCEEDED(r))
        {
            if (FAILED(factory5->CheckFeatureSupport(
                           DXGI_FEATURE_PRESENT_ALLOW_TEARING,
                           &allowTearing, sizeof(allowTearing))))
            {
                allowTearing = FALSE;
            }
        }
    }
    return allowTearing == TRUE;
}
    
IDXGISwapChain4* CreateSwapChain(HWND hWnd,ID3D12CommandQueue* commandQueue,u32 width, u32 height, u32 bufferCount)
{
    IDXGISwapChain4* dxgiSwapChain4;
    IDXGIFactory4* dxgiFactory4;
    UINT createFactoryFlags = 0;
#if defined(_DEBUG)
    //createFactoryFlags = DXGI_CREATE_FACTORY_DEBUG;
#endif
        
    (CreateDXGIFactory2(createFactoryFlags, IID_PPV_ARGS(&dxgiFactory4)));
    DXGI_SWAP_CHAIN_DESC1 swapChainDesc = {};
    swapChainDesc.Width = width;
    swapChainDesc.Height = height;
    swapChainDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    swapChainDesc.Stereo = FALSE;
    swapChainDesc.SampleDesc = { 1, 0 };
    swapChainDesc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    swapChainDesc.BufferCount = bufferCount;
    swapChainDesc.Scaling = DXGI_SCALING_STRETCH;
    swapChainDesc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD;
    swapChainDesc.AlphaMode = DXGI_ALPHA_MODE_UNSPECIFIED;
    // It is recommended to always allow tearing if tearing support is available.
    swapChainDesc.Flags = CheckTearingSupport() ? DXGI_SWAP_CHAIN_FLAG_ALLOW_TEARING : 0;
    ComPtr<IDXGISwapChain1> swapChain1;
    (dxgiFactory4->CreateSwapChainForHwnd(
        commandQueue,
        hWnd,
        &swapChainDesc,
        nullptr,
        nullptr,
        &swapChain1));
        
    // Disable the Alt+Enter fullscreen toggle feature. Switching to fullscreen
    // will be handled manually.
    (dxgiFactory4->MakeWindowAssociation(hWnd, DXGI_MWA_NO_ALT_ENTER));
    HRESULT result = swapChain1->QueryInterface(&dxgiSwapChain4);
    ASSERT(SUCCEEDED(result));
    //(swapChain1.As(&dxgiSwapChain4));
    return dxgiSwapChain4;
}

/*
ID3D12DescriptorHeap* CreateDescriptorHeap(ID3D12Device2* l_device,D3D12_DESCRIPTOR_HEAP_DESC desc)
{
    ID3D12DescriptorHeap* result;
    HRESULT r = l_device->CreateDescriptorHeap(&desc, IID_PPV_ARGS(&result));
    if (FAILED(r))
    {
        ASSERT(false);
    }
    return result;    
}
*/

ID3D12DescriptorHeap* CreateDescriptorHeap(ID3D12Device2* device,u32 num_desc,D3D12_DESCRIPTOR_HEAP_TYPE type,D3D12_DESCRIPTOR_HEAP_FLAGS  flags)
{
    ID3D12DescriptorHeap* result;
    D3D12_DESCRIPTOR_HEAP_DESC heapDesc = {0};
    heapDesc.NumDescriptors = num_desc;
    heapDesc.Flags = flags;
    heapDesc.Type = type;

    HRESULT r = device->CreateDescriptorHeap(&heapDesc, IID_PPV_ARGS(&result));
    if (FAILED(r))
    {
        ASSERT(false);
    }
    return result;
}
    
ID3D12DescriptorHeap* CreateDescriptorHeap(ID3D12Device2* l_device,D3D12_DESCRIPTOR_HEAP_TYPE type, u32 num_of_descriptors)
{
    ID3D12DescriptorHeap* descriptorHeap;
    D3D12_DESCRIPTOR_HEAP_DESC desc = {};
    desc.NumDescriptors = num_of_descriptors;
    desc.Type = type;
    (l_device->CreateDescriptorHeap(&desc, IID_PPV_ARGS(&descriptorHeap)));
    return descriptorHeap;
}

void CreateRenderTargetView(ID3D12Device2* device,ID3D12Resource *pResource,D3D12_RENDER_TARGET_VIEW_DESC *pDesc,D3D12_CPU_DESCRIPTOR_HANDLE DestDescriptor)
{
    device->CreateRenderTargetView(pResource, pDesc,DestDescriptor);    
}

HRESULT GetBuffer(IDXGISwapChain4* swapChain,UINT Buffer,ID3D12Resource** ppSurface)
{
    HRESULT r = swapChain->GetBuffer(Buffer, IID_PPV_ARGS(ppSurface));
    ASSERT(ppSurface);
    ASSERT(SUCCEEDED(r));
    return r;
}

/*
void UpdateRenderTargetViews(ID3D12Device2* device,IDXGISwapChain4* swapChain, ID3D12DescriptorHeap* descriptorHeap)
{
    auto rtvDescriptorSize = device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    CD3DX12_CPU_DESCRIPTOR_HANDLE rtvHandle(descriptorHeap->GetCPUDescriptorHandleForHeapStart());
    for (int i = 0; i < num_of_back_buffers; ++i)
    {
        ID3D12Resource* backBuffer;
        (swapChain->GetBuffer(i, IID_PPV_ARGS(&backBuffer)));
        device->CreateRenderTargetView(backBuffer, nullptr, rtvHandle);
        back_buffers[i] = backBuffer;
        rtvHandle.Offset(rtvDescriptorSize);
    }
}
*/

ID3D12Fence* CreateFence(ID3D12Device2* device)
{
    ID3D12Fence* fence;
    (device->CreateFence(0, D3D12_FENCE_FLAG_NONE, IID_PPV_ARGS(&fence)));
    return fence;
}
    
HANDLE CreateEventHandle()
{
    HANDLE fenceEvent;
    fenceEvent = ::CreateEvent(NULL, FALSE, FALSE, NULL);
    ASSERT(fenceEvent && "Failed to create fence event.");
    return fenceEvent;
}
    
ID3D12GraphicsCommandList* CreateCommandList(ID3D12Device2* device,ID3D12CommandAllocator* commandAllocator, D3D12_COMMAND_LIST_TYPE type)
{
    ID3D12GraphicsCommandList* command_list;
    HRESULT result = (device->CreateCommandList(0, type, commandAllocator, nullptr, IID_PPV_ARGS(&command_list)));
#if 1
    HRESULT removed_reason = device->GetDeviceRemovedReason();
    DWORD e = GetLastError();
#endif
    ASSERT(SUCCEEDED(result));
    command_list->Close();
    return command_list;
}

/*
void CreateDefaultDepthStencilBuffer(f2 dim)
{
    //Create the depth buffer
    // TODO(Ray Garner): FLUSH
    uint32_t width =  max(1, dim.x);
    uint32_t height = max(1, dim.y);
    D3D12_CLEAR_VALUE optimizedClearValue = {};
    optimizedClearValue.Format = DXGI_FORMAT_D32_FLOAT;
    optimizedClearValue.DepthStencil = { 1.0f, 0 };
    device->CreateCommittedResource(
        &CD3DX12_HEAP_PROPERTIES(D3D12_HEAP_TYPE_DEFAULT),
        D3D12_HEAP_FLAG_NONE,
        &CD3DX12_RESOURCE_DESC::Tex2D(DXGI_FORMAT_D32_FLOAT, width, height,
                                      1, 0, 1, 0, D3D12_RESOURCE_FLAG_ALLOW_DEPTH_STENCIL),
        D3D12_RESOURCE_STATE_DEPTH_WRITE,
        &optimizedClearValue,
        IID_PPV_ARGS(&depth_buffer));
    
    // Update the depth-stencil view.
    D3D12_DEPTH_STENCIL_VIEW_DESC dsv = {};
    dsv.Format = DXGI_FORMAT_D32_FLOAT;
    dsv.ViewDimension = D3D12_DSV_DIMENSION_TEXTURE2D;
    dsv.Texture2D.MipSlice = 0;
    dsv.Flags = D3D12_DSV_FLAG_NONE;
    device->CreateDepthStencilView(depth_buffer, &dsv,
                                   dsv_heap->GetCPUDescriptorHandleForHeapStart());
    fflush(stdout);
}


ID3D12RootSignature* CreateDefaultRootSig()
{
    // Create the descriptor heap for the depth-stencil view.
    D3D12_DESCRIPTOR_HEAP_DESC dsv_h_d = {};
    dsv_h_d.NumDescriptors = 1;
    dsv_h_d.Type = D3D12_DESCRIPTOR_HEAP_TYPE_DSV;
    dsv_h_d.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_NONE;
    HRESULT r = device->CreateDescriptorHeap(&dsv_h_d, IID_PPV_ARGS(&dsv_heap));
    ASSERT(SUCCEEDED(r));
    
    D3D12_FEATURE_DATA_ROOT_SIGNATURE feature_data = {};
    feature_data.HighestVersion = D3D_ROOT_SIGNATURE_VERSION_1_1;
    if (FAILED(device->CheckFeatureSupport(D3D12_FEATURE_ROOT_SIGNATURE, &feature_data, sizeof(feature_data))))
    {
        feature_data.HighestVersion = D3D_ROOT_SIGNATURE_VERSION_1_0;
    }

    // Allow input layout and deny unnecessary access to certain pipeline stages.
    D3D12_ROOT_SIGNATURE_FLAGS root_sig_flags =
        D3D12_ROOT_SIGNATURE_FLAG_ALLOW_INPUT_ASSEMBLER_INPUT_LAYOUT |
        D3D12_ROOT_SIGNATURE_FLAG_DENY_HULL_SHADER_ROOT_ACCESS |
        D3D12_ROOT_SIGNATURE_FLAG_DENY_DOMAIN_SHADER_ROOT_ACCESS |
        D3D12_ROOT_SIGNATURE_FLAG_DENY_GEOMETRY_SHADER_ROOT_ACCESS;
    //|D3D12_ROOT_SIGNATURE_FLAG_DENY_PIXEL_SHADER_ROOT_ACCESS;

    // create a descriptor range (descriptor table) and fill it out
    // this is a range of descriptors inside a descriptor heap
    D3D12_DESCRIPTOR_RANGE1  descriptorTableRanges[1];
    descriptorTableRanges[0].RangeType = D3D12_DESCRIPTOR_RANGE_TYPE_SRV;
    descriptorTableRanges[0].NumDescriptors = -1;//MAX_SRV_DESC_HEAP_COUNT; 
    descriptorTableRanges[0].BaseShaderRegister = 0; 
    descriptorTableRanges[0].RegisterSpace = 0;
    descriptorTableRanges[0].OffsetInDescriptorsFromTableStart = D3D12_DESCRIPTOR_RANGE_OFFSET_APPEND; 
    descriptorTableRanges[0].Flags = D3D12_DESCRIPTOR_RANGE_FLAG_DESCRIPTORS_VOLATILE;

    // create a descriptor table
    D3D12_ROOT_DESCRIPTOR_TABLE1 descriptorTable;
    descriptorTable.NumDescriptorRanges = _countof(descriptorTableRanges);
    descriptorTable.pDescriptorRanges = &descriptorTableRanges[0];

    D3D12_ROOT_CONSTANTS rc_1 = {};
    rc_1.RegisterSpace = 0;
    rc_1.ShaderRegister = 0;
    rc_1.Num32BitValues = 16;
    
    D3D12_ROOT_CONSTANTS rc_2 = {};
    rc_2.RegisterSpace = 0;
    rc_2.ShaderRegister = 1;
    rc_2.Num32BitValues = 16;
    
    D3D12_ROOT_CONSTANTS rc_3 = {};
    rc_3.RegisterSpace = 0;
    rc_3.ShaderRegister = 2;
    rc_3.Num32BitValues = 4;
    
    D3D12_ROOT_CONSTANTS rc_4 = {};
    rc_4.RegisterSpace = 0;
    rc_4.ShaderRegister = 0;
    rc_4.Num32BitValues = 4;

    D3D12_ROOT_PARAMETER1  root_params[5];
    root_params[0].ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
    root_params[0].ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX;
    root_params[0].Constants = rc_1;

    // fill out the parameter for our descriptor table. Remember it's a good idea to sort parameters by frequency of change. Our constant
    // buffer will be changed multiple times per frame, while our descriptor table will not be changed at all.
    root_params[1].ParameterType = D3D12_ROOT_PARAMETER_TYPE_DESCRIPTOR_TABLE;
    root_params[1].DescriptorTable = descriptorTable;
    root_params[1].ShaderVisibility = D3D12_SHADER_VISIBILITY_ALL;
   
    root_params[2].ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
    root_params[2].ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX;
    root_params[2].Constants = rc_2;
    
    root_params[3].ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
    root_params[3].ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX;
    root_params[3].Constants = rc_3;
    
    root_params[4].ParameterType = D3D12_ROOT_PARAMETER_TYPE_32BIT_CONSTANTS;
    root_params[4].ShaderVisibility = D3D12_SHADER_VISIBILITY_PIXEL;
    root_params[4].Constants = rc_4;

    D3D12_STATIC_SAMPLER_DESC vs;
    vs.Filter = D3D12_FILTER_MIN_MAG_MIP_POINT;
    vs.AddressU = D3D12_TEXTURE_ADDRESS_MODE_WRAP;
    vs.AddressV = D3D12_TEXTURE_ADDRESS_MODE_WRAP;
    vs.AddressW = D3D12_TEXTURE_ADDRESS_MODE_WRAP;
    vs.MipLODBias = 0.0f;
    vs.MaxAnisotropy = 1;
    vs.ComparisonFunc = D3D12_COMPARISON_FUNC_ALWAYS;
    vs.MinLOD = 0;
    vs.MaxLOD = D3D12_FLOAT32_MAX;
    vs.ShaderRegister = 1;
    vs.RegisterSpace = 0;
    vs.ShaderVisibility = D3D12_SHADER_VISIBILITY_VERTEX;

    D3D12_STATIC_SAMPLER_DESC tex_static_samplers[2];
    tex_static_samplers[0] = vs;

    D3D12_STATIC_SAMPLER_DESC ss;
    ss.Filter = D3D12_FILTER_MIN_MAG_MIP_POINT;
    ss.AddressU = D3D12_TEXTURE_ADDRESS_MODE_WRAP;
    ss.AddressV = D3D12_TEXTURE_ADDRESS_MODE_WRAP;
    ss.AddressW = D3D12_TEXTURE_ADDRESS_MODE_WRAP;
    ss.MipLODBias = 0.0f;
    ss.MaxAnisotropy = 1;
    ss.ComparisonFunc = D3D12_COMPARISON_FUNC_ALWAYS;
    ss.MinLOD = 0;
    ss.MaxLOD = D3D12_FLOAT32_MAX;
    ss.ShaderRegister = 0;
    ss.RegisterSpace = 0;
    ss.ShaderVisibility = D3D12_SHADER_VISIBILITY_PIXEL;
    
    tex_static_samplers[1] = ss;

    return root_sig = CreatRootSignature(root_params,_countof(root_params),tex_static_samplers,2,root_sig_flags);
}


PipelineStateStream local_ppss = {};


PipelineStateStream CreateDefaultPipelineStateStreamDesc(D3D12_INPUT_ELEMENT_DESC* input_layout,int input_layout_count,ID3DBlob* vs_blob,ID3DBlob* fs_blob,bool depth_enable)
{
    PipelineStateStream ppss = {}; 
    ppss.pRootSignature = root_sig;
    
    D3D12_INPUT_ELEMENT_DESC input_layout_l[] = {
        { "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT,    0, D3D12_APPEND_ALIGNED_ELEMENT, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "COLOR"   , 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, D3D12_APPEND_ALIGNED_ELEMENT, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
        { "TEXCOORD", 0, DXGI_FORMAT_R32G32_FLOAT,       0, D3D12_APPEND_ALIGNED_ELEMENT, D3D12_INPUT_CLASSIFICATION_PER_VERTEX_DATA, 0 },
    };
        
    ppss.InputLayout = { input_layout_l,(u32)input_layout_count };

    D3D12_RT_FORMAT_ARRAY rtv_formats = {};
    rtv_formats.NumRenderTargets = 1;
    rtv_formats.RTFormats[0] = DXGI_FORMAT_R8G8B8A8_UNORM;
        
    ppss.PrimitiveTopologyType = D3D12_PRIMITIVE_TOPOLOGY_TYPE_TRIANGLE;
    ppss.VS = CD3DX12_SHADER_BYTECODE(vs_blob);
    ppss.PS = CD3DX12_SHADER_BYTECODE(fs_blob);
    ppss.DSVFormat = DXGI_FORMAT_D32_FLOAT;
    ppss.RTVFormats = rtv_formats;
    CD3DX12_DEFAULT d = {};

    CD3DX12_DEPTH_STENCIL_DESC1 dss1 = CD3DX12_DEPTH_STENCIL_DESC1(d);
    dss1.DepthEnable = depth_enable;
    CD3DX12_PIPELINE_STATE_STREAM_DEPTH_STENCIL1 dss = CD3DX12_PIPELINE_STATE_STREAM_DEPTH_STENCIL1(dss1);
//    ppss.depth_stencil_state = dss;
        
    CD3DX12_RASTERIZER_DESC raster_desc = CD3DX12_RASTERIZER_DESC(d);
    raster_desc.CullMode = D3D12_CULL_MODE_NONE;
    ppss.RasterizerState = CD3DX12_PIPELINE_STATE_STREAM_RASTERIZER(raster_desc);
    
    CD3DX12_BLEND_DESC bdx = CD3DX12_BLEND_DESC(d);
    bdx.RenderTarget[0].BlendEnable = true;
    bdx.RenderTarget[0].SrcBlend = D3D12_BLEND_SRC_ALPHA;
    bdx.RenderTarget[0].DestBlend = D3D12_BLEND_INV_SRC_ALPHA;
//    ppss.blend_state = CD3DX12_PIPELINE_STATE_STREAM_BLEND_DESC(bdx);
    local_ppss = ppss;
    D3D12_PIPELINE_STATE_STREAM_DESC pipeline_state_stream_desc = 
        {
            sizeof(PipelineStateStream), &local_ppss
        };

    CreatePipelineState(pipeline_state_stream_desc);    
    return ppss;        
}


void Init()
{
//        srv_heap_count = 0;
    allocator_tables = {};
    allocator_tables.free_allocator_table = fmj_stretch_buffer_init(1,sizeof(D12CommandAllocatorEntry*),8);
    allocator_tables.free_allocator_table_copy = fmj_stretch_buffer_init(1,sizeof(D12CommandAllocatorEntry*),8);
    allocator_tables.free_allocator_table_compute = fmj_stretch_buffer_init(1,sizeof(D12CommandAllocatorEntry*),8);
        
    allocator_tables.free_allocators = fmj_stretch_buffer_init(1, sizeof(D12CommandAllocatorEntry), 8);
    allocator_tables.command_lists = fmj_stretch_buffer_init(1, sizeof(D12CommandListEntry), 8);
    allocator_tables.allocator_to_list_table = fmj_stretch_buffer_init(1, sizeof(D12CommandAlloctorToCommandListKeyEntry), 8);
    temp_queue_command_list = fmj_stretch_buffer_init(1, sizeof(ID3D12GraphicsCommandList*),8);

    //AnythingCacheCode::Init(&allocator_tables.fl_ca, 4096, sizeof(D12CommandAllocatorEntry), sizeof(D12CommandAllocatorKey), true);
    allocator_tables.fl_ca = fmj_anycache_init(4096,sizeof(D12CommandAllocatorEntry), sizeof(D12CommandAllocatorKey), true);

    //render_com_buf.arena = PlatformAllocatePartition(MegaBytes(2));
    render_com_buf.arena = fmj_arena_allocate(FMJMEGABYTES(2));
        
    //Resource bookkeeping
    //resource_ca = CreateCommandAllocator(device,D3D12_COMMAND_LIST_TYPE_COPY);
        
//    resource_cl = 
//        CreateCommandList(device,resource_ca,D3D12_COMMAND_LIST_TYPE_COPY);
        
//    resource_ca->Reset();
//    resource_cl->Reset(resource_ca,nullptr);

    //This is the global resources cache for direcx12 
    //resources
//        AnythingCacheCode::Init(&resource_tables.resources,4096,sizeof(D12Resource),sizeof(D12ResourceKey));
    resource_tables.resources = fmj_anycache_init(4096,sizeof(D12Resource),sizeof(D12ResourceKey),true);
    //This is the perframe perthread resource state tracking of subresources
    //in use by command list about to be excecuted on this frame.
    //will be reset ever frame after command list execution.
    resource_tables.per_thread_sub_resource_state = fmj_stretch_buffer_init(1,sizeof(D12ResourceStateEntry),8);
    //This it the inter thread and intra list sub resource state 
    //for each resource. at the end of every use by a list on ever thread there is a final state.
    //We put that here so that when executing it can be cross reference and checked to see if the sub resource is in the proper state BEFORE its used in the command list.
    //If not we create a new command list to transition that sub resource into the proper state ONLY if its needed other wise ensure we do absolutely nothing.
    resource_tables.global_sub_resrouce_state =  fmj_stretch_buffer_init(1,sizeof(D12ResourceStateEntry),8);
    //is_resource_cl_recording = true;
        
    constants_arena = fmj_arena_allocate(FMJMEGABYTES(4));
        
    //Descriptor heap for our resources
    // create the descriptor heap that will store our srv
//    default_srv_desc_heap = CreateDescriptorHeap(MAX_SRV_DESC_HEAP_COUNT,D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV,D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE);
        
    D12ResourceState::Init(device);
}

CreateDeviceResult Init(HWND* window,f2 dim)
{
    CreateDeviceResult result = {0};
    dxgiAdapter4 = GetAdapter(g_UseWarp);
    device = CreateDevice(dxgiAdapter4);

//    command_queue = CreateCommandQueue(device, D3D12_COMMAND_LIST_TYPE_DIRECT);
//    copy_command_queue = CreateCommandQueue(device, D3D12_COMMAND_LIST_TYPE_COPY);
//    compute_command_queue = CreateCommandQueue(device, D3D12_COMMAND_LIST_TYPE_COMPUTE);

//    swap_chain = CreateSwapChain(*window, command_queue,dim.x, dim.y, num_of_back_buffers);

//    u32 current_back_buffer_index = swap_chain->GetCurrentBackBufferIndex();
    //rtv_descriptor_heap = CreateDescriptorHeap(device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV, num_of_back_buffers);
//    rtv_desc_size = device->GetDescriptorHandleIncrementSize(D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
//    UpdateRenderTargetViews(device, swap_chain, rtv_descriptor_heap);
        
//    fence = CreateFence(device);
//    fence_event = CreateEventHandle();
        
    result.is_init = true;
    Init();
    result.device.device = device;
    
//    D3D12_DESCRIPTOR_HEAP_DESC desc = {};
//    desc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_CBV_SRV_UAV;
//    desc.NumDescriptors = 1;
//    desc.Flags = D3D12_DESCRIPTOR_HEAP_FLAG_SHADER_VISIBLE;
//    if (device->CreateDescriptorHeap(&desc, IID_PPV_ARGS(&main_desc_heap)) != S_OK)
//    {
//        result.is_init = false;
//    }
//    else
//    {
//        CreateDefaultRootSig();
//        CreateDefaultDepthStencilBuffer(dim);
//        CreateDefaultPipelineStateStreamDesc();
//    }

    return result;
}

inline ID3D12Device2* GetDevice()
{
    return device;
}
*/

u32 GetCurrentBackBufferIndex(IDXGISwapChain4* swap_chain)
{
    return swap_chain->GetCurrentBackBufferIndex();
}

/*
ID3D12Resource* GetCurrentBackBuffer()
{
    u32 bbi = GetCurrentBackBufferIndex();
    ID3D12Resource* result = back_buffers[bbi];
    ASSERT(result);
    return result;
}
*/

ID3D12PipelineState*  CreatePipelineState(ID3D12Device2* device,D3D12_PIPELINE_STATE_STREAM_DESC pssd)
{
    ID3D12PipelineState* result;
    PipelineStateStream* psp = (PipelineStateStream*)pssd.pPipelineStateSubobjectStream;
    
    printf("size of rasterizer %d \n",(u32)sizeof(psp->RasterizerState));

    CD3DX12_DEFAULT d = {};
    
    CD3DX12_RASTERIZER_DESC raster_desc = CD3DX12_RASTERIZER_DESC(d);
    raster_desc.CullMode = D3D12_CULL_MODE_NONE;

    fflush( stdout );
    HRESULT r = device->CreatePipelineState(&pssd, IID_PPV_ARGS(&result));    
    ASSERT(SUCCEEDED(r));

    return result;
}

bool CheckFeatureSupport(ID3D12Device2* device,
  D3D12_FEATURE Feature,
  void          *pFeatureSupportData,
  UINT          FeatureSupportDataSize)
{
    HRESULT hr = device->CheckFeatureSupport(
            Feature,
            pFeatureSupportData,
            FeatureSupportDataSize);

    if(SUCCEEDED(hr))
    {
        return true;
    }
    else
    {
        return false;
    }    
}

/*
bool CheckFeatureSupport(D12Resource* resource)
{
    if (resource && resource->state)
    {
        auto desc = resource->state->GetDesc();
        resource->format_support.Format = desc.Format;
{
    HRESULT hr = device->CheckFeatureSupport(
            D3D12_FEATURE_FORMAT_SUPPORT,
            &resource->format_support,
            sizeof(D3D12_FEATURE_DATA_FORMAT_SUPPORT));

    if(SUCCEEDED(hr))
    {
        return true;
    }
    else
    {
        return false;
    }    
    }
    else
    {
        resource->format_support = {};
    }

}
*/

/*
// NOTE(Ray Garner): This is kind of like the OpenGL Texture 2D
// we will make space on the gpu and upload the texture from cpu
//to gpu right away. LoadedTexture is like the descriptor and also
//holds a pointer to the texels on cpu.
void Texture2D(Texture* lt,u32 heap_index,D12Resource* tex_resource,ID3D12DescriptorHeap* heap)
{
    D12CommandAllocatorEntry* free_ca  = GetFreeCommandAllocatorEntry(D3D12_COMMAND_LIST_TYPE_COPY);
    resource_ca = free_ca->allocator;
    if(!is_resource_cl_recording)
    {
        resource_ca->Reset();
        resource_cl->Reset(resource_ca,nullptr);
        is_resource_cl_recording = true;
    }

    D3D12_HEAP_PROPERTIES hp =  
        {
            D3D12_HEAP_TYPE_UPLOAD,
            D3D12_CPU_PAGE_PROPERTY_UNKNOWN,
            D3D12_MEMORY_POOL_UNKNOWN,
            0,
            0
        };
    
    D3D12_SUBRESOURCE_DATA subresourceData = {};
    subresourceData.pData = lt->texels;
    
    // TODO(Ray Garner): Handle minimum size for alignment.
    //This wont work for a smaller texture im pretty sure.
    subresourceData.RowPitch = lt->dim.x * lt->bytes_per_pixel;
    subresourceData.SlicePitch = subresourceData.RowPitch;

    // Create a temporary (intermediate) resource for uploading the subresources
    UINT64 req_size = GetRequiredIntermediateSize( tex_resource->state, 0, 1);    
    UploadOp uop = {};
    
    ID3D12Resource* intermediate_resource;
    HRESULT hr = device->CreateCommittedResource(
        &hp,
        D3D12_HEAP_FLAG_NONE,
        &CD3DX12_RESOURCE_DESC::Buffer( req_size ),
        D3D12_RESOURCE_STATE_GENERIC_READ,
        0,
        IID_PPV_ARGS( &uop.temp_arena.resource ));
        
    uop.temp_arena.resource->SetName(L"TEMP_UPLOAD_TEXTURE");
    ASSERT(SUCCEEDED(hr));
        
    hr = UpdateSubresources(resource_cl, 
                            tex_resource->state, uop.temp_arena.resource,
                            (u32)0, (u32)0, (u32)1, &subresourceData);
    ASSERT(SUCCEEDED(hr));
    
    CheckFeatureSupport(tex_resource);
        
    lt->state = tex_resource->state;
    fmj_thread_begin_ticket_mutex(&upload_operations.ticket_mutex);
    uop.id = upload_operations.current_op_id++;
    UploadOpKey k = {uop.id};
    fmj_anycache_add_to_free_list(&upload_operations.table_cache,&k,&uop);

    // NOTE(Ray Garner): Implement this.
    //if(upload_ops.anythings.count > UPLOAD_OP_THRESHOLD)
    {
        if(is_resource_cl_recording)
        {
            resource_cl->Close();
            is_resource_cl_recording = false;
        }

        ID3D12CommandList* const command_lists[] = {
            resource_cl
        };
        copy_command_queue->ExecuteCommandLists(_countof(command_lists), command_lists);
        upload_operations.fence_value = Signal(copy_command_queue, upload_operations.fence, upload_operations.fence_value);
            
        WaitForFenceValue(upload_operations.fence, upload_operations.fence_value, upload_operations.fence_event);
            
        //If we have gotten here we remove the temmp transient resource. and remove them from the cache
        for(int i = 0;i < upload_operations.table_cache.anythings.fixed.count;++i)
        {
            UploadOp *finished_uop = (UploadOp*)fmj_stretch_buffer_get_(&upload_operations.table_cache.anythings,i);
            // NOTE(Ray Garner): Upload should always be a copy operation and so we cant/dont need to 
            //call discard resource.
            // TODO(Ray Garner): Figure out how to properly release this
            //finished_uop->temp_arena.resource->Release();
            UploadOpKey k_ = {finished_uop->id};
            fmj_anycache_remove_free_list(&upload_operations.table_cache,&k_);
        }
        fmj_anycache_reset(&upload_operations.table_cache);
    }
    fmj_thread_end_ticket_mutex(&upload_operations.ticket_mutex);
}


bool GetCAPredicateCOPY(void* ca)
{
    D12CommandAllocatorEntry* entry = (D12CommandAllocatorEntry*)ca;
    if(entry->type == D3D12_COMMAND_LIST_TYPE_COPY && IsFenceComplete(upload_operations.fence,upload_operations.fence_value))
    {
        return true;
    }
    return false;
}


bool GetCAPredicateDIRECT(void* ca)
{
    D12CommandAllocatorEntry* entry = (D12CommandAllocatorEntry*)ca;
    if(entry->type == D3D12_COMMAND_LIST_TYPE_DIRECT && IsFenceComplete(fence,entry->fence_value))
    {
        return true;
    }
    return false;
}


void CheckReuseCommandAllocators()
{
    fmj_stretch_buffer_clear(&allocator_tables.free_allocator_table);
    fmj_stretch_buffer_clear(&allocator_tables.free_allocator_table_compute);
    fmj_stretch_buffer_clear(&allocator_tables.free_allocator_table_copy);                
    for(int i = 0;i < allocator_tables.fl_ca.anythings.fixed.count;++i)
    {
        D12CommandAllocatorEntry* entry = (D12CommandAllocatorEntry*)allocator_tables.fl_ca.anythings.fixed.base + i;
        //Check the fence values
        if(IsFenceComplete(fence,entry->fence_value))
        {
            FMJStretchBuffer* table = GetTableForType(entry->type);
            //if one put them on the free table for reuse.
            fmj_stretch_buffer_push(table,(void*)&entry);
        }
    }
}


static CommandAllocToListResult GetFirstAssociatedList(D12CommandAllocatorEntry* allocator)
{
    CommandAllocToListResult result = {};
    bool found = false;
    //Run through all the list that are associated with an allocator check for first available list
    for (int i = 0; i < allocator_tables.allocator_to_list_table.fixed.count; ++i)
    {
        D12CommandAlloctorToCommandListKeyEntry* entry = (D12CommandAlloctorToCommandListKeyEntry*)allocator_tables.allocator_to_list_table.fixed.base + i;
        if (allocator->index == entry->command_list_index)
        {
            //D12CommandAllocatorEntry* caentry = YoyoGetVectorElement(D12CommandAllocatorEntry, &allocator_tables.allocators, entry->command_allocator_index);
            D12CommandListEntry* e = (D12CommandListEntry*)fmj_stretch_buffer_get_(&allocator_tables.command_lists, entry->command_list_index);
            ASSERT(e);
            if (!e->is_encoding)
            {
                result.list = *e;
                //Since at this point this allocator should have all command list associated with it finished processing we can just grab the first command list.
                //and use it.
                result.index = entry->command_list_index;
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
D12CommandListEntry GetAssociatedCommandList(D12CommandAllocatorEntry* ca)
{
    CommandAllocToListResult listandindex = GetFirstAssociatedList(ca);
    D12CommandListEntry command_list_entry = listandindex.list;
    u64 cl_index = listandindex.index;
    if(!listandindex.found)
    {
        command_list_entry.list = CreateCommandList(device, ca->allocator, ca->type);
        command_list_entry.is_encoding = true;
        command_list_entry.index = allocator_tables.command_lists.fixed.count;
        command_list_entry.temp_resources = fmj_stretch_buffer_init(1,sizeof(ID3D12Object*),8);
            
        cl_index = fmj_stretch_buffer_push(&allocator_tables.command_lists, (void*)&command_list_entry);
        D12CommandAlloctorToCommandListKeyEntry a_t_l_e = {};
        a_t_l_e.command_allocator_index = ca->index;
        a_t_l_e.command_list_index = cl_index;
        fmj_stretch_buffer_push(&allocator_tables.allocator_to_list_table, (void*)&a_t_l_e);
    }
    fmj_stretch_buffer_push(&ca->used_list_indexes, (void*)&cl_index);
    return command_list_entry;
}


void EndCommandListEncodingAndExecute(D12CommandAllocatorEntry* ca,D12CommandListEntry cl)
{
    //Render encoder end encoding
    u64 index = cl.index;
    D12CommandListEntry* le = (D12CommandListEntry*)fmj_stretch_buffer_get_(&allocator_tables.command_lists, index);
    le->list->Close();
    le->is_encoding = false;
        
    ID3D12CommandList* const commandLists[] = {
        cl.list
    };
        
    for (int i = 0; i < ca->used_list_indexes.fixed.count; ++i)
    {
        u64 index_ = *((u64*)ca->used_list_indexes.fixed.base + i);
        D12CommandListEntry* cle = (D12CommandListEntry*)fmj_stretch_buffer_get_(&allocator_tables.command_lists,index_);
        fmj_stretch_buffer_push(&temp_queue_command_list, (void*)&cle->list);
    }
        
    ID3D12CommandList* const* temp = (ID3D12CommandList * const*)temp_queue_command_list.fixed.base;
    command_queue->ExecuteCommandLists(temp_queue_command_list.fixed.count, temp);
    HRESULT removed_reason = device->GetDeviceRemovedReason();
    DWORD e = GetLastError();
        
    fmj_stretch_buffer_clear(&temp_queue_command_list);
    fmj_stretch_buffer_clear(&ca->used_list_indexes);
}
*/

// TODO(Ray Garner): // NOTE(Ray Garner): It has been reccommended that we store tranistions until the
//copy draw dispatch or push needs to be executed and deffer them to the last minute as possible as 
//batches. For now we ignore that advice but will come back to that later.
void TransitionResource(D12CommandListEntry cle,ID3D12Resource* resource,D3D12_RESOURCE_STATES from,D3D12_RESOURCE_STATES to)
{
    CD3DX12_RESOURCE_BARRIER barrier = CD3DX12_RESOURCE_BARRIER::Transition(
        resource,
        from, to);
    cle.list->ResourceBarrier(1, &barrier);
}

D3D12_DESCRIPTOR_HEAP_DESC GetDesc(ID3D12DescriptorHeap* desc_heap)
{
    return desc_heap->GetDesc();
}
 
D3D12_CPU_DESCRIPTOR_HANDLE GetCPUDescriptorHandleForHeapStart(ID3D12DescriptorHeap* desc_heap)
{
    D3D12_CPU_DESCRIPTOR_HANDLE result = desc_heap->GetCPUDescriptorHandleForHeapStart();
    printf("ptr : %d \n",(u32)(result.ptr));
    fflush( stdout );
    return result;
}

D3D12_GPU_DESCRIPTOR_HANDLE GetGPUDescriptorHandleForHeapStart(ID3D12DescriptorHeap* desc_heap)
{
    return desc_heap->GetGPUDescriptorHandleForHeapStart();
}


UINT GetDescriptorHandleIncrementSize(ID3D12Device2* device, D3D12_DESCRIPTOR_HEAP_TYPE DescriptorHeapType)
{
    return device->GetDescriptorHandleIncrementSize(DescriptorHeapType);    
}

void CreateShaderResourceView(ID3D12Device2* device,ID3D12Resource* resource,D3D12_SHADER_RESOURCE_VIEW_DESC* desc,D3D12_CPU_DESCRIPTOR_HANDLE handle)
{
    device->CreateShaderResourceView(resource,desc,handle);
}

void CreateConstantBufferView(ID3D12Device2* device,D3D12_CONSTANT_BUFFER_VIEW_DESC* desc,D3D12_CPU_DESCRIPTOR_HANDLE handle)
{
    device->CreateConstantBufferView(desc,handle);
}

void CompileShader_(char* file_name,void** blob,char* shader_version_and_type)
{
    FMJFileReadResult file_result = fmj_file_platform_read_entire_file(file_name);
    ASSERT(file_result.content_size > 0);

    ID3DBlob* blob_errors;

    HRESULT r = D3DCompile2(
        file_result.content,
        file_result.content_size,
        file_name,
        0,
        0,
        "main",
        shader_version_and_type,
        SHADER_DEBUG_FLAGS,
        0,
        0,
        0,
        0,
        (ID3DBlob**)blob,
            &blob_errors);
    
    if ( blob_errors )
    {
        OutputDebugStringA( (const char*)blob_errors->GetBufferPointer());
    }
    
    ASSERT(SUCCEEDED(r));
}

D3D12_SHADER_BYTECODE GetShaderByteCode(ID3DBlob* blob)
{
    D3D12_SHADER_BYTECODE result = {0};
    result.pShaderBytecode = blob->GetBufferPointer();
    result.BytecodeLength = blob->GetBufferSize();
    return result;
}

/*
void EndFrame()
{
    fmj_thread_begin_ticket_mutex(&upload_operations.ticket_mutex);
    u32 current_backbuffer_index = GetCurrentBackBufferIndex();
    if(is_resource_cl_recording)
    {
        resource_cl->Close();
        is_resource_cl_recording = false;
    }
    //Prepare
    D3D12_CPU_DESCRIPTOR_HANDLE dsv_cpu_handle = dsv_heap->GetCPUDescriptorHandleForHeapStart();
    CD3DX12_CPU_DESCRIPTOR_HANDLE rtv_cpu_handle = CD3DX12_CPU_DESCRIPTOR_HANDLE(rtv_descriptor_heap->GetCPUDescriptorHandleForHeapStart(),current_backbuffer_index, rtv_desc_size);
    //D12Present the current framebuffer
    //Commandbuffer
    D12CommandAllocatorEntry* allocator_entry = GetFreeCommandAllocatorEntry(D3D12_COMMAND_LIST_TYPE_DIRECT);
    D12CommandListEntry command_list = GetAssociatedCommandList(allocator_entry);

    //Graphics
    ID3D12Resource* back_buffer = GetCurrentBackBuffer();
        
    bool fc = IsFenceComplete(fence,allocator_entry->fence_value);
        
    ASSERT(fc);
    allocator_entry->allocator->Reset();
        
    command_list.list->Reset(allocator_entry->allocator, nullptr);
        
    // Clear the render target.
    TransitionResource(command_list,back_buffer,D3D12_RESOURCE_STATE_PRESENT,D3D12_RESOURCE_STATE_RENDER_TARGET);
        
    FLOAT clearColor[] = { 0.4f, 0.6f, 0.9f, 1.0f };
        
    command_list.list->ClearRenderTargetView(rtv, clearColor, 0, nullptr);
    command_list.list->ClearDepthStencilView(dsv_cpu_handle, D3D12_CLEAR_FLAG_DEPTH, 1.0f, 0, 0, nullptr);
        
    //finish up
    EndCommandListEncodingAndExecute(allocator_entry,command_list);
    //insert signal in queue to so we know when we have executed up to this point. 
    //which in this case is up to the command clear and tranition back to present transition 
    //for back buffer.
    allocator_entry->fence_value = Signal(command_queue, fence, fence_value);
        
    WaitForFenceValue(fence, allocator_entry->fence_value, fence_event);


    //D12Rendering
    
    D12CommandAllocatorEntry* current_ae;
    D12CommandListEntry current_cl;
        
    void* at = render_com_buf.arena.base;
    for(int i = 0;i < render_com_buf.count;++i)
    {
        D12CommandHeader* header = (D12CommandHeader*)at;
        CommandType command_type = header->type;
        at = (uint8_t*)at + sizeof(D12CommandHeader);
            
        if(command_type == CommandType_StartCommandList)
        {
            D12CommandStartCommandList* com = (D12CommandStartCommandList*)at;
            at = (uint8_t*)at + (sizeof(D12CommandStartCommandList));                

            //Pop(at,D12CommandStartCommandList);
            current_ae = GetFreeCommandAllocatorEntry(D3D12_COMMAND_LIST_TYPE_DIRECT);
                
            current_cl = GetAssociatedCommandList(current_ae);
            bool fcgeo = IsFenceComplete(fence,current_ae->fence_value);
            ASSERT(fcgeo);
            current_ae->allocator->Reset();
            current_cl.list->Reset(current_ae->allocator, nullptr);
                
            current_cl.list->OMSetRenderTargets(1, &rtv_cpu_handle, FALSE, &dsv_cpu_handle);

            continue;
        }

        else if(command_type == CommandType_EndCommandList)
        {
            D12CommandEndCommmandList* com = Pop(at,D12CommandEndCommmandList);
            // NOTE(Ray Garner): For now we do this here but we need to do something else  setting render targets.
                
            //End D12 Renderering
            EndCommandListEncodingAndExecute(current_ae,current_cl);
            current_ae->fence_value = Signal(command_queue, fence, fence_value);
            // NOTE(Ray Garner): // TODO(Ray Garner): If there are dependencies from the last command list we need to enter a waitforfence value
            //so that we can finish executing this command list before and have the result ready for the next one.
            //If not we dont need to worry about this.
                
            //wait for the gpu to execute up until this point before we procede this is the allocators..
            //current fence value which we got when we signaled. 
            //the fence value that we give to each allocator is based on the fence value for the queue.
            WaitForFenceValue(fence, current_ae->fence_value, fence_event);
            fmj_stretch_buffer_clear(&current_ae->used_list_indexes);
            continue;
        }

        else if(command_type == CommandType_Viewport)
        {
            D12CommandViewport* com = Pop(at,D12CommandViewport);
            D3D12_VIEWPORT  new_viewport = CD3DX12_VIEWPORT(0.0f, 0.0f,com->viewport.z, com->viewport.w);
            current_cl.list->RSSetViewports(1, &new_viewport);
            continue;
        }

        else if(command_type == CommandType_ScissorRect)
        {
            D12CommandScissorRect* com = Pop(at,D12CommandScissorRect);
            //D12RendererCode::sis_rect = CD3DX12_RECT((u64)com->rect.x(), (u64)com->rect.y(), (u64)com->rect.z(), (u64)com->rect.w());
            current_cl.list->RSSetScissorRects(1, &com->rect);
            continue;
        }

        else if(command_type == CommandType_RootSignature)
        {
            D12CommandRootSignature* com = Pop(at,D12CommandRootSignature);
            ASSERT(com->root_sig);
            current_cl.list->SetGraphicsRootSignature(com->root_sig);
            continue;
        }
            
        else if(command_type == CommandType_PipelineState)
        {
            D12CommandPipelineState* com = Pop(at,D12CommandPipelineState);
            ASSERT(com->pipeline_state);
            current_cl.list->SetPipelineState(com->pipeline_state);
            continue;
        }

        else if(command_type == CommandType_SetVertexBuffer)
        {
            D12CommandSetVertexBuffer* com = Pop(at,D12CommandSetVertexBuffer);
            current_cl.list->IASetVertexBuffers(com->slot, 1, &com->buffer_view);                
            continue;                
        }

        else if(command_type == CommandType_Draw)
        {
            D12CommandBasicDraw* com = Pop(at,D12CommandBasicDraw);
//                current_cl.list->IASetVertexBuffers(0, 1, &com->buffer_view);
            current_cl.list->IASetPrimitiveTopology(com->topology);
            current_cl.list->DrawInstanced(com->count, 1, com->vertex_offset, 0);
            continue;
        }
            
        else if(command_type == CommandType_DrawIndexed)
        {
            D12CommandIndexedDraw* com = Pop(at,D12CommandIndexedDraw);
//                D3D12_VERTEX_BUFFER_VIEW views[2] = {com->buffer_view,com->uv_view};
//                current_cl.list->IASetVertexBuffers(0, 2, views);
            current_cl.list->IASetIndexBuffer(&com->index_buffer_view);
            // NOTE(Ray Garner): // TODO(Ray Garner): Get the heaps
            //that match with the pipeline state and root sig
            current_cl.list->IASetPrimitiveTopology(com->topology);
            current_cl.list->DrawIndexedInstanced(com->index_count,1,com->index_offset,0,0);
            continue;
        }
            
        else if(command_type == CommandType_GraphicsRootDescTable)
        {
            D12CommandGraphicsRootDescTable* com = Pop(at,D12CommandGraphicsRootDescTable);
                
            ID3D12DescriptorHeap* descriptorHeaps[] = { com->heap };
            current_cl.list->SetDescriptorHeaps(1, descriptorHeaps);
            current_cl.list->SetGraphicsRootDescriptorTable(com->index, com->gpu_handle);
            continue;
        }
            
        else if(command_type == CommandType_GraphicsRootConstant)
        {
            D12CommandGraphicsRoot32BitConstant* com = Pop(at,D12CommandGraphicsRoot32BitConstant);
            current_cl.list->SetGraphicsRoot32BitConstants(com->index, com->num_values, com->gpuptr, com->offset);
            continue;
        }
    }
        

    render_com_buf.count = 0;
    fmj_arena_deallocate(&render_com_buf.arena,false);
    
    D12CommandAllocatorEntry* final_allocator_entry = GetFreeCommandAllocatorEntry(D3D12_COMMAND_LIST_TYPE_DIRECT);
        
    D12CommandListEntry final_command_list = GetAssociatedCommandList(final_allocator_entry);
        
    bool final_fc = IsFenceComplete(fence,final_allocator_entry->fence_value);
    ASSERT(final_fc);
    final_allocator_entry->allocator->Reset();
        
    final_command_list.list->Reset(final_allocator_entry->allocator, nullptr);
    ID3D12Resource* cbb = GetCurrentBackBuffer();
//    final_command_list.list->SetDescriptorHeaps(1,&main_desc_heap);

    final_command_list.list->OMSetRenderTargets(1, &rtv_cpu_handle, FALSE, &dsv_cpu_handle);        
//        final_command_list.list->OMSetRenderTargets(1,&g_mainRenderTargetDescriptor[backBufferIdx], FALSE, NULL);
    //ImGui::Render();
//    ImGui_ImplDX12_RenderDrawData(ImGui::GetDrawData(), final_command_list.list);
    
//    D12CommandAllocatorEntry* final_allocator_entry = GetFreeCommandAllocatorEntry(D3D12_COMMAND_LIST_TYPE_DIRECT);
        
//    D12CommandListEntry final_command_list = GetAssociatedCommandList(final_allocator_entry);
        
//    bool final_fc = IsFenceComplete(fence,final_allocator_entry->fence_value);
//    ASSERT(final_fc);
//    final_allocator_entry->allocator->Reset();

        
//    final_command_list.list->Reset(final_allocator_entry->allocator, nullptr);
    //ID3D12Resource* cbb = GetCurrentBackBuffer();
//    final_command_list.list->SetDescriptorHeaps(1,&main_desc_heap);

//    final_command_list.list->OMSetRenderTargets(1, &rtv_cpu_handle, FALSE, &dsv_cpu_handle);
    
    //tranistion the render target back to present mode. preparing for presentation.
    TransitionResource(final_command_list,cbb,D3D12_RESOURCE_STATE_RENDER_TARGET,D3D12_RESOURCE_STATE_PRESENT);
        
    //finish up
    EndCommandListEncodingAndExecute(final_allocator_entry,final_command_list);
    //insert signal in queue to so we know when we have executed up to this point. 
    //which in this case is up to the command clear and tranition back to present transition 
    //for back buffer.
    final_allocator_entry->fence_value = Signal(command_queue, fence, fence_value);
    WaitForFenceValue(fence, final_allocator_entry->fence_value, fence_event);
        
    //execute the present flip
    UINT sync_interval = 0;
    UINT present_flags = DXGI_PRESENT_ALLOW_TEARING;
    swap_chain->Present(sync_interval, present_flags);
        
    //wait for the gpu to execute up until this point before we procede this is the allocators..
    //current fence value which we got when we signaled. 
    //the fence value that we give to each allocator is based on the fence value for the queue.
    //D12RendererCode::WaitForFenceValue(fence, allocator_entry->fence_value, fence_event);
    fmj_stretch_buffer_clear(&allocator_entry->used_list_indexes);

    is_resource_cl_recording = false;
    // NOTE(Ray Garner): Here we are doing bookkeeping for resuse of various resources.
    //If the allocators are not in flight add them to the free table
    CheckReuseCommandAllocators();
    fmj_thread_end_ticket_mutex(&upload_operations.ticket_mutex);
        
    //Reset state of constant buffer
    fmj_arena_deallocate(&constants_arena,false);
}
*/
