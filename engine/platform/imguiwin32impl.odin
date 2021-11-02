// dear imgui: Platform Backend for Windows (standard windows API for 32 and 64 bits applications)
// This needs to be used along with a Renderer (e.g. DirectX11, OpenGL3, Vulkan..)

// Implemented features:
//  [X] Platform: Clipboard support (for Win32 this is actually part of core dear imgui)
//  [X] Platform: Mouse cursor shape and visibility. Disable with 'io.ConfigFlags |= ImGuiConfigFlags_NoMouseCursorChange'.
//  [X] Platform: Keyboard arrays indexed using VK_* Virtual Key Codes, e.g. ImGui::IsKeyPressed(VK_SPACE).
//  [X] Platform: Gamepad support. Enabled with 'io.ConfigFlags |= ImGuiConfigFlags_NavEnableGamepad'.

// You can use unmodified imgui_impl_* files in your project. See examples/ folder for examples of using this.
// Prefer including the entire imgui/ repository into your project (either as a copy or as a submodule), and only build the backends you need.
// If you are new to Dear ImGui, read documentation from the docs/ folder + read the top of imgui.cpp.
// Read online: https://github.com/ocornut/imgui/tree/master/docs
package platform;

import logger "../logger"

import imgui "../external/odin-imgui"
import win32 "core:sys/win32"
import win "core:sys/windows"
import "core:c"
import "../platform"
import "core:fmt"
//#include "imgui.h"
//#include "imgui_impl_win32.h"
//#ifndef WIN32_LEAN_AND_MEAN
//#define WIN32_LEAN_AND_MEAN
//#endif
//#include <windows.h>
//#include <tchar.h>
//#include <dwmapi.h>

// Configuration flags to add in your imconfig.h file:
//#define IMGUI_IMPL_WIN32_DISABLE_GAMEPAD              // Disable gamepad support. This was meaningful before <1.81 but we now load XInput dynamically so the option is now less relevant.

// Using XInput for gamepad (will load DLL dynamically)
//#ifndef IMGUI_IMPL_WIN32_DISABLE_GAMEPAD
//#include <xinput.h>
//typedef DWORD (WINAPI *PFN_XInputGetCapabilities)(DWORD, DWORD, XINPUT_CAPABILITIES*);
//typedef DWORD (WINAPI *PFN_XInputGetState)(DWORD, XINPUT_STATE*);
//#endif

// CHANGELOG
// (minor and older changes stripped away, please see git history for details)
//  2021-08-17: Calling io.AddFocusEvent() on WM_SETFOCUS/WM_KILLFOCUS messages.
//  2021-08-02: Inputs: Fixed keyboard modifiers being reported when host windo doesn't have focus.
//  2021-07-29: Inputs: MousePos is correctly reported when the host platform window is hovered but not focused (using TrackMouseEvent() to receive WM_MOUSELEAVE events).
//  2021-06-29: Reorganized backend to pull data from a single structure to facilitate usage with multiple-contexts (all g_XXXX access changed to bd->XXXX).
//  2021-06-08: Fixed ImGui_ImplWin32_EnableDpiAwareness() and ImGui_ImplWin32_GetDpiScaleForMonitor() to handle Windows 8.1/10 features without a manifest (per-monitor DPI, and properly calls SetProcessDpiAwareness() on 8.1).
//  2021-03-23: Inputs: Clearing keyboard down array when losing focus (WM_KILLFOCUS).
//  2021-02-18: Added ImGui_ImplWin32_EnableAlphaCompositing(). Non Visual Studio users will need to link with dwmapi.lib (MinGW/gcc: use -ldwmapi).
//  2021-02-17: Fixed ImGui_ImplWin32_EnableDpiAwareness() attempting to get SetProcessDpiAwareness from shcore.dll on Windows 8 whereas it is only supported on Windows 8.1.
//  2021-01-25: Inputs: Dynamically loading XInput DLL.
//  2020-12-04: Misc: Fixed setting of io.DisplaySize to invalid/uninitialized data when after hwnd has been closed.
//  2020-03-03: Inputs: Calling AddInputCharacterUTF16() to support surrogate pairs leading to codepoint >= 0x10000 (for more complete CJK inputs)
//  2020-02-17: Added ImGui_ImplWin32_EnableDpiAwareness(), ImGui_ImplWin32_GetDpiScaleForHwnd(), ImGui_ImplWin32_GetDpiScaleForMonitor() helper functions.
//  2020-01-14: Inputs: Added support for #define IMGUI_IMPL_WIN32_DISABLE_GAMEPAD/IMGUI_IMPL_WIN32_DISABLE_LINKING_XINPUT.
//  2019-12-05: Inputs: Added support for ImGuiMouseCursor_NotAllowed mouse cursor.
//  2019-05-11: Inputs: Don't filter value from WM_CHAR before calling AddInputCharacter().
//  2019-01-17: Misc: Using GetForegroundWindow()+IsChild() instead of GetActiveWindow() to be compatible with windows created in a different thread or parent.
//  2019-01-17: Inputs: Added support for mouse buttons 4 and 5 via WM_XBUTTON* messages.
//  2019-01-15: Inputs: Added support for XInput gamepads (if ImGuiConfigFlags_NavEnableGamepad is set by user application).
//  2018-11-30: Misc: Setting up io.BackendPlatformName so it can be displayed in the About Window.
//  2018-06-29: Inputs: Added support for the ImGuiMouseCursor_Hand cursor.
//  2018-06-10: Inputs: Fixed handling of mouse wheel messages to support fine position messages (typically sent by track-pads).
//  2018-06-08: Misc: Extracted imgui_impl_win32.cpp/.h away from the old combined DX9/DX10/DX11/DX12 examples.
//  2018-03-20: Misc: Setup io.BackendFlags ImGuiBackendFlags_HasMouseCursors and ImGuiBackendFlags_HasSetMousePos flags + honor ImGuiConfigFlags_NoMouseCursorChange flag.
//  2018-02-20: Inputs: Added support for mouse cursors (ImGui::GetMouseCursor() value and WM_SETCURSOR message handling).
//  2018-02-06: Inputs: Added mapping for ImGuiKey_Space.
//  2018-02-06: Inputs: Honoring the io.WantSetMousePos by repositioning the mouse (when using navigation and ImGuiConfigFlags_NavMoveMouse is set).
//  2018-02-06: Misc: Removed call to ImGui::Shutdown() which is not available from 1.60 WIP, user needs to call CreateContext/DestroyContext themselves.
//  2018-01-20: Inputs: Added Horizontal Mouse Wheel support.
//  2018-01-08: Inputs: Added mapping for ImGuiKey_Insert.
//  2018-01-05: Inputs: Added WM_LBUTTONDBLCLK double-click handlers for window classes with the CS_DBLCLKS flag.
//  2017-10-23: Inputs: Added WM_SYSKEYDOWN / WM_SYSKEYUP handlers so e.g. the VK_MENU key can be read.
//  2017-10-23: Inputs: Using Win32 ::SetCapture/::GetCapture() to retrieve mouse positions outside the client area when dragging.
//  2016-11-12: Inputs: Only call Win32 ::SetCursor(NULL) when io.MouseDrawCursor is set.

ImGui_ImplWin32_Data :: struct{
    hWnd : win32.Hwnd,
    MouseHwnd : win32.Hwnd,
    MouseTracked : bool,
    Time : win.LARGE_INTEGER,
    TicksPerSecond : win.LARGE_INTEGER,
    LastMouseCursor : imgui.Mouse_Cursor,// ImGuiMouseCursor,
    HasGamepad : bool,
    WantUpdateHasGamepad : bool,

//#ifndef IMGUI_IMPL_WIN32_DISABLE_GAMEPAD
//    HMODULE                     XInputDLL;
//    PFN_XInputGetCapabilities   XInputGetCapabilities;
//    PFN_XInputGetState          XInputGetState;
//#endif
//
    //ImGui_ImplWin32_Data()      { memset(this, 0, sizeof(*this)); }
}


// Backend data stored in io.BackendPlatformUserData to allow support for multiple Dear ImGui contexts
// It is STRONGLY preferred that you use docking branch with multi-viewports (== single Dear ImGui context + multiple windows) instead of multiple Dear ImGui contexts.
// FIXME: multi-context support is not well tested and probably dysfunctional in this backend.
// FIXME: some shared resources (mouse cursor shape, gamepad) are mishandled when using multi-context.
ImGui_ImplWin32_GetBackendData :: proc()-> ^ImGui_ImplWin32_Data{
    //fmt.println("Get Backend Data called");
    result : ^ImGui_ImplWin32_Data;
    cur_context := imgui.get_current_context;
    //fmt.println(cur_context);
   //fmt.println(cur_context == nil);
    if cur_context != nil{

        result = cast(^ImGui_ImplWin32_Data)imgui.get_io().backend_platform_user_data;
        //fmt.println("TEST OUTPUT");
    }else{
        //fmt.println("cur_context is nil?");
        result = nil;
    }

    //return imgui.get_current_context() == nil ? cast(^ImGui_ImplWin32_Data)imgui.get_io().backend_platform_user_data : nil;//(ImGui_ImplWin32_Data*)ImGui::GetIO().BackendPlatformUserData : NULL;
    //return ImGui::GetCurrentContext() ? (ImGui_ImplWin32_Data*)ImGui::GetIO().BackendPlatformUserData : NULL;
    return result;
}


// Functions
ImGui_ImplWin32_Init :: proc(hwnd : win32.Hwnd) -> bool{
    io : ^imgui.IO = imgui.get_io();//ImGui::GetIO();
//    IM_ASSERT(io.BackendPlatformUserData == NULL && "Already initialized a platform backend!");

    perf_frequency : win.LARGE_INTEGER;//i64;
    perf_counter : win.LARGE_INTEGER;//i64;
    //qpc_frequency: win32.LARGE_INTEGER;

    if !win.QueryPerformanceFrequency(&perf_frequency){
        return false;
    }
    if (!win.QueryPerformanceCounter(&perf_counter)){
        return false;
    }
    using imgui;
    // Setup backend capabilities flags
    //ImGui_ImplWin32_Data* bd = IM_NEW(ImGui_ImplWin32_Data)();
    bd := new(ImGui_ImplWin32_Data);
//    io.BackendPlatformUserData = (void*)bd;
    io.backend_platform_user_data = bd;

    io.backend_platform_name = "imgui_impl_win32";
    io.backend_flags |= Backend_Flags.HasMouseCursors;// ImGuiBackendFlags_HasMouseCursors;         // We can honor GetMouseCursor() values (optional)
    io.backend_flags |= Backend_Flags.HasSetMousePos;// ImGuiBackendFlags_HasSetMousePos;          // We can honor io.WantSetMousePos requests (optional, rarely used)

    bd.hWnd = hwnd;
    bd.WantUpdateHasGamepad = true;
    bd.TicksPerSecond = perf_frequency;
    g_TicksPerSecond = perf_frequency;
    bd.Time = perf_counter;
    bd.LastMouseCursor = Mouse_Cursor.Count;// ImGuiMouseCursor_COUNT;

    io.ime_window_handle = hwnd;

    // Keyboard mapping. Dear ImGui will use those indices to peek into the io.KeysDown[] array that we will update during the application lifetime.
    io.key_map[imgui.Key.Tab] = win32.VK_TAB;
    io.key_map[Key.LeftArrow] = win32.VK_LEFT;
    io.key_map[Key.RightArrow] = win32.VK_RIGHT;
    io.key_map[Key.UpArrow] = win32.VK_UP;
    io.key_map[Key.DownArrow] = win32.VK_DOWN;
    io.key_map[Key.PageUp] = win32.VK_PRIOR;
    io.key_map[Key.PageDown] = win32.VK_NEXT;
    io.key_map[Key.Home] = win32.VK_HOME;
    io.key_map[Key.End] = win32.VK_END;
    io.key_map[Key.Insert] = win32.VK_INSERT;
    io.key_map[Key.Delete] = win32.VK_DELETE;
    io.key_map[Key.Backspace] = win32.VK_BACK;
    io.key_map[Key.Space] = win32.VK_SPACE;
    io.key_map[Key.Enter] = win32.VK_RETURN;
    io.key_map[Key.Escape] = win32.VK_ESCAPE;
    io.key_map[Key.KeyPadEnter] = win32.VK_RETURN;
    io.key_map[Key.A] = 'A';
    io.key_map[Key.C] = 'C';
    io.key_map[Key.V] = 'V';
    io.key_map[Key.X] = 'X';
    io.key_map[Key.Y] = 'Y';
    io.key_map[Key.Z] = 'Z';
/*
    // Dynamically load XInput library
#ifndef IMGUI_IMPL_WIN32_DISABLE_GAMEPAD
    const char* xinput_dll_names[] = {
        "xinput1_4.dll",   // Windows 8+
        "xinput1_3.dll",   // DirectX SDK
        "xinput9_1_0.dll", // Windows Vista, Windows 7
        "xinput1_2.dll",   // DirectX SDK
        "xinput1_1.dll"    // DirectX SDK
    };
    for (int n = 0; n < IM_ARRAYSIZE(xinput_dll_names); n++)
        if (HMODULE dll = ::LoadLibraryA(xinput_dll_names[n]))
        {
            bd->XInputDLL = dll;
            bd->XInputGetCapabilities = (PFN_XInputGetCapabilities)::GetProcAddress(dll, "XInputGetCapabilities");
            bd->XInputGetState = (PFN_XInputGetState)::GetProcAddress(dll, "XInputGetState");
            break;
        }
#endif // IMGUI_IMPL_WIN32_DISABLE_GAMEPAD
*/
    return true;
}

/*
void    ImGui_ImplWin32_Shutdown(){
    ImGuiIO& io = ImGui::GetIO();
    ImGui_ImplWin32_Data* bd = ImGui_ImplWin32_GetBackendData();

    // Unload XInput library
#ifndef IMGUI_IMPL_WIN32_DISABLE_GAMEPAD
    if (bd->XInputDLL)
        ::FreeLibrary(bd->XInputDLL);
#endif // IMGUI_IMPL_WIN32_DISABLE_GAMEPAD

    io.BackendPlatformName = NULL;
    io.BackendPlatformUserData = NULL;
    IM_DELETE(bd);
}
*/

ImGui_ImplWin32_UpdateMouseCursor :: proc() -> bool{
    //ImGuiIO& io = ImGui::GetIO();
    io := imgui.get_io();
    if cast(bool)(io.config_flags & imgui.Config_Flags.NoMouseCursorChange){
        return false;
    }

    //ImGuiMouseCursor imgui_cursor = ImGui::GetMouseCursor();
    imgui_cursor :=  imgui.get_mouse_cursor();
    if  imgui_cursor == imgui.Mouse_Cursor.None || io.mouse_draw_cursor{
        // Hide OS mouse cursor if imgui is drawing it or if it wants no cursor
        win32.set_cursor(nil);
    }
    else{
        // Show OS mouse cursor
        //LPTSTR win32_cursor = IDC_ARROW;
        win32_cursor : cstring = win32.IDC_ARROW;
        #partial switch imgui_cursor { 
            case imgui.Mouse_Cursor.Arrow:        win32_cursor = win32.IDC_ARROW; break;
            case imgui.Mouse_Cursor.TextInput:    win32_cursor = win32.IDC_IBEAM; break;
            case imgui.Mouse_Cursor.ResizeAll:    win32_cursor = win32.IDC_SIZEALL; break;
            case imgui.Mouse_Cursor.ResizeEw:     win32_cursor = win32.IDC_SIZEWE; break;
            case imgui.Mouse_Cursor.ResizeNs:     win32_cursor = win32.IDC_SIZENS; break;
            case imgui.Mouse_Cursor.ResizeNesw:   win32_cursor = win32.IDC_SIZENESW; break;
            case imgui.Mouse_Cursor.ResizeNwse:   win32_cursor = win32.IDC_SIZENWSE; break;
            case imgui.Mouse_Cursor.Hand:         win32_cursor = win32.IDC_HAND; break;
            case imgui.Mouse_Cursor.NotAllowed:   win32_cursor = win32.IDC_NO; break;
        }
        win32.set_cursor(win32.load_cursor_a(nil, win32_cursor));
    }
    return true;
}

ImGui_ImplWin32_UpdateMousePos :: proc(){
    bd := ImGui_ImplWin32_GetBackendData();

    //ImGuiIO& io = ImGui::GetIO();
    io := imgui.get_io();
   // IM_ASSERT(bd->hWnd != 0);

    mouse_pos_prev := io.mouse_pos;//.MousePos;
    //io.mouse_pos = imgui.Vec2{-max(f32), -max(f32)};

    // Obtain focused and hovered window. We forward mouse input when focused or when hovered (and no other window is capturing)
    focused_window : win32.Hwnd = platform.GetForegroundWindow();
    hovered_window := bd.MouseHwnd;
    mouse_window : win32.Hwnd = nil;
    if hovered_window != nil && (hovered_window == bd.hWnd || platform.IsChild(hovered_window, bd.hWnd)){
        mouse_window = hovered_window;
    }
    else if focused_window != nil && (focused_window == bd.hWnd || platform.IsChild(focused_window, bd.hWnd)){
        mouse_window = focused_window;
    }
    if mouse_window == nil{
        return;
    }
    // Set OS mouse position from Dear ImGui if requested (rarely used, only when ImGuiConfigFlags_NavEnableSetMousePos is enabled by user)
    if io.want_set_mouse_pos{
        pos : win32.Point = { cast(i32)mouse_pos_prev.x, cast(i32)mouse_pos_prev.y };
        if win32.client_to_screen(bd.hWnd, &pos){
            win32.set_cursor_pos(pos.x, pos.y);
        }
    }

    // Set Dear ImGui mouse position from OS position
    pos : win32.Point;
    if (win32.get_cursor_pos(&pos) && win32.screen_to_client(mouse_window, &pos)){
     // io.mouse_pos = imgui.Vec2{cast(f32)pos.x, cast(f32)pos.y};
    }
}

// Gamepad navigation mapping
ImGui_ImplWin32_UpdateGamepads :: proc(){
/*
#ifndef IMGUI_IMPL_WIN32_DISABLE_GAMEPAD
    ImGuiIO& io = ImGui::GetIO();
    ImGui_ImplWin32_Data* bd = ImGui_ImplWin32_GetBackendData();
    memset(io.NavInputs, 0, sizeof(io.NavInputs));
    if ((io.ConfigFlags & ImGuiConfigFlags_NavEnableGamepad) == 0)
        return;

    // Calling XInputGetState() every frame on disconnected gamepads is unfortunately too slow.
    // Instead we refresh gamepad availability by calling XInputGetCapabilities() _only_ after receiving WM_DEVICECHANGE.
    if (bd->WantUpdateHasGamepad)
    {
        XINPUT_CAPABILITIES caps;
        bd->HasGamepad = bd->XInputGetCapabilities ? (bd->XInputGetCapabilities(0, XINPUT_FLAG_GAMEPAD, &caps) == ERROR_SUCCESS) : false;
        bd->WantUpdateHasGamepad = false;
    }

    io.BackendFlags &= ~ImGuiBackendFlags_HasGamepad;
    XINPUT_STATE xinput_state;
    if (bd->HasGamepad && bd->XInputGetState && bd->XInputGetState(0, &xinput_state) == ERROR_SUCCESS)
    {
        const XINPUT_GAMEPAD& gamepad = xinput_state.Gamepad;
        io.BackendFlags |= ImGuiBackendFlags_HasGamepad;

        #define MAP_BUTTON(NAV_NO, BUTTON_ENUM)     { io.NavInputs[NAV_NO] = (gamepad.wButtons & BUTTON_ENUM) ? 1.0f : 0.0f; }
        #define MAP_ANALOG(NAV_NO, VALUE, V0, V1)   { float vn = (float)(VALUE - V0) / (float)(V1 - V0); if (vn > 1.0f) vn = 1.0f; if (vn > 0.0f && io.NavInputs[NAV_NO] < vn) io.NavInputs[NAV_NO] = vn; }
        MAP_BUTTON(ImGuiNavInput_Activate,      XINPUT_GAMEPAD_A);              // Cross / A
        MAP_BUTTON(ImGuiNavInput_Cancel,        XINPUT_GAMEPAD_B);              // Circle / B
        MAP_BUTTON(ImGuiNavInput_Menu,          XINPUT_GAMEPAD_X);              // Square / X
        MAP_BUTTON(ImGuiNavInput_Input,         XINPUT_GAMEPAD_Y);              // Triangle / Y
        MAP_BUTTON(ImGuiNavInput_DpadLeft,      XINPUT_GAMEPAD_DPAD_LEFT);      // D-Pad Left
        MAP_BUTTON(ImGuiNavInput_DpadRight,     XINPUT_GAMEPAD_DPAD_RIGHT);     // D-Pad Right
        MAP_BUTTON(ImGuiNavInput_DpadUp,        XINPUT_GAMEPAD_DPAD_UP);        // D-Pad Up
        MAP_BUTTON(ImGuiNavInput_DpadDown,      XINPUT_GAMEPAD_DPAD_DOWN);      // D-Pad Down
        MAP_BUTTON(ImGuiNavInput_FocusPrev,     XINPUT_GAMEPAD_LEFT_SHOULDER);  // L1 / LB
        MAP_BUTTON(ImGuiNavInput_FocusNext,     XINPUT_GAMEPAD_RIGHT_SHOULDER); // R1 / RB
        MAP_BUTTON(ImGuiNavInput_TweakSlow,     XINPUT_GAMEPAD_LEFT_SHOULDER);  // L1 / LB
        MAP_BUTTON(ImGuiNavInput_TweakFast,     XINPUT_GAMEPAD_RIGHT_SHOULDER); // R1 / RB
        MAP_ANALOG(ImGuiNavInput_LStickLeft,    gamepad.sThumbLX,  -XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE, -32768);
        MAP_ANALOG(ImGuiNavInput_LStickRight,   gamepad.sThumbLX,  +XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE, +32767);
        MAP_ANALOG(ImGuiNavInput_LStickUp,      gamepad.sThumbLY,  +XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE, +32767);
        MAP_ANALOG(ImGuiNavInput_LStickDown,    gamepad.sThumbLY,  -XINPUT_GAMEPAD_LEFT_THUMB_DEADZONE, -32767);
        #undef MAP_BUTTON
        #undef MAP_ANALOG
    }
#endif // #ifndef IMGUI_IMPL_WIN32_DISABLE_GAMEPAD
*/
}

g_time : win.LARGE_INTEGER= 0;
g_TicksPerSecond : win.LARGE_INTEGER = 0;
g_LastMouseCursor : imgui.Mouse_Cursor = imgui.Mouse_Cursor.Count;// ImGuiMouseCursor_Count_;


ImGui_ImplWin32_NewFrame :: proc(){
    fmt.println("Start New Frame");
    // /ImGuiIO& io = ImGui::GetIO();
    io := imgui.get_io();
    bd :=  ImGui_ImplWin32_GetBackendData();
    //IM_ASSERT(bd != NULL && "Did you call ImGui_ImplWin32_Init()?");

    // Setup display size (every frame to accommodate for window resizing)
    rect : win32.Rect = { 0, 0, 0, 0 };
    win32.get_client_rect(bd.hWnd, &rect);
    io.display_size = imgui.Vec2{cast(f32)(rect.right - rect.left), cast(f32)(rect.bottom - rect.top)};

    // Setup time step
    current_time : win.LARGE_INTEGER = 0;
    win.QueryPerformanceCounter(&current_time);
    io.delta_time = cast(f32)(current_time - g_time) / cast(f32)g_TicksPerSecond;
    g_time = current_time;

    // Update OS mouse position
    ImGui_ImplWin32_UpdateMousePos();

    // Update OS mouse cursor with the cursor requested by imgui
    //ImGuiMouseCursor mouse_cursor = io.MouseDrawCursor ? ImGuiMouseCursor_None : ImGui::GetMouseCursor();
    mouse_cursor := io.mouse_draw_cursor ?  imgui.Mouse_Cursor.None : imgui.get_mouse_cursor();
    if g_LastMouseCursor != mouse_cursor{
        g_LastMouseCursor = mouse_cursor;
        ImGui_ImplWin32_UpdateMouseCursor();
    }

    // Update game controllers (if enabled and available)
    //ImGui_ImplWin32_UpdateGamepads();
}

// Allow compilation with old Windows SDK. MinGW doesn't have default _WIN32_WINNT/WINVER versions.
//#ifndef WM_MOUSEHWHEEL
//#define WM_MOUSEHWHEEL 0x020E
//#endif
//#ifndef DBT_DEVNODES_CHANGED
//#define DBT_DEVNODES_CHANGED 0x0007
//#endif

// Win32 message handler (process Win32 mouse/keyboard inputs, etc.)
// Call from your application's message handler.
// When implementing your own backend, you can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if Dear ImGui wants to use your inputs.
// - When io.WantCaptureMouse is true, do not dispatch mouse input data to your main application.
// - When io.WantCaptureKeyboard is true, do not dispatch keyboard input data to your main application.
// Generally you may always pass all inputs to Dear ImGui, and hide them from your application based on those two flags.
// PS: In this Win32 handler, we use the capture API (GetCapture/SetCapture/ReleaseCapture) to be able to read mouse coordinates when dragging mouse outside of our window bounds.
// PS: We treat DBLCLK messages as regular mouse down messages, so this code will work on windows classes that have the CS_DBLCLKS flag set. Our own example app code doesn't set this flag.
//#if 0
// Copy this line into your .cpp file to forward declare the function.
//extern IMGUI_IMPL_API LRESULT ImGui_ImplWin32_WndProcHandler(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam);
//#endif
ImGui_ImplWin32_WndProcHandler :: proc(hwnd : win32.Hwnd, msg : c.uint, wParam : win32.Wparam, lParam : win32.Lparam ) -> win32.Lresult {
    //if (ImGui::GetCurrentContext() == NULL)
    if imgui.get_current_context() == nil{
        return 0;
    }

    io := imgui.get_io();
    bd := ImGui_ImplWin32_GetBackendData();
    switch (msg)
    {
        case win32.WM_MOUSEMOVE:{
            // We need to call TrackMouseEvent in order to receive WM_MOUSELEAVE events
            bd.MouseHwnd = hwnd;
            if !bd.MouseTracked{
                tme : TRACKMOUSEEVENT = { size_of(TRACKMOUSEEVENT), TME_LEAVE, hwnd, 0 };
                //platform.TrackMouseEvent(&tme);
                bd.MouseTracked = true;
            }
            break;
        }
        case WM_MOUSELEAVE:{
            if bd.MouseHwnd == hwnd{
                bd.MouseHwnd = nil;
            }
            bd.MouseTracked = false;
            break;
        }
        case win32.WM_LBUTTONDOWN: case win32.WM_LBUTTONDBLCLK:{}
        case win32.WM_RBUTTONDOWN: case win32.WM_RBUTTONDBLCLK:{}
        case win32.WM_MBUTTONDOWN: case win32.WM_MBUTTONDBLCLK:{
        //case win32.WM_XBUTTONDOWN: case win32.WM_XBUTTONDBLCLK:{
        
            button : int = 0;
            if (msg == win32.WM_LBUTTONDOWN || msg == win32.WM_LBUTTONDBLCLK) { button = 0; }
            if (msg == win32.WM_RBUTTONDOWN || msg == win32.WM_RBUTTONDBLCLK) { button = 1; }
            if (msg == win32.WM_MBUTTONDOWN || msg == win32.WM_MBUTTONDBLCLK) { button = 2; }
            //if (msg == win32.WM_XBUTTONDOWN || msg == WM_XBUTTONDBLCLK) { button = (GET_XBUTTON_WPARAM(wParam) == XBUTTON1) ? 3 : 4; }
            //if (!ImGui::IsAnyMouseDown() && ::GetCapture() == NULL)
            //    ::SetCapture(hwnd);
            //io.mouse_down[button] = true;
            return 0;
        }
        
        case win32.WM_LBUTTONUP:{}
        case win32.WM_RBUTTONUP:{}
        case win32.WM_MBUTTONUP:{
        //case win32.WM_XBUTTONUP:{

            button : int = 0;
            if (msg == win32.WM_LBUTTONUP) { button = 0; }
            if (msg == win32.WM_RBUTTONUP) { button = 1; }
            if (msg == win32.WM_MBUTTONUP) { button = 2; }
            //if (msg == win32.WM_XBUTTONUP) { button = (GET_XBUTTON_WPARAM(wParam) == XBUTTON1) ? 3 : 4; }
            //io.MouseDown[button] = false;

            io.mouse_down[button] = false;
            //if (!ImGui::IsAnyMouseDown() && ::GetCapture() == hwnd)
            //    ::ReleaseCapture();
            return 0;
        }
        
        case win32.WM_MOUSEWHEEL:{
            io.mouse_wheel += f32(i16(GET_WHEEL_DELTA_WPARAM(wParam))) / f32(WHEEL_DELTA)
            return 0;
        }

        ///case win32.WM_MOUSEHWHEEL:{
            //io.mouse_wheel_h += (float)GET_WHEEL_DELTA_WPARAM(wParam) / (float)WHEEL_DELTA;
           // return 0;
        //}  
        case win32.WM_KEYDOWN:{}
        case win32.WM_KEYUP:{}
        case win32.WM_SYSKEYDOWN:{}
        case win32.WM_SYSKEYUP:{
            down : bool = (msg == win32.WM_KEYDOWN || msg == win32.WM_SYSKEYDOWN);
            if wParam < 256{
                io.keys_down[wParam] = down;
            }
            if wParam == win32.VK_CONTROL{
                io.key_ctrl = down;
            }
            if wParam == win32.VK_SHIFT{
                io.key_shift = down;
            }
            if wParam == win32.VK_MENU{
                io.key_alt = down;
            }
            return 0;
        }
        case win32.WM_SETFOCUS:{}
        case win32.WM_KILLFOCUS:{
            //io.AddFocusEvent(msg == WM_SETFOCUS);
            //fmt.println("TODO Fix WM_KILLFOCUS to work with this version of imgui. or upgrade imgui on kill focus.")
            return 0;
        }
        case win32.WM_CHAR:{
            // You can also use ToAscii()+GetKeyboardState() to retrieve characters.
            if wParam > 0 && wParam < 0x10000{
                imgui.io_add_input_character_utf16(io,cast(imgui.Wchar16)wParam);
            //io.AddInputCharacterUTF16((unsigned short)wParam);
            }
            return 0;
        }
        case win32.WM_SETCURSOR:{
            if win32.LOWORD_L(lParam) == HTCLIENT && ImGui_ImplWin32_UpdateMouseCursor(){
                return 1;
            }
            return 0;
        }
        case WM_DEVICECHANGE:{
            if cast(c.uint)wParam == DBT_DEVNODES_CHANGED{
                bd.WantUpdateHasGamepad = true;
            }
            return 0;
        }
    }
    return 0;
}
