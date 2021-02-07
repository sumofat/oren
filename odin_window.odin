 
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

spawn_window :: proc(windowName : cstring, width : u32 = 640, height : u32 = 480 ) -> (ErrorStr, ^WindowData)
{
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
