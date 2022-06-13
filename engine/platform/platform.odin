package platform

import platform "../platform"
import win "core:sys/windows"


ps : PlatformState;

PlatformState :: struct
{
    time : platform.Time,
    input : platform.Input,
//    Renderer renderer,
//    Audio audio,
    is_running : bool,    

    //TODO(Ray):what will we do on other platforms not for sure yet.
    window : platform.Window,
//    Memory memory,
    //    info : windows.SYSTEM_INFO,
};

/*
win_set_screen_mode :: proc(is_full_screen : bool){
	window := ps.window.handle
	style := win.GetWindowLongW(window,win.GWL_STYLE)
	ps.window.is_full_screen_mode = is_full_screen
	ps.window.global_window_p.length = size_of(platform.WINDOWPLACEMENT)
	if ps.window.is_full_screen_mode{
		mi : win.MONITORINFO
		if platform.GetWindowPlacement(window,&ps.window.global_window_p) && 
			platform.GetMonitorInfo(platform.MonitorFromWindow(window,MONITOR_DEFAULT
	}

}
*/
