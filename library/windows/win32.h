#include<windows.h>
#include <Xinput.h>
#include <dsound.h>
#include <mmdeviceapi.h>
#include <Audioclient.h>
#include <xinput.h>


#include "../fmj/src/fmj_types.h"


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
    WNDCLASS w_class;
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

PlatformState local_copy_ps = {0};
//declarations
//WINDOWS SETUP FUNCTIONS

void HandleWindowsMessages(PlatformState* ps);
f2 GetWin32WindowDim(PlatformState* ps);
void WINSetScreenMode(PlatformState* ps,bool is_full_screen);
void PullTimeState(PlatformState* ps);
void UpdateDigitalButton(DigitalButton* button,u32 state);
void PullMouseState(PlatformState* ps);
void PullDigitalButtons(PlatformState* ps);
void SetButton(DigitalButton* button,u32 button_type,XINPUT_STATE state);
void PullGamePads(PlatformState* ps);
//    int PlatformInit(PlatformState* ps,f2 window_dim,f2 window_p,int n_show_cmd);
void testPlatformInit(PlatformState* ps,f32 window_dim);
bool platformtest(PlatformState* ps,f2 window_dim,f2 window_p);
//end declare

