#include<windows.h>
#include <Xinput.h>
#include <dsound.h>
#include <mmdeviceapi.h>
#include <Audioclient.h>
#include <xinput.h>

// DirectX 12 specific headers.
#include <d3d12.h>
#include <dxgi1_6.h>
#include <d3dcompiler.h>
//#include <DirectXMath.h>

// D3D12 extension library.
#include "d3dx12.h"

// Windows Runtime Library. Needed for Microsoft::WRL::ComPtr<> template class.
#include <wrl.h>
#include <chrono>


extern "C"
{
  #include "../fmj/src/fmj_types.h"
}

#define MAX_KEYS 256
#define MAX_CONTROLLER_SUPPORT 2
struct Keys
{
    u32 w;
	u32 e;
	u32 r;
    u32 a;
    u32 s;
    u32 d;
    u32 f;
    u32 i;
    u32 j;
    u32 k;
    u32 l;
    u32 f1;
    u32 f2;
    u32 f3;
}typedef Keys;

Keys keys;

struct Time
{
    u64 frame_index;
    f32 delta_seconds;
    u64 delta_ticks;
    u64 delta_nanoseconds;
    u64 delta_microseconds;
    u64 delta_miliseconds;

    u64 delta_samples;
    
    f64 time_seconds;
    u64 time_ticks;
    u64 time_nanoseconds;
    u64 time_microseconds;
    u64 time_miliseconds;

    u64 ticks_per_second;
    u64 initial_ticks;

    u64 prev_ticks;
}typedef Time;

struct DigitalButton
{
    bool down;
    bool pressed;
    bool released;
}typedef DigitalButton;

struct Keyboard
{
    DigitalButton keys[MAX_KEYS];    
}typedef Keyboard;

struct AnalogButton
{
    f32 threshold;
    f32 value;
    bool down;
    bool pressed;
    bool released;
}typedef AnalogButton;

struct Axis
{
    f32 value;
    f32 threshold;
}typedef Axis;

//TODO(Ray):Handle other types of axis like ruddder/throttle etc...
struct Stick
{
    Axis X;
    Axis Y;
}typedef Stick;

struct GamePad
{
#if WINDOWS
    XINPUT_STATE state;    
#endif
    
    Stick left_stick;
    Stick right_stick;
 
    Axis left_shoulder;
    Axis right_shoulder;

    DigitalButton up;
    DigitalButton down;
    DigitalButton left;
    DigitalButton right;
 
    DigitalButton a;
    DigitalButton b;
    DigitalButton x;
    DigitalButton y;

    DigitalButton l;
    DigitalButton r;

    DigitalButton select;
    DigitalButton start;    
}typedef GamePad;

struct Mouse
{
    f2 p;
    f2 prev_p;
    f2 delta_p;
    f2 uv;
    f2 prev_uv;
    f2 delta_uv;

    DigitalButton lmb;//left_mouse_button
    DigitalButton rmb;
	bool wrap_mode;
}typedef Mouse;

struct Input
{
    Keyboard keyboard;
    Mouse mouse;
    GamePad game_pads[MAX_CONTROLLER_SUPPORT];
}typedef Input;

struct Window
{
#if WINDOWS
    WNDCLASSA w_class;
    HWND handle;
    HDC device_context;
    WINDOWPLACEMENT global_window_p;
#endif
	f2 dim;
    f2 p;
    bool is_full_screen_mode;
}typedef Window;

struct PlatformState
{

    Time time;
    Input input;
//    Renderer renderer;
//    Audio audio;
//    Memory memory;
//    SYSTEM_INFO info;
    bool is_running;
    Window window;    
}typedef PlatformState;


struct D12CommandAllocatorTables
{
    FMJStretchBuffer command_buffers;
    FMJStretchBuffer free_command_buffers;
    FMJStretchBuffer free_allocators;
    FMJStretchBuffer command_lists;
	FMJStretchBuffer allocator_to_list_table;
    
    //One for each type 
    FMJStretchBuffer free_allocator_table;//direct/graphics
    FMJStretchBuffer free_allocator_table_compute;
    FMJStretchBuffer free_allocator_table_copy;
    
    AnyCache fl_ca;//command_allocators
}typedef D12CommandAllocatorTables;


struct D12CommandAllocatorEntry
{
    ID3D12CommandAllocator* allocator;
	FMJStretchBuffer used_list_indexes;//Queued list indexes inflight being processed 
	u64 index;
    u64 fence_value;
    u64 thread_id;
    D3D12_COMMAND_LIST_TYPE type;
}typedef D12CommandAllocatorEntry;

//similar to MTLRenderCommandEncoder
struct D12CommandListEntry
{
    u64 index;
	ID3D12GraphicsCommandList* list;
//    RenderPassDescriptor* pass_desc;
	u64 encoding_thread_index;
	bool is_encoding;
    D3D12_COMMAND_LIST_TYPE type;
    FMJStretchBuffer temp_resources;//temp resources to release after execution is finished.
}typedef D12CommandListEntry;
 
struct D12CommandAlloctorToCommandListKeyEntry
{
	u64 command_allocator_index;
	u64 command_list_index;
};

//Similar to a MTLCommandBuffer
struct D12CommandAllocatorKey
{
    u64 ptr;
    u64 thread_id;//    
};

struct D12RenderCommandList
{
    FMJMemoryArena arena;
    u64 count;
};

struct UploadOperations
{
    u64 count;
    AnyCache table_cache;
    FMJTicketMutex ticket_mutex;
    u64 current_op_id;
    u64 fence_value;
    ID3D12Fence* fence;
    HANDLE fence_event;
};

struct GPUArena
{
    u64 size;
    ID3D12Heap* heap;
    ID3D12Resource* resource;
    u32 slot;
    union
    {
        D3D12_VERTEX_BUFFER_VIEW buffer_view;
        D3D12_INDEX_BUFFER_VIEW index_buffer_view;
    };
};

struct UploadOp
{
    u64 id;
    u64 thread_id;
    GPUArena arena;
    GPUArena temp_arena;
};

struct UploadOpKey
{
    u64 id;
};

struct D12ResourceTables
{
    AnyCache resources;
    FMJStretchBuffer per_thread_sub_resource_state;
    FMJStretchBuffer global_sub_resrouce_state;
};

struct D12Resource
{
    u32 id;
    ID3D12Resource* state;
    D3D12_FEATURE_DATA_FORMAT_SUPPORT format_support;
    u32 thread_id;
};

struct D12ResourceKey
{
    //u32 id;
    u64 id;//pointer to resource
    u32 thread_id;
};

struct D12ResourceStateEntry
{
    D12Resource resource;
    D12CommandListEntry list;
    D3D12_RESOURCE_STATES state;
};

struct CompatibilityProfile
{
    int level;
}typedef CompatibilityProfile;

struct RenderDevice
{
    void* device;
    void* device_context;
    u32 max_render_targets;//GRAPHICS_MAX_RENDER_TARGETS;
    CompatibilityProfile profile;
    //TODO(Ray):- newArgumentEncoderWithArguments:
    //Creates a new argument encoder for a specific array of arguments.
    //Required.
    //ArgumentBuffersTier argument_buffers_support;
    //This limit is only applicable to samplers that have their supportArgumentBuffers property set to YES.
    u32 max_argument_buffer_sampler_count;
}typedef RenderDevice;

struct CreateDeviceResult
{
    bool is_init;
    int compatible_level;
    f2 dim;
    RenderDevice device;
}typedef CreateDeviceResult;

struct CommandAllocToListResult
{
    D12CommandListEntry list;
    u64 index;
    bool found;
};

struct PipelineStateStream
{
    CD3DX12_PIPELINE_STATE_STREAM_ROOT_SIGNATURE pRootSignature;
    CD3DX12_PIPELINE_STATE_STREAM_INPUT_LAYOUT InputLayout;
    CD3DX12_PIPELINE_STATE_STREAM_PRIMITIVE_TOPOLOGY PrimitiveTopologyType;
    CD3DX12_PIPELINE_STATE_STREAM_VS VS;
    CD3DX12_PIPELINE_STATE_STREAM_PS PS;
    CD3DX12_PIPELINE_STATE_STREAM_DEPTH_STENCIL_FORMAT DSVFormat;
    CD3DX12_PIPELINE_STATE_STREAM_RENDER_TARGET_FORMATS RTVFormats;
    CD3DX12_PIPELINE_STATE_STREAM_RASTERIZER RasterizerState;
//    CD3DX12_PIPELINE_STATE_STREAM_BLEND_DESC blend_state;
//    CD3DX12_PIPELINE_STATE_STREAM_DEPTH_STENCIL1 depth_stencil_state;            
};

//Commands
enum CommandType
{
    CommandType_StartCommandList,
    CommandType_EndCommandList,
    CommandType_Draw,
    CommandType_DrawIndexed,
    CommandType_Viewport,
    CommandType_PipelineState,
    CommandType_RootSignature,
    CommandType_ScissorRect,
    CommandType_GraphicsRootDescTable,
    CommandType_GraphicsRootConstant,
    CommandType_SetVertexBuffer    
};

struct D12CommandHeader
{
    CommandType type;
    u32 pad;
};

struct D12CommandBasicDraw
{
    u32 vertex_offset;
    u32 count;
    D3D12_PRIMITIVE_TOPOLOGY topology;
    u32 heap_count;
    //ID3D12DescriptorHeap* heaps;
    D3D12_VERTEX_BUFFER_VIEW buffer_view;// TODO(Ray Garner): add a way to bind multiples
    // TODO(Ray Garner): add a way to bind multiples
};

struct D12CommandIndexedDraw
{
    u32 index_count;
    u32 index_offset;
    D3D12_PRIMITIVE_TOPOLOGY topology;
    u32 heap_count;
//    D3D12_VERTEX_BUFFER_VIEW uv_view;
//    D3D12_VERTEX_BUFFER_VIEW buffer_view;// TODO(Ray Garner): add a way to bind multiples
    
    D3D12_INDEX_BUFFER_VIEW index_buffer_view;
    // TODO(Ray Garner): add a way to bind multiples
};

struct D12CommandSetVertexBuffer
{
    u32 slot;
    D3D12_VERTEX_BUFFER_VIEW buffer_view;
};

struct D12CommandViewport
{
    f4 viewport;
};

struct D12CommandRootSignature
{
    ID3D12RootSignature* root_sig;
};

struct D12CommandPipelineState
{
    ID3D12PipelineState* pipeline_state;
};

struct D12CommandScissorRect
{
    CD3DX12_RECT rect; 
    //f4 rect;
};

struct D12CommandGraphicsRootDescTable
{
    u64 index;
    ID3D12DescriptorHeap* heap;
    D3D12_GPU_DESCRIPTOR_HANDLE gpu_handle;
};

struct D12CommandGraphicsRoot32BitConstant
{
    u32 index;
    u32 num_values;
    void* gpuptr;
    u32 offset;
};

struct D12CommandStartCommandList
{
    bool dummy;
    D3D12_CPU_DESCRIPTOR_HANDLE* handles;
};

struct D12CommandEndCommmandList
{
    bool dummy;
};

struct D12RenderTargets
{
    bool is_desc_range;
    u32 count;
    D3D12_CPU_DESCRIPTOR_HANDLE* descriptors;
    D3D12_CPU_DESCRIPTOR_HANDLE* depth_stencil_handle;
};


struct GPUMeshResource
{
    GPUArena vertex_buff;
    GPUArena normal_buff;
    GPUArena uv_buff;
    GPUArena tangent_buff;
    GPUArena element_buff;
    uint64_t hash_key;
    f2 buffer_range;
    u32 index_id;
};

struct GPUMemoryResult
{
    u64 Budget;
    u64 CurrentUsage;
    u64 AvailableForReservation;
    u64 CurrentReservation;
};

struct Texture
{
    void* texels;
    f2 dim;
    u32 size;
    u32 bytes_per_pixel;
    f32 width_over_height;// TODO(Ray Garner): probably remove
    f2 align_percentage;// TODO(Ray Garner): probably remove this
    u32 channel_count;//grey = 1: grey,alpha = 2,rgb = 3,rgba = 4
//    Texture texture;
    void* state;// NOTE(Ray Garner): temp addition
    uint32_t slot;
};

#include "d12_resource_state.h"

PlatformState local_copy_ps = {0};
//declarations

#define MAX_SRV_DESC_HEAP_COUNT 512// NOTE(Ray Garner): totally arbiturary number
#define GRAPHICS_MAX_RENDER_TARGETS 4
#define SHADER_DEBUG_FLAGS D3DCOMPILE_DEBUG | D3DCOMPILE_SKIP_OPTIMIZATION | D3DCOMPILE_PACK_MATRIX_ROW_MAJOR | D3DCOMPILE_PARTIAL_PRECISION | D3DCOMPILE_OPTIMIZATION_LEVEL0 | D3DCOMPILE_WARNINGS_ARE_ERRORS //| D3DCOMPILE_ENABLE_BACKWARDS_COMPATIBILITY
extern "C"
{
    void HandleWindowsMessages(PlatformState* ps);
    f2 GetWin32WindowDim(PlatformState* ps);
    f2 WINSetScreenMode(PlatformState* ps,bool is_full_screen);
    void PullTimeState(PlatformState* ps);
    void UpdateDigitalButton(DigitalButton* button,u32 state);
    void PullMouseState(PlatformState* ps);
    void PullDigitalButtons(PlatformState* ps);
    void SetButton(DigitalButton* button,u32 button_type,XINPUT_STATE state);
    void PullGamePads(PlatformState* ps);
//    int PlatformInit(PlatformState* ps,f2 window_dim,f2 window_p,int n_show_cmd);
    void testPlatformInit(PlatformState* ps,f32 window_dim);
    int PlatformInit(PlatformState* ps,f2 window_dim,f2 window_p,int n_show_cmd);
    bool platformtest(PlatformState* ps,f2 window_dim,f2 window_p);

    //Graphics
    CreateDeviceResult Init(HWND* window,f2 dim);
    
    void CreateDefaultDepthStencilBuffer(f2 dim);
    ID3D12RootSignature* CreateDefaultRootSig();    
    ID3D12Device2* GetDevice();
    u32 GetCurrentBackBufferIndex(IDXGISwapChain4* swap_chain);
    ID3D12Resource* GetCurrentBackBuffer();
    void EndFrame();
    void* AddCommand_(u32 size);
    void AddSetVertexBufferCommand(u32 slot,D3D12_VERTEX_BUFFER_VIEW buffer_view);    
    void AddDrawIndexedCommand(u32 index_count,u32 index_offset,D3D12_PRIMITIVE_TOPOLOGY topology,D3D12_INDEX_BUFFER_VIEW index_buffer_view);    
    void AddDrawCommand(u32 offset,u32 count,D3D12_PRIMITIVE_TOPOLOGY topology);    
    void AddViewportCommand(f4 vp);    
    void AddRootSignatureCommand(ID3D12RootSignature* root);    
    void AddPipelineStateCommand(ID3D12PipelineState* ps);    
    void AddScissorRectCommand(f4 rect);    
    void AddStartCommandListCommand(D3D12_CPU_DESCRIPTOR_HANDLE* handles);
    
    void AddEndCommandListCommand();    
// TODO(Ray Garner): Replace these with something later
    void AddGraphicsRootDescTable(u64 index,ID3D12DescriptorHeap* heaps,D3D12_GPU_DESCRIPTOR_HANDLE gpu_handle);    
    void AddGraphicsRoot32BitConstant(u32 index,u32 num_values,void* gpuptr,u32 offset);    
    GPUMemoryResult QueryGPUFastMemory();
    void CompileShader_(char* file_name,void** blob,char* shader_version_and_type);
    void CompileShaderText_(char* shader_text,int text_size,void** blob,char* shader_version_and_type);
    ID3D12PipelineState* CreateGraphicsPipelineState(ID3D12Device2* device,D3D12_GRAPHICS_PIPELINE_STATE_DESC *pDesc);

    D3D12_SHADER_BYTECODE GetShaderByteCode(ID3DBlob* blob);

    ID3D12PipelineState*  CreatePipelineState(ID3D12Device2* device,D3D12_PIPELINE_STATE_STREAM_DESC pssd);
    
    PipelineStateStream CreateDefaultPipelineStateStreamDesc(D3D12_INPUT_ELEMENT_DESC* input_layout,int input_layout_count,ID3DBlob* vs_blob,ID3DBlob* fs_blob,bool depth_enable = false);
    ID3D12DescriptorHeap* CreateDescriptorHeap(ID3D12Device2* device,u32 num_desc,D3D12_DESCRIPTOR_HEAP_TYPE type,D3D12_DESCRIPTOR_HEAP_FLAGS  flags);
    D3D12_DESCRIPTOR_HEAP_DESC  GetDesc(ID3D12DescriptorHeap* desc_heap);
    D3D12_GPU_DESCRIPTOR_HANDLE GetGPUDescriptorHandleForHeapStart(ID3D12DescriptorHeap* desc_heap);
    D3D12_CPU_DESCRIPTOR_HANDLE GetCPUDescriptorHandleForHeapStart(ID3D12DescriptorHeap* desc_heap); 
//    void Texture2D(Texture* lt,u32 heap_index,D12Resource* tex_resource);
    void Texture2D(Texture* lt,u32 heap_index,D12Resource* tex_resource,ID3D12DescriptorHeap* heap);
    HRESULT CreateCommittedResource(ID3D12Device2* device,
                                 D3D12_HEAP_PROPERTIES *pHeapProperties,
                                 D3D12_HEAP_FLAGS HeapFlags,
                                 D3D12_RESOURCE_DESC *pDesc,
                                 D3D12_RESOURCE_STATES InitialResourceState,
                                 D3D12_CLEAR_VALUE *pOptimizedClearValue,
                                 ID3D12Resource** resource);
        
    GPUArena AllocateGPUArena(ID3D12Device2* device,u64 size);
    GPUArena AllocateStaticGPUArena(ID3D12Device2* device,u64 size);
    
    void UploadBufferData(GPUArena* g_arena,void* data,u64 size);    
    void SetArenaToVertexBufferView(GPUArena* g_arena,u64 size,u32 stride);    
    void SetArenaToIndexVertexBufferView(GPUArena* g_arena,u64 size,DXGI_FORMAT format);
    void SetArenaToConstantBuffer(GPUArena* arena,u32 heap_index);
    UINT GetDescriptorHandleIncrementSize(ID3D12Device2* device, D3D12_DESCRIPTOR_HEAP_TYPE DescriptorHeapType);

    void CreateShaderResourceView(ID3D12Device2* device,ID3D12Resource* resource,D3D12_SHADER_RESOURCE_VIEW_DESC* desc,D3D12_CPU_DESCRIPTOR_HANDLE handle);
    void CreateConstantBufferView(ID3D12Device2* device,D3D12_CONSTANT_BUFFER_VIEW_DESC* desc,D3D12_CPU_DESCRIPTOR_HANDLE handle);
    
    HRESULT Map(ID3D12Resource* resource,u32 sub_resource,D3D12_RANGE* range,void** data);
    void Unmap(ID3D12Resource* resource,UINT Subresource,D3D12_RANGE *pWrittenRange);

    ID3D12CommandQueue* CreateCommandQueue(ID3D12Device2* device, D3D12_COMMAND_LIST_TYPE type);
    IDXGISwapChain4* CreateSwapChain(HWND hWnd,ID3D12CommandQueue* commandQueue,u32 width, u32 height, u32 bufferCount);
    void UpdateRenderTargetViews(ID3D12Device2* device,IDXGISwapChain4* swapChain, ID3D12DescriptorHeap* descriptorHeap);
    ID3D12Fence* CreateFence(ID3D12Device2* device);
    HANDLE CreateEventHandle();
    ID3D12CommandAllocator* CreateCommandAllocator(ID3D12Device2* device, D3D12_COMMAND_LIST_TYPE type);
    ID3D12GraphicsCommandList* CreateCommandList(ID3D12Device2* device,ID3D12CommandAllocator* commandAllocator, D3D12_COMMAND_LIST_TYPE type);
    HRESULT ResetCommandAllocator(ID3D12CommandAllocator* a);
    HRESULT ResetCommandList(ID3D12GraphicsCommandList* list,ID3D12CommandAllocator *pAllocator,ID3D12PipelineState *pInitialState);
    HRESULT CloseCommandList(ID3D12GraphicsCommandList* list);    
    HRESULT D3D12UpdateSubresources(ID3D12GraphicsCommandList* pCmdList, ID3D12Resource* pDestinationResource, ID3D12Resource* pIntermediate,u32 FirstSubresource,u32 NumSubresources,u64 RequiredSize,D3D12_SUBRESOURCE_DATA* pSrcData);
    bool IsFenceComplete(ID3D12Fence* fence,u64 fence_value);

    void ExecuteCommandLists(ID3D12CommandQueue* queue, ID3D12CommandList*  const* lists,u32 list_count);
    
    //    void ExecuteCommandLists(ID3D12CommandList* lists,u32 list_count);
    u64 Signal(ID3D12CommandQueue* commandQueue, ID3D12Fence* fence,u64* fenceValue);    
    HRESULT SetEventOnCompletion(ID3D12Fence* fence,UINT64 Value,HANDLE hEvent);
    HRESULT SignalCommandQueue(ID3D12CommandQueue* commandQueue,ID3D12Fence *pFence,UINT64 Value);
    void WaitForFenceValue(ID3D12Fence* fence, u64 fenceValue, HANDLE fenceEvent,double duration);

    bool CheckFeatureSupport(ID3D12Device2* device,D3D12_FEATURE Feature,void *pFeatureSupportData,UINT FeatureSupportDataSize);
    
    u64 GetIntermediateSize(ID3D12Resource* resource,u32 firstSubResource,u32 NumSubresources);
    void CreateDepthStencilView(ID3D12Device2* device,ID3D12Resource *pResource,D3D12_DEPTH_STENCIL_VIEW_DESC *pDesc,  D3D12_CPU_DESCRIPTOR_HANDLE DestDescriptor);

    ID3D12RootSignature* CreateRootSignature(ID3D12Device2* device,D3D12_ROOT_PARAMETER1* params,int param_count,D3D12_STATIC_SAMPLER_DESC* samplers,int sampler_count,D3D12_ROOT_SIGNATURE_FLAGS flags);

    void TransitionResource(D12CommandListEntry cle,ID3D12Resource* resource,D3D12_RESOURCE_STATES from,D3D12_RESOURCE_STATES to);
    void ClearRenderTargetView(ID3D12GraphicsCommandList* list,D3D12_CPU_DESCRIPTOR_HANDLE RenderTargetView,FLOAT ColorRGBA[4] ,UINT NumRects,D3D12_RECT *pRects);
    void ClearDepthStencilView(ID3D12GraphicsCommandList* list,
                           D3D12_CPU_DESCRIPTOR_HANDLE DepthStencilView,
                           D3D12_CLEAR_FLAGS           ClearFlags,
                           f32                       Depth,
                           u8                       Stencil,
                           u32                        NumRects,
                               D3D12_RECT            *pRects);
    void OMSetRenderTargets(ID3D12GraphicsCommandList* list,u32 NumRenderTargetDescriptors,D3D12_CPU_DESCRIPTOR_HANDLE *pRenderTargetDescriptors,bool RTsSingleHandleToDescriptorRange,D3D12_CPU_DESCRIPTOR_HANDLE *pDepthStencilDescriptor); 
    void OMSetBlendFactor(ID3D12GraphicsCommandList* list,float BlendFactor[4]); 
    void OMSetStencilRef(ID3D12GraphicsCommandList* list,UINT ref);
    void RSSetViewports(ID3D12GraphicsCommandList* list,u32 NumViewports,D3D12_VIEWPORT *pViewports);
    void RSSetScissorRects(ID3D12GraphicsCommandList* list,u32 NumRects,D3D12_RECT *pRects);
    void IASetPrimitiveTopology(ID3D12GraphicsCommandList*list,D3D12_PRIMITIVE_TOPOLOGY PrimitiveTopology);
    void DrawInstanced(ID3D12GraphicsCommandList* list,u32 VertexCountPerInstance,u32 InstanceCount,u32 StartVertexLocation,u32 StartInstanceLocation);
    void DrawIndexedInstanced(ID3D12GraphicsCommandList* list,u32 IndexCountPerInstance,u32 InstanceCount,u32 StartIndexLocation,s32  BaseVertexLocation,u32 StartInstanceLocation);    
    void IASetIndexBuffer(ID3D12GraphicsCommandList* list,D3D12_INDEX_BUFFER_VIEW *pView);
    void IASetVertexBuffers(ID3D12GraphicsCommandList* list,u32 StartSlot,u32 NumViews,D3D12_VERTEX_BUFFER_VIEW *pViews);
    void SetPipelineState(ID3D12GraphicsCommandList* list,ID3D12PipelineState *pPipelineState);
    void SetDescriptorHeaps(ID3D12GraphicsCommandList* list,u32 NumDescriptorHeaps,ID3D12DescriptorHeap* const* ppDescriptorHeaps);    
    void SetGraphicsRootDescriptorTable(ID3D12GraphicsCommandList* list, u32 RootParameterIndex,D3D12_GPU_DESCRIPTOR_HANDLE BaseDescriptor);
    void SetGraphicsRoot32BitConstants(ID3D12GraphicsCommandList* list,u32 RootParameterIndex,u32 Num32BitValuesToSet,void *pSrcData,u32 DestOffsetIn32BitValues);
    void SetGraphicsRootSignature(ID3D12GraphicsCommandList* list,ID3D12RootSignature *pRootSignature);    
    HRESULT Present(IDXGISwapChain4* swap_chain,u32 SyncInterval,u32 Flags);
    HRESULT GetBuffer(IDXGISwapChain4* swapChain,UINT Buffer,ID3D12Resource** ppSurface);
    void CreateRenderTargetView(ID3D12Device2* device,ID3D12Resource *pResource,D3D12_RENDER_TARGET_VIEW_DESC *pDesc,D3D12_CPU_DESCRIPTOR_HANDLE DestDescriptor);
    ID3D12Device2* CreateDevice(IDXGIAdapter4* adapter);
    IDXGIAdapter4* GetAdapter(bool useWarp);
    D3D12_GPU_VIRTUAL_ADDRESS GetGPUVirtualAddress(ID3D12Resource* resource);
    void CopyTextureRegion(ID3D12GraphicsCommandList* list,D3D12_TEXTURE_COPY_LOCATION *pDst,UINT DstX,UINT DstY,UINT DstZ,D3D12_TEXTURE_COPY_LOCATION *pSrc,D3D12_BOX *pSrcBox);
    void ResourceBarrier(ID3D12GraphicsCommandList* list, UINT NumBarriers,D3D12_RESOURCE_BARRIER *pBarriers);
}
//end declare

