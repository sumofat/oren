package platform
//Seems to work fine we will move on to getting the directx12 renderering stuff to work as a lib now.
//and a window which will be more challenging.
import "core:fmt"
import "core:c"
import windows "core:sys/windows"
import window32 "core:sys/win32"
import fmj "../fmj"
import la "core:math/linalg"

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
    p : la.Vector2,
    prev_p : la.Vector2,
    delta_p : la.Vector2,
    uv : la.Vector2,
    prev_uv : la.Vector2,
    delta_uv : la.Vector2,

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

POINT :: struct
{
    x : u32,
    y : u32
};

RECT :: struct
{
    left : u32,
    top : u32,
    right : u32,
    bottom : u32,
};

Window :: struct
{
    w_class : window32.Wnd_Class_A,
    handle : window32.Hwnd,
    device_context : window32.Hdc,
    global_window_p : window32.Window_Placement,
    dim : la.Vector2,
    p : la.Vector2,
    is_full_screen_mode : bool,
};

foreign import platform "../../library/windows/build/win32.lib"

@(default_calling_convention="c")
foreign platform
{
//    testPlatformInit :: proc(ps : ^PlatformState,window_dim : f32) ---;
    platformtest :: proc "c" (ps : ^PlatformState,window_dim : la.Vector2,window_p : la.Vector2) -> bool ---;
    PlatformInit :: proc "c" (ps : ^PlatformState,window_dim : la.Vector2,window_p : la.Vector2,n_show_cmd : c.int) -> bool ---;    
    HandleWindowsMessages :: proc "c" (ps : ^PlatformState) ---;
    Init :: proc "c" (window : ^window32.Hwnd,dim : la.Vector2) -> CreateDeviceResult ---;
    CreateDefaultDepthStencilBuffer :: proc "c"(dim : la.Vector2) ---;
    CreateDefaultRootSig :: proc "c"()  -> rawptr ---;    
    GetDevice :: proc "c"() -> rawptr ---;
    GetCurrentBackBufferIndex :: proc "c"() -> u32 ---;
    GetCurrentBackBuffer :: proc "c"() -> rawptr ---;
    EndFrame :: proc "c"() ---;
    AddCommand_ :: proc "c"(size : u32) -> rawptr ---;
    AddHeader :: proc "c"(type : CommandType) ---;    
    AddSetVertexBufferCommand :: proc "c"(slot : u32 ,buffer_view : D3D12_VERTEX_BUFFER_VIEW) ---;
    AddDrawIndexedCommand :: proc "c"(index_count : u32 ,index_offset : u32 ,topology : D3D12_PRIMITIVE_TOPOLOGY, index_buffer_view : D3D12_INDEX_BUFFER_VIEW) ---;
    AddDrawCommand :: proc(offset : u32,count : u32, topology : D3D12_PRIMITIVE_TOPOLOGY) ---;
    AddViewportCommand :: proc "c"(vp : fmj.f4) ---;
    AddRootSignatureCommand :: proc "c"(root_sig_ptr : rawptr/*ID3D12RootSignature*/) ---;
    AddPipelineStateCommand :: proc "c" (ps_ptr : rawptr/*ID3D12PipelineState*/) ---;
    AddScissorRectCommand :: proc "c"(rect : fmj.f4) ---;
    AddStartCommandListCommand :: proc "c"() ---;
    AddEndCommandListCommand :: proc "c"() ---;
    AddGraphicsRootDescTable :: proc "c" (index : u64,heaps_ptr : rawptr/*ID3D12DescriptorHeap**/,gpu_handle : D3D12_GPU_DESCRIPTOR_HANDLE) ---;
    AddGraphicsRoot32BitConstant :: proc "c"(index : u32,num_values : u32,gpuptr : rawptr,offset : u32) ---;
    QueryGPUFastMemory :: proc "c" ()-> GPUMemoryResult ---;
    CompileShader_ :: proc "c" (file_name : cstring,blob : ^rawptr/*void** */,shader_version_and_type : cstring) ---;
    GetShaderByteCode :: proc"c"(blob : rawptr) -> D3D12_SHADER_BYTECODE ---;
    CreatePipelineState :: proc "c"(pssd : D3D12_PIPELINE_STATE_STREAM_DESC)->  rawptr ---;//ID3D12PipelineState*  ;
    CreateDefaultPipelineStateStreamDesc :: proc "c"(input_layout : ^D3D12_INPUT_ELEMENT_DESC ,input_layout_count : c.int,vs_blob : rawptr,fs_blob : rawptr,depth_enable : bool) -> PipelineStateStream ---;
    CreateDescriptorHeap :: proc "c"(device : rawptr,desc : D3D12_DESCRIPTOR_HEAP_DESC) -> rawptr /*ID3D12DescriptorHeap* */ ---;
    GetDesc :: proc "c"(desc_heap : rawptr) ->  D3D12_DESCRIPTOR_HEAP_DESC ---;
    GetGPUDescriptorHandleForHeapStart :: proc "c"(desc_heap : rawptr) ->D3D12_GPU_DESCRIPTOR_HANDLE ---;    
    GetCPUDescriptorHandleForHeapStart :: proc "c"(desc_heap : rawptr)-> D3D12_CPU_DESCRIPTOR_HANDLE ---;    
}

AddCommand :: proc($T: typeid) -> ^T
{
    return (^T)(AddCommand_(size_of(T)));
}    


