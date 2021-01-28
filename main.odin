package main

import "core:fmt"
import "core:c"
import windows "core:sys/windows"
import window32 "core:sys/win32"
 
ErrorStr :: cstring;

WindowData :: struct {
    hInstance : window32.Hinstance,
    hwnd : window32.Hwnd,
    width : u32,
    height : u32,
};

Wnd_Proc :: proc "std" (hwnd : window32.Hwnd, uMsg : u32, wParam : window32.Wparam, lParam : window32.Lparam) -> window32.Lresult
{
    switch (uMsg)
	{
		case window32.WM_DESTROY:
        {
			window32.post_quit_message(0);
			return 0;
        }
		case window32.WM_PAINT:
		{
			ps : window32.Paint_Struct = {};
			hdc : window32.Hdc = window32.begin_paint(hwnd, &ps);

			//window32.fill_rect(hdc, &ps.rcPaint, window32.COLOR_BACKGROUND);

			window32.end_paint(hwnd, &ps);
			return 0;
		}
	}
	return window32.def_window_proc_a(hwnd, uMsg, wParam, lParam);
}

spawn_window :: proc(windowName : cstring, width : u32 = 640, height : u32 = 480 ) -> (ErrorStr, ^WindowData) {

	// Register the window class.
    CLASS_NAME : cstring = "Main Vulkan Window";

	wc : window32.Wnd_Class_Ex_A = {}; 

    hInstance := cast(window32.Hinstance)(window32.get_module_handle_a(nil));

    wc.size = size_of(window32.Wnd_Class_Ex_A);
	wc.wnd_proc = Wnd_Proc;
	wc.instance = hInstance;
	wc.class_name = CLASS_NAME;

	if window32.register_class_ex_a(&wc) == 0 do return "Failed to register class!", nil;

    hwnd := window32.create_window_ex_a(
        0,
        CLASS_NAME,
        windowName,
        window32.WS_OVERLAPPEDWINDOW | window32.WS_VISIBLE,
        window32.CW_USEDEFAULT, window32.CW_USEDEFAULT, 640, 480,
        nil,
        nil,
        hInstance,
        nil,
    );

    if hwnd == nil do return "failed to create window!", nil;

    window := new(WindowData);
    window.hInstance = hInstance;
    window.hwnd = hwnd;
    window.width = width;
    window.height = height;

    return nil, window;
}

handle_msgs :: proc(window : ^WindowData) -> bool
{
    msg : window32.Msg = {};
    cont : bool = true;
    for window32.peek_message_a(&msg, nil, 0, 0, window32.PM_REMOVE)
    { 
        if msg.message == window32.WM_QUIT do cont = false;
        window32.translate_message(&msg);
        window32.dispatch_message_a(&msg);
    }
    return cont;
}

//first test importing libs that we compile here with the foreign system.
//starting with simple C lib FMJ

foreign import fmj "library/fmj/build/fmj.lib"

@(default_calling_convention="c")
foreign fmj
{
    degrees :: proc "c" (x : f32) -> f32 ---;
    radians :: proc "c" (x : f32) -> f32 ---;
}
 
f2 :: struct
{
    x : f32,
    y: f32
}

//Seems to work fine we will move on to getting the directx12 renderering stuff to work as a lib now.
//and a window which will be more challenging.

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
    p : f2,
    prev_p : f2,
    delta_p : f2,
    uv : f2,
    prev_uv : f2,
    delta_uv : f2,

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

WINDOWPLACEMENT :: struct
{
    length : c.uint,
    flags :   c.uint,
    showCmd :   c.uint,
    ptMinPosition : POINT,
    ptMaxPosition : POINT,
    rcNormalPosition : POINT,
    rcDevice : RECT,
};

Window :: struct
{
    w_class : rawptr,
    handle : rawptr ,
    device_context : rawptr,
    global_window_p : WINDOWPLACEMENT,
    dim : f2,
    p : f2,
    is_full_screen_mode : bool,
};

PlatformState :: struct
{
    time : Time,
    input : Input,
//    Renderer renderer,
//    Audio audio,
    is_running : bool,    

    //TODO(Ray): NOTE(ray):This has some memory issue consider keeping it internal to the c side.
    window : Window,
//    Memory memory,
    //    info : windows.SYSTEM_INFO,
};

foreign import win32 "library/windows/build/win32_c.lib"

@(default_calling_convention="c")
foreign win32
{
//    testPlatformInit :: proc(ps : ^PlatformState,window_dim : f32) ---;
    platformtest :: proc "c" (ps : ^PlatformState,window_dim : f2,window_p : f2) -> bool ---;
    HandleWindowsMessages :: proc "c" (ps : ^PlatformState) ---;
}

//Get a window and some basic rendering working.
main :: proc()
{
    fmt.println("Hellope!");

    x :f32 = degrees(20);
    fmt.println(x);
    x = radians(x);
    fmt.println(x);    

    ps : PlatformState;
    window_dim := f2{1024,1024};
    window_p := f2{0,0};
    show_cmd : i32 = 0;
    ps.is_running  = true;

    //    testPlatformInit(&ps,100);
    //fmt.println(ps);
    fmt.println(ps.is_running);	        	    
    if !platformtest(&ps,window_dim,window_p)
    {
	fmt.println("Failed to initialize platform window!");
	assert(false);
    }
    else
    {
	fmt.println("Initialized platform window!");
	fmt.println(ps.is_running);
	
	for ps.is_running
	{
	    fmt.println("Checking windows messages...");
	    HandleWindowsMessages(&ps);
	    fmt.println(ps.is_running);	        		    
	}
    }

//    for ps.is_running
    {
//	fmt.println("Running a windows app!");		
    }
//    platformtest(&ps,100);

    //for ps.is_running
    {
//        if(ps->input.keyboard.keys[keys.s].down)
        {
//            ps->is_running = false;
        }
    }

    /*
    err, win := spawn_window("test",640,480 );

//time
    now : windows.LARGE_INTEGER;
    windows.QueryPerformanceFrequency(&now);
    ps.time.ticks_per_second = cast(u64)now;
    windows.QueryPerformanceCounter(&now);
    ps.time.initial_ticks = cast(u64)now;
    ps.time.prev_ticks = ps.time.initial_ticks;

//keys
    //TODO(Ray):Propery check for layouts
//    layout : HKL =  windows.LoadKeyboardLayout("00000409",0x00000001);

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

    for ;;
    {
	handle_msgs(win);
    }
*/    
}
 
