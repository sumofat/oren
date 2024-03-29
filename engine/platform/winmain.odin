package platform
//Seems to work fine we will move on to getting the directx12 renderering stuff to work as a lib now.
//and a window which will be more challenging.
import "core:fmt"
import "core:c"
import windows "core:sys/windows"
import fmj "../fmj"
import la "core:math/linalg"
import math "../math"

MAX_KEYS : int : 256;
MAX_CONTROLLER_SUPPORT : int : 2;

Keys :: struct
{
    w : u32,
    e : u32,
    r : u32,
    a : u32,
    s : u32,
    d : u32,
    f : u32,
    i : u32,
    j : u32,
    k : u32,
    l : u32,
    f1 : u32,
    f2 : u32,
    f3 : u32,
};

keys : Keys;

Time :: struct
{
    frame_index : u64,
    delta_seconds : f32,
    delta_ticks : u64,
    delta_nanoseconds : u64,
    delta_microseconds : u64,
    delta_miliseconds : u64,

    delta_samples : u64,
    
    time_seconds : f64,
    time_ticks : u64,
    time_nanoseconds : u64,
    time_microseconds : u64,
    time_miliseconds : u64,

    ticks_per_second : u64,
    initial_ticks : u64,

    prev_ticks : u64,
};

DigitalButton :: struct
{
    down : bool,
    pressed : bool,
    released : bool,
};

Keyboard :: struct
{
    keys: [MAX_KEYS]DigitalButton,    
};

AnalogButton :: struct
{
    threshold : f32,
    value : f32,
    down : bool,
    pressed : bool,
    released : bool,
};

Axis :: struct
{
    value : f32,
    threshold : f32,
};

//TODO(Ray):Handle other types of axis like ruddder/throttle etc...
Stick :: struct
{
    X : Axis,
    Y : Axis,
};

XINPUT_GAMEPAD :: struct
{
    wButtons : u16,
    bLeftTrigger : u8,
    bRightTrigger : u8,
    sThumbLX : u16,
    sThumbLY : u16,
    sThumbRX : u16,
    sThumbRY : u16,
};

XINPUT_STATE :: struct
{
    dwPacketNumber : u32,
    Gamepad : XINPUT_GAMEPAD,
};

GamePad :: struct
{
    state : XINPUT_STATE ,    
    
    left_stick : Stick,
    right_stick : Stick,
 
    left_shoulder : Axis,
    right_shoulder : Axis,

    up : DigitalButton,
    down : DigitalButton,
    left : DigitalButton,
    right : DigitalButton,
 
    a : DigitalButton,
    b : DigitalButton,
    x : DigitalButton,
    y : DigitalButton,

    l : DigitalButton,
    r : DigitalButton,

    select : DigitalButton,
    start : DigitalButton,    
};

Mouse :: struct
{
    p : la.Vector2f32,
    prev_p : la.Vector2f32,
    delta_p : la.Vector2f32,
    uv : la.Vector2f32,
    prev_uv : la.Vector2f32,
    delta_uv : la.Vector2f32,

    lmb : DigitalButton,//left_mouse_button
    rmb : DigitalButton,
    wrap_mode : bool,
};

Input :: struct
{
    keyboard : Keyboard,
    mouse : Mouse,
    game_pads : [MAX_CONTROLLER_SUPPORT]GamePad,
};

Window :: struct
{
    w_class : windows.WNDCLASSA,
    handle : windows.HWND,
    device_context : windows.HDC,
    global_window_p : windows.WINDOWPLACEMENT,
    dim : la.Vector2f32,
    p : la.Vector2f32,
    is_full_screen_mode : bool,
};

TRACKMOUSEEVENT :: struct{
  cbSize : windows.DWORD,
  dwFlags : windows.DWORD,
  hwndTrack : windows.HWND,
  dwHoverTime : windows.DWORD,
};

TME_LEAVE :: 0x00000002;
WM_MOUSELEAVE :: 0x02A3;
WHEEL_DELTA :: 120;
GET_WHEEL_DELTA_WPARAM :: windows.HIWORD;
HTCLIENT :: 1; //in a client area
DBT_DEVNODES_CHANGED :: 0x0007;//device has been added to or removed from the system.
WM_DEVICECHANGE :: 0x0219;

foreign import winkernal "system:kernel32.lib";
foreign import platform "../../library/windows/build/win32.lib"

S_OK :: 0x00000000;

@(default_calling_convention="c")
foreign platform
{
//    testPlatformInit :: proc(ps : ^PlatformState,window_dim : f32) ---;
    platformtest :: proc "c" (ps : ^PlatformState,window_dim : la.Vector2f32,window_p : la.Vector2f32) -> bool ---;
    PlatformInit :: proc "c" (ps : ^PlatformState,window_dim : la.Vector2f32,window_p : la.Vector2f32,n_show_cmd : c.int) -> bool ---;    
    HandleWindowsMessages :: proc "c" (ps : ^PlatformState) ---;
    PullMouseState :: proc "c"(ps : ^PlatformState) ---;
    PullTimeState :: proc "c"(ps : ^PlatformState) ---;
    CreateDefaultDepthStencilBuffer :: proc "c"(dim : la.Vector2f32) ---;
    CreateDefaultRootSig :: proc "c"()  -> rawptr ---;    
    GetDevice :: proc "c"() -> rawptr ---;
    GetCurrentBackBufferIndex :: proc "c"(swap_chain : rawptr) -> u32 ---;
    GetCurrentBackBuffer :: proc "c"() -> rawptr ---;
    AddCommand_ :: proc "c"(size : u32) -> rawptr ---;
    AddHeader :: proc "c"(type : CommandType) ---;    
    AddSetVertexBufferCommand :: proc "c"(slot : u32 ,buffer_view : D3D12_VERTEX_BUFFER_VIEW) ---;
    AddDrawIndexedCommand :: proc "c"(index_count : u32 ,index_offset : u32 ,topology : D3D12_PRIMITIVE_TOPOLOGY, index_buffer_view : D3D12_INDEX_BUFFER_VIEW) ---;
    AddDrawCommand :: proc(offset : u32,count : u32, topology : D3D12_PRIMITIVE_TOPOLOGY) ---;
    AddViewportCommand :: proc "c"(vp : math.f4) ---;
    AddRootSignatureCommand :: proc "c"(root_sig_ptr : rawptr/*ID3D12RootSignature*/) ---;
    AddPipelineStateCommand :: proc "c" (ps_ptr : rawptr/*ID3D12PipelineState*/) ---;
    AddScissorRectCommand :: proc "c"(rect : math.f4) ---;
    AddStartCommandListCommand :: proc "c"() ---;
    AddEndCommandListCommand :: proc "c"() ---;
    AddGraphicsRootDescTable :: proc "c" (index : u64,heaps_ptr : rawptr/*ID3D12DescriptorHeap**/,gpu_handle : D3D12_GPU_DESCRIPTOR_HANDLE) ---;
    AddGraphicsRoot32BitConstant :: proc "c"(index : u32,num_values : u32,gpuptr : rawptr,offset : u32) ---;
    QueryGPUFastMemory :: proc "c" ()-> GPUMemoryResult ---;
    CompileShader_ :: proc "c" (file_name : cstring,blob : ^rawptr/*void** */,shader_version_and_type : cstring) ---;
    //CompileShaderText_ :: proc "c" (file : cstring,blob : ^rawptr/*void** */,shader_version_and_type : cstring) ---;
    CompileShaderText_ :: proc "c"(shader_text : cstring,text_size : c.int,blob : ^rawptr,shader_version_and_type : cstring) ---;

    GetShaderByteCode :: proc"c"(blob : rawptr) -> D3D12_SHADER_BYTECODE ---;
    CreatePipelineState :: proc "c"(device : rawptr,pssd : D3D12_PIPELINE_STATE_STREAM_DESC)->  rawptr ---;//ID3D12PipelineState*  ;
    CreateDefaultPipelineStateStreamDesc :: proc "c"(input_layout : ^D3D12_INPUT_ELEMENT_DESC ,input_layout_count : c.int,vs_blob : rawptr,fs_blob : rawptr,depth_enable : bool) -> PipelineStateStream ---;
//    CreateDescriptorHeap :: proc "c"(device : rawptr,desc : D3D12_DESCRIPTOR_HEAP_DESC,num_of_descriptors : u32) -> rawptr /*ID3D12DescriptorHeap* */ ---;
    CreateDescriptorHeap :: proc "c"(device : rawptr,num_desc : u32,type : D3D12_DESCRIPTOR_HEAP_TYPE,flags : D3D12_DESCRIPTOR_HEAP_FLAGS)-> rawptr --- /*ID3D12DescriptorHeap**/ ;    
    GetDesc :: proc "c"(desc_heap : rawptr) ->  D3D12_DESCRIPTOR_HEAP_DESC ---;
    GetGPUVirtualAddress :: proc "c"(resource : rawptr /*ID3D12Resource* */) -> D3D12_GPU_VIRTUAL_ADDRESS ---;
    GetGPUDescriptorHandleForHeapStart :: proc "c"(desc_heap : rawptr) ->D3D12_GPU_DESCRIPTOR_HANDLE ---;    
    GetCPUDescriptorHandleForHeapStart :: proc "c"(desc_heap : rawptr)-> D3D12_CPU_DESCRIPTOR_HANDLE ---;
    CreateCommandAllocator ::  proc "c"(device : rawptr,type : D3D12_COMMAND_LIST_TYPE) -> rawptr ---/*ID3D12CommandAllocator**/;
    CreateCommandList :: proc "c"(device : rawptr,commandAllocator : rawptr/*^ID3D12CommandAllocator*/, type  : D3D12_COMMAND_LIST_TYPE) -> rawptr---;//ID3D12GraphicsCommandList* ;
    CreateFence :: proc "c"(device : rawptr) -> rawptr/*ID3D12Fence**/---;
    CreateEventHandle :: proc "c"() ->windows.HANDLE ---;
    IsFenceComplete :: proc "c"(fence : rawptr /*ID3D12Fence* */,fence_value : u64) -> bool ---;
    GetForegroundWindow :: proc "c"() ->  windows.HWND ---;
    IsChild :: proc "c"(hWndParent : windows.HWND,hWnd : windows.HWND) -> bool ---;
    //TrackMouseEvent :: proc "c"(lpEventTrack : ^TRACKMOUSEEVENT) -> bool ---;
    CopyTextureRegion :: proc "c" (list : rawptr,pDst : ^D3D12_TEXTURE_COPY_LOCATION,DstX : c.uint,DstY : c.uint,DstZ : c.uint,pSrc : ^D3D12_TEXTURE_COPY_LOCATION,pSrcBox : ^D3D12_BOX) ---;
    WaitForSingleObject :: proc "c" (hHandle : windows.HANDLE,dwMilliseconds : windows.DWORD) -> windows.DWORD ---;
    WINSetScreenMode :: proc "c"(ps : ^PlatformState,is_full_screen : bool) -> la.Vector2f32 ---;
    OutputDebugStringW :: proc "c"(lpOutputString : cstring) ---
}



@(default_calling_convention="c")
foreign winkernal
{
    InterlockedExchangeAdd64 :: proc "c"(dst: ^i64, desired: i64) -> i64 ---;    
}

AddCommand :: proc($T: typeid) -> ^T
{
    return (^T)(AddCommand_(size_of(T)));
}    


