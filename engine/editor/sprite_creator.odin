package editor
import imgui "../external/odin-imgui"
import platform	"../platform"
import gfx "../graphics"
import eng_m "../math"
import la "core:math/linalg"
import math "core:math"
import con "../containers"
import libc "core:c/libc"
import fmt "core:fmt"

Zoxel :: struct{
	id : u64,
	ref : u64,
	color : u32,//for now 32 bit color could be other bit size
}

Layer :: struct{
	name : string,
	grid : [dynamic]Zoxel,
	size : eng_m.f2,
}

grid_step : f32 = 17.0

layers : con.Buffer(Layer)
current_layer : Layer

init_sprite_creator :: proc(){
	layers = con.buf_init(0,Layer)
	default_layer : Layer
	default_layer.name = "default"
	default_layer.size = eng_m.f2{64,64}
	layer_id := add_layer(default_layer)
	current_layer = get_layer(layer_id)

}

get_layer :: proc(layer_id : int) -> Layer{
	layer := con.buf_get(&layers,u64(layer_id))
	return layer
}

add_layer :: proc(layer_desc : Layer)  -> (layer_id : int){
	new_layer : Layer = layer_desc
	new_layer.grid = make([dynamic]Zoxel,int(layer_desc.size.x * layer_desc.size.y),int(layer_desc.size.x * layer_desc.size.y))
	return int(con.buf_push(&layers,new_layer))
}

remove_layer :: proc(layer_id : int){

}

show_sprite_createor :: proc(){
	using imgui
	using con
	using eng_m
	using fmt
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
	mouse_pos_in_canvas.x = mouse_pos_in_canvas.x - origin.x
	mouse_pos_in_canvas.y = mouse_pos_in_canvas.y - origin.y
	//Working on getting the mouse grid
	mouse_grid_p : Vec2
	mouse_grid_p.x = mouse_pos_in_canvas.x / grid_step
	mouse_grid_p.y = mouse_pos_in_canvas.y / grid_step

	grid_offset : Vec2 = {mouse_grid_p.x,mouse_grid_p.y}
	sel_origin : Vec2
	sel_origin.x = origin.x + f32(int(grid_offset.x) * int(grid_step))
	sel_origin.y = origin.y + f32(int(grid_offset.y) * int(grid_step))
	selected_p := sel_origin 
	//selected_p.x = selected_p.x - (grid_offset * grid_step)
	//selected_p.y = selected_p.y - (grid_offset * grid_step)

	selectd_size := Vec2{sel_origin.x + grid_step,sel_origin.y + grid_step}
	
	draw_list_add_rect_filled(draw_list,selected_p,selectd_size,color_convert_float4to_u32(Vec4{1,0,1,1}))

//	selected_p.x = mouse_pos_in_canvas.x
//	selected_p.y = mouse_pos_in_canvas.y
	
//	selectd_size = Vec2{selected_p.x + grid_step,selected_p.y + grid_step}
	
//	draw_list_add_rect_filled(draw_list,selected_p,selectd_size,color_convert_float4to_u32(Vec4{0,1,1,1}))
	
	//prepare color circle
	//create and show grid lines
	//fill pixel in grid with current color
	if is_any_mouse_down(){
		//grid_step += 0.11
		size_x := int(clamp(grid_offset.x,0,current_layer.size.x))
		fmt.printf("%f\n",size_x)
		size_y := int(clamp(grid_offset.y,0,current_layer.size.y))
		
		fmt.printf("%f\n",size_y)
		mul_sizes := int(current_layer.size.x) * size_y
		fmt.printf("%f\n",mul_sizes)
		painting_idx := int( size_x + mul_sizes)
		current_layer.grid[painting_idx].color = 0xFFFFFFFF
		for i in 0..64{
			current_layer.grid[i].color = 0xFFFFFFFF
		}
	}
	stride := current_layer.size.x
	x : int
	y : int
	idx : int
	test_red : f32
	for zoxel,i in current_layer.grid{
		//grid_offset : Vec2 = {f32(x),f32(y)}//{mouse_grid_p.x,mouse_grid_p.y}
		sel_origin : Vec2
		sel_origin.x = origin.x + f32(x * int(grid_step))
		sel_origin.y = origin.y + f32(y * int(grid_step))
		selected_p := sel_origin 

		selectd_size := Vec2{sel_origin.x + grid_step,sel_origin.y + grid_step}
		pix_col : Vec4
		color_convert_u32to_float4(&pix_col,zoxel.color/*Vec4{test_red,0,1,1}*/)
		draw_list_add_rect_filled(draw_list,selected_p,selectd_size,zoxel.color)
		if x == int(stride - 1){
			y = (y + 1) % int(stride)
		}
		x = (x + 1) % int(stride)
		test_red += 0.0007
	}
	
	start : Vec2 = origin
	total_size_of_graph_x := grid_step * current_layer.size.x + start.x
	total_size_of_graph_y := grid_step * current_layer.size.y + start.y

	draw_line_distance_x := grid_step * current_layer.size.x
	draw_line_distance_y := grid_step * current_layer.size.y
	
	//for x := libc.fmodf(scrolling.x, grid_step); x < canvas_size.x; x += grid_step{
	for x := start.x; x < total_size_of_graph_x; x += grid_step{
		//draw_list_add_line(draw_list,Vec2{canvas_p0.x + x, canvas_p0.y}, Vec2{canvas_p0.x + x, canvas_p1.y}, color_convert_float4to_u32(Vec4{200, 200, 200, 40}))
		draw_list_add_line(draw_list,Vec2{x, origin.y}, Vec2{x, origin.y + draw_line_distance_x}, color_convert_float4to_u32(Vec4{200, 200, 200, 40}))
	}
	//for y := libc.fmodf(scrolling.y, grid_step); y < canvas_size.y; y += grid_step{
	for y := start.y; y < total_size_of_graph_y; y += grid_step{
		draw_list_add_line(draw_list,Vec2{origin.x, y}, Vec2{origin.x + draw_line_distance_y, y}, color_convert_float4to_u32(Vec4{200, 200, 200, 40}))
	//	draw_list_add_line(draw_list,Vec2{canvas_p0.x, canvas_p0.y + y}, Vec2{canvas_p1.x, canvas_p0.y + y}, color_convert_float4to_u32(Vec4{200, 200, 200, 40}))
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