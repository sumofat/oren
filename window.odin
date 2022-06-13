package oren
import platform "engine/platform"
import windows "core:sys/windows"
import runtime "core:runtime"
import la "core:math/linalg"

Wnd_Proc :: proc "std" (hwnd : windows.HWND, uMsg : u32, wParam : windows.WPARAM, lParam : windows.LPARAM) -> windows.LRESULT{
	context = runtime.default_context();
	platform.ImGui_ImplWin32_WndProcHandler(hwnd, uMsg, wParam, lParam);//{

    switch (uMsg){
    	case windows.WM_DESTROY:{
    	    windows.PostQuitMessage(0);
    	    return 0;
        }
    	case windows.WM_PAINT:{
    	    ps : windows.PAINTSTRUCT = {};
    	    hdc : windows.HDC = windows.BeginPaint(hwnd, &ps);
    	    //windows.fill_rect(hdc, &ps.rcPaint, windows.COLOR_BACKGROUND);
    	    windows.EndPaint(hwnd, &ps);
    	    return 0;
    	}
    }
    return windows.DefWindowProcA(hwnd, uMsg, wParam, lParam);
}

WindowData :: struct {
    hInstance : windows.HINSTANCE,
    hwnd : windows.HWND,
    width : u32,
    height : u32,
};

ErrorStr :: cstring;
GWL_STYLE :: -16
set_screen_mode :: proc(ps : ^platform.PlatformState,is_full_screen : bool)-> la.Vector2f32{
	return platform.WINSetScreenMode(ps,is_full_screen)
}

spawn_window :: proc(ps : ^platform.PlatformState,windowName : cstring, width : u32 = 640, height : u32 = 480 ) -> (ErrorStr, WindowData){
    // Register the window class.
    using la;
	window : WindowData;

    CLASS_NAME : cstring = "Main Window";

    wc : windows.WNDCLASSEXA = {}; 
    hInstance := cast(windows.HINSTANCE)(windows.GetModuleHandleA(nil));
    ps.is_running = true;
    ps.window.dim = Vector2f32{f32(width), f32(height)};
    ps.window.p = Vector2f32{};
    
    wc.cbSize = size_of(windows.WNDCLASSEXA);
    wc.lpfnWndProc = Wnd_Proc;
    wc.hInstance = hInstance;
    wc.lpszClassName = CLASS_NAME;

    if windows.RegisterClassExA(&wc) == 0 do return "Failed to register class!", window;

    hwnd := windows.CreateWindowExA(
        0,
        CLASS_NAME,
        windowName,
        windows.WS_OVERLAPPEDWINDOW | windows.WS_VISIBLE,
        windows.CW_USEDEFAULT, windows.CW_USEDEFAULT, i32(ps.window.dim.x), i32(ps.window.dim.y),
        nil,
        nil,
        hInstance,
        nil,
    );

    ps.window.handle = hwnd;
    
    if hwnd == nil do return "failed to create window!", window;

    
    window.hInstance = hInstance;
    window.hwnd = hwnd;
    window.width = width;
    window.height = height;

    return nil, window;
}

handle_msgs :: proc(window : ^WindowData) -> bool{
    msg : windows.MSG = {};
    cont : bool = true;
    for windows.PeekMessageA(&msg, nil, 0, 0, windows.PM_REMOVE){ 
        if msg.message == windows.WM_QUIT do cont = false;
        windows.TranslateMessage(&msg);
        windows.DispatchMessageA(&msg);
    }
    return cont;
}
