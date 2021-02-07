package platform

import platform "../platform"

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
