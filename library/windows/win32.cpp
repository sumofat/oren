#include "win32.h"
//WINDOWS SETUP FUNCTIONS
f2 GetWin32WindowDim(PlatformState* ps)
{
    RECT client_rect;
    GetClientRect(ps->window.handle, &client_rect);
	return f2_create(client_rect.right - client_rect.left, client_rect.bottom - client_rect.top);
}

void WINSetScreenMode(PlatformState* ps,bool is_full_screen)
{
    HWND Window = ps->window.handle;
    LONG Style = GetWindowLong(Window, GWL_STYLE);
    ps->window.is_full_screen_mode = is_full_screen;
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
            PAINTSTRUCT ps;
            HDC hDc = BeginPaint(Window, &ps);
//            FillRect(hDc, &ps.rcPaint, (HBRUSH) (COLOR_WINDOW + 1));
            EndPaint(Window, &ps);
            return 0;
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
            gm.ps.is_running = false;
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
        if(message.message == WM_QUIT)
        {
            ps->is_running = false;
        }
        TranslateMessage(&message);
        DispatchMessageA(&message);
    }
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
    GetSystemInfo(&ps->info.system_info);

    f2 dim = window_dim;
    f2 p = window_p;
    
    Window *window = &ps->window;
    
	window->dim = dim;
    window->p = p;
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
                window->p.x,
                window->p.y,
                window->dim.x,
                window->dim.y,
                0,
                0,
                h_instance,
                0);
        ErrorCode = GetLastError();
        if(created_window)
        {
            window->handle = created_window;
            WINSetScreenMode(ps,true);            
            ShowWindow(created_window, n_show_cmd);
        }
        else
        {
            //TODO(Ray):Could not attain window gracefully let the user know and shut down.
            //Could not start window.
            MessageBox(NULL, "Window Creation Failed!", "Error!",
                        MB_ICONEXCLAMATION | MB_OK);
             return 0;
        }
    }

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
    return 1;    
}
 
int platform_init(PlatformState* ps,f2 window_dim,f2 window_p,int n_show_cmd)
{
    return PlatformInit(ps,window_dim,window_p,n_show_cmd);
}

void test(f32 window_dim)
{
    window_dim += 2;
}

