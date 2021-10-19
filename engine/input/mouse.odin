package input
DigitalButton :: struct{
    down : bool,
    pressed : bool,
    released : bool,
}

Mouse :: struct{
    p : f2,
    prev_p : f2,
    delta_p : f2,
    uv : f2,
    prev_uv : f2,
    delta_uv : f2,

    lmb : DigitalButton,//left_mouse_button
	rmb : DigitalButton,
	wrap_mode : bool, 
}

/*
UpdateDigitalButton :: proc(button : ^DigitalButton,state : u32)
{
    was_down := button.down;
    down := state >> 7;
    button.pressed = !was_down && down;
    button.released = was_down && !down;
    button.down = down;    
}

PullMouseState :: proc(ps : ^PlatformState){
    input := &ps.input;
    if(input)
    {
         MouseP  : POINT;
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
*/