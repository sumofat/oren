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
import strings "core:strings"

Zoxel :: struct{
	id : u64,
	ref : u64,
	color : u32,//for now 32 bit color could be other bit size
}

Layer :: struct{
	name : string,
	grid : [dynamic]Zoxel,
	size : eng_m.f2,
	is_show : bool,
	is_solo : bool,	
}

grid_step : f32 = 17.0

layers : con.Buffer(Layer)
current_layer : Layer

selected_color : u32
is_show_grid : bool = true
grid_color := imgui.Vec4{50, 500, 50, 40}

input_layer_name : string
//TODO(Ray):Allow for painting multiple texels at onece with a brush
	layers_names : con.Buffer(string)

init_sprite_creator :: proc(){
	layers = con.buf_init(0,Layer)
	default_layer : Layer
	default_layer.name = "default"
	default_layer.size = eng_m.f2{64,64}
	layer_id := add_layer(default_layer)
	current_layer = get_layer(layer_id)
	input_layer_name = "MAXIMUMLAYERNAME"
	layers_names = con.buf_init(0,string)
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
	color : Vec4 
	@static colora : [4]f32
	//color_picker4("Color",colora)
	color_edit4("ColorButton",&colora)
	checkbox("Show Grid",&is_show_grid)
	if is_show_grid  == false{
		grid_color = Vec4{0,0,0,0}
	}else{
		grid_color = Vec4{0.6,0.6, 0.6, 1}
	}
	selected_color = color_convert_float4to_u32(Vec4{colora[0],colora[1],colora[2],colora[3]})

	//layer controls
	for layer in layers.buffer{
		buf_push(&layers_names,layer.name)
	}

	input_text("Layer Name",transmute([]u8)input_layer_name)
	same_line()
	if button("AddLayer"){
		new_layer : Layer
		new_layer.size = {64,64}
		new_layer.name = strings.clone(input_layer_name)

		add_layer(new_layer)
	}
	@static current_layer_id : i32 = 0

	if begin_list_box("Layers"){
		for layer,i in &layers.buffer{
			text(layer.name)

			same_line()
			if button(fmt.tprintf("select %d",i)){
				current_layer_id = i32(i)
			}
			same_line()
			if button(fmt.tprintf("view/hide %d",i)){
				layer.is_show = ~layer.is_show
			}
			same_line()
			if button(fmt.tprintf("solo %d",i)){
				layer.is_solo = ~layer.is_solo
			}
		}
	}
	end_list_box()

	combo("Layers",&current_layer_id,layers_names.buffer[:])

	buf_clear(&layers_names)

	current_layer = buf_get(&layers,u64(current_layer_id))

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

	selectd_size := Vec2{sel_origin.x + grid_step,sel_origin.y + grid_step}
	
	draw_list_add_rect_filled(draw_list,selected_p,selectd_size,color_convert_float4to_u32(Vec4{1,0,1,1}))

	//prepare color circle
	//create and show grid lines
	//fill pixel in grid with current color
	if is_mouse_down(Mouse_Button.Left){
		//grid_step += 0.11
		size_x := int(clamp(grid_offset.x,0,current_layer.size.x))
		size_y := int(clamp(grid_offset.y,0,current_layer.size.y))
		mul_sizes := int(current_layer.size.x) * size_y
		painting_idx := int( size_x + mul_sizes)
		current_layer.grid[painting_idx].color = selected_color//0xFFFFFFFF
	}

	if is_mouse_down(Mouse_Button.Right){
		size_x := int(clamp(grid_offset.x,0,current_layer.size.x))
		size_y := int(clamp(grid_offset.y,0,current_layer.size.y))
		mul_sizes := int(current_layer.size.x) * size_y
		painting_idx := int( size_x + mul_sizes)
		current_layer.grid[painting_idx].color = 0x00000000
	}

	if is_mouse_down(Mouse_Button.Middle){
		scrolling.x += io.mouse_delta.x
		scrolling.y += io.mouse_delta.y
	}

	grid_step += io.mouse_wheel

	stride := current_layer.size.x
	x : int
	y : int
	idx : int
	test_red : f32
	for zoxel,i in current_layer.grid{
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
	
	for x := start.x; x < total_size_of_graph_x; x += grid_step{
		draw_list_add_line(draw_list,Vec2{x, origin.y}, Vec2{x, origin.y + draw_line_distance_x}, color_convert_float4to_u32(grid_color))
	}
	for y := start.y; y < total_size_of_graph_y; y += grid_step{
		draw_list_add_line(draw_list,Vec2{origin.x, y}, Vec2{origin.x + draw_line_distance_y, y}, color_convert_float4to_u32(grid_color))
	}
	//show layers
	//show visual choices //visible / solo / (hide|show)
	//output button 
	/*writes to disk in a mega texture with referencing info for the engine
		outputs all layers on texture with animation data
	*/





	end()
}