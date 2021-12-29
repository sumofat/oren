package editor
import imgui "../external/odin-imgui"
import platform	"../platform"
import gfx "../graphics"
import eng_m "../math"
import la "core:math/linalg"
import math "core:math"
import con "../containers"
import libc "core:c/libc"

Zoxel :: struct{
	id : u64,
	ref : u64,
}

Layer :: struct{
	name : string,
	grid : [dynamic]Zoxel,
}
grid_step : f32 = 17.0

layers : con.Buffer(Layer)

init_sprite_creator :: proc(){
	layers = con.buf_init(0,Layer)
	default_layer : Layer
	default_layer.name = "default"
	add_layer(default_layer)
}

get_layer :: proc(layer_id : int) -> Layer{
	layer := con.buf_get(&layers,u64(layer_id))
	return layer
}

add_layer :: proc(layer_desc : Layer)  -> (layer_id : int){
	new_layer : Layer = layer_desc
	new_layer.grid = make([dynamic]Zoxel)
	return int(con.buf_push(&layers,new_layer))
}

remove_layer :: proc(layer_id : int){

}

show_sprite_createor :: proc(){
	using imgui
	using con
	@static scrolling : Vec2

	if !begin("Sprite Creator"){
		end()
		return
	}
	//prepare drawing surface
	canvas_p0 : Vec2
	get_cursor_screen_pos(&canvas_p0)
	canvas_size : Vec2
	get_content_region_avail(&canvas_size)
	canvas_p1 := Vec2{canvas_p0.x + canvas_size.x,canvas_p0.y + canvas_size.y}

	io := imgui.get_io()
	draw_list := imgui.get_window_draw_list()
	draw_list_add_rect_filled(draw_list,canvas_p0,canvas_p1,color_convert_float4to_u32(Vec4{0.25,0.25,0.25,1}))
	draw_list_add_rect(draw_list,canvas_p0,canvas_p1,color_convert_float4to_u32(Vec4{1,1,1,1}))
	invisible_button("canvas",canvas_size,imgui.Button_Flags.MouseButtonLeft | imgui.Button_Flags.MouseButtonRight)
	zoxel_size := grid_step

	origin : Vec2 = {canvas_p0.x + scrolling.x, canvas_p0.y + scrolling.y}
	mouse_pos_in_canvas : Vec2
	get_mouse_pos(&mouse_pos_in_canvas)

	//Working on getting the mouse grid
	mouse_grid_p : Vec2
	mouse_grid_p.x = origin.x + (mouse_pos_in_canvas.x / grid_step)
	mouse_grid_p.y = origin.y + (mouse_pos_in_canvas.y / grid_step)

	grid_offset : Vec2 = {mouse_grid_p.x,mouse_grid_p.y}
	origin.x = origin.x + (grid_offset.x * grid_step)
	origin.y = origin.y + (grid_offset.y * grid_step)
	selected_p := origin 
	//selected_p.x = selected_p.x - (grid_offset * grid_step)
	//selected_p.y = selected_p.y - (grid_offset * grid_step)

	selectd_size := Vec2{origin.x + grid_step,origin.y + grid_step}
	
	draw_list_add_rect_filled(draw_list,selected_p,selectd_size,color_convert_float4to_u32(Vec4{1,0,1,1}))

	selected_p.x = mouse_pos_in_canvas.x
	selected_p.y = mouse_pos_in_canvas.y
	
	selectd_size = Vec2{selected_p.x + grid_step,selected_p.y + grid_step}
	
	draw_list_add_rect_filled(draw_list,selected_p,selectd_size,color_convert_float4to_u32(Vec4{0,1,1,1}))
	
	//prepare color circle
	//create and show grid lines
	if is_any_mouse_down(){
		//grid_step += 0.11
	}
	for x := libc.fmodf(scrolling.x, grid_step); x < canvas_size.x; x += grid_step{
		draw_list_add_line(draw_list,Vec2{canvas_p0.x + x, canvas_p0.y}, Vec2{canvas_p0.x + x, canvas_p1.y}, color_convert_float4to_u32(Vec4{200, 200, 200, 40}))
	}
	for y := libc.fmodf(scrolling.y, grid_step); y < canvas_size.y; y += grid_step{
		draw_list_add_line(draw_list,Vec2{canvas_p0.x, canvas_p0.y + y}, Vec2{canvas_p1.x, canvas_p0.y + y}, color_convert_float4to_u32(Vec4{200, 200, 200, 40}))
	}
	//mouse_threshold_for_pan : f32 = opt_enable_context_menu ? -1.0f : 0.0f;
	//EDITOR : Pick color and fill in squares as one zoxel
 	if imgui.is_mouse_dragging(imgui.Mouse_Button.Left){
        scrolling.x += io.mouse_delta.x
        scrolling.y += io.mouse_delta.y
	}
	//show layers
	//show visual choices //visible / solo / (hide|show)
	//output button 
	/*writes to disk in a mega texture with referencing info for the engine
		outputs all layers on texture with animation data
	*/





	end()
}