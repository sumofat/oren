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
	is_show : bool,
	is_solo : bool,	
	size : eng_m.f2,
}

LayerGroup :: struct{
	name : string,
	layers : con.Buffer(Layer),
	layers_names : con.Buffer(string),
	gpu_image_id : u64,
	grid : [dynamic]Zoxel,
	size : eng_m.f2,
	size_in_bytes : int,
}

layer_groups : con.Buffer(LayerGroup)

group_names : con.Buffer(string)

grid_step : f32 = 17.0

current_group : ^LayerGroup
current_layer : ^Layer

selected_color : u32
is_show_grid : bool = true
grid_color := imgui.Vec4{50, 500, 50, 40}

input_layer_name : string
input_group_name : string

//TODO(Ray): Sprite Editor
/*
1. Allow for painting multiple texels at onece with a brush
	a. show texel selection with pink outlines
2. solo 
3. blending
4. fix skipping whem  moving mouse fast.
5. List all sprites created and switch at will
6. output button : creates sprites in memory 
7. final output writes to disk in a mega texture with referencing info for the engine
		outputs all layers on texture with animation data
*/

//TODO(Ray):Animation Editor
/*
1. show all sprite available in real time as in sprite editor
2. can scale rotate any way 
3. attach origin points.
4. create key frames
5. looping animation or frame by frame
6. create sprite sheet animations.
*/


init_sprite_creator :: proc(){
	group_names = con.buf_init(0,string)
	layer_groups = con.buf_init(0,LayerGroup)
	input_group_name = "MAXGROUPNAME"
	add_layer_group("Default")
}


init_layer_group :: proc(name : string) -> LayerGroup{
	result : LayerGroup

	default_layer : Layer
	default_layer.name = "default"
	default_layer.size = eng_m.f2{64,64}

	result.name = strings.clone(name)
	result.layers_names = con.buf_init(0,string)
	result.grid = make([dynamic]Zoxel,u64(default_layer.size.x * default_layer.size.y))
	result.layers = con.buf_init(0,Layer)
	result.size = default_layer.size
	result.size_in_bytes = int(default_layer.size.x * default_layer.size.y)
	layer_id := add_layer(&result,default_layer)
	input_layer_name = "MAXIMUMLAYERNAME"

	return result
}

add_layer_group :: proc(name : string) -> int{
	new_group : LayerGroup = init_layer_group(name)
	return int(con.buf_push(&layer_groups,new_group))
}

get_layer :: proc(group : ^LayerGroup,layer_id : int) -> Layer{
	layer := con.buf_get(&group.layers,u64(layer_id))
	return layer
}

add_layer :: proc(group : ^LayerGroup, layer_desc : Layer)  -> (layer_id : int){
	new_layer : Layer = layer_desc
	new_layer.grid = make([dynamic]Zoxel,int(layer_desc.size.x * layer_desc.size.y),int(layer_desc.size.x * layer_desc.size.y))
	return int(con.buf_push(&group.layers,new_layer))
}

remove_layer :: proc(layer_id : int){

}

unpack_color_32 :: proc(color : u32)-> [4]u8{

	result : [4]u8
	result[0] = u8(color) 		//a
	result[1] = u8(color >> 8)	//b
	result[2] = u8(color >> 16)	//g
	result[3] = u8(color >> 24)	//r
	return result
}

pack_color_32 :: proc(colors : [4]u8) -> u32{
	return u32((colors[0]) | (colors[1] << 8) | (colors[2] << 16) | (colors[3] << 24) )
}

blend_op_normal :: proc(source : u32,destination : u32) -> u32{
	result_unpacked : [4]u8
	s_channels := unpack_color_32(source)
	d_channels :=  unpack_color_32(destination)
	for i in 0..4{
		s := s_channels[i]
		d := d_channels[i]
		result_unpacked[i] = d + s
	}
	final_color := u32((u32(result_unpacked[3]) << 24) | (u32(result_unpacked[2]) << 16) | (u32(result_unpacked[1]) << 8) | u32(result_unpacked[0]) )
	return final_color
}

blend_op_mul :: proc(source : u32,destination : u32) -> u32{
	result_unpacked : [4]u8
	s_channels := unpack_color_32(source)
	d_channels :=  unpack_color_32(destination)
	for i in 0..3{
		s := s_channels[i]
		d := d_channels[i]
		result_unpacked[i] = u8(clamp(u32(d) * u32(s),0,254))
	}
	final_color := u32((u32(result_unpacked[3]) << 24) | (u32(result_unpacked[2]) << 16) | (u32(result_unpacked[1]) << 8) | u32(result_unpacked[0]) )
	return final_color
}

flatten_group :: proc(group : ^LayerGroup){
	//starting from bottom to top layer apply final blend and
	//pixel color and filtering to image
	temp : [dynamic]Zoxel = make([dynamic]Zoxel,group.size_in_bytes)
	prev_layer : Layer
	for layer,i in group.layers.buffer{
		//nothing to blend to
		if i == 0{
			prev_layer = layer
			continue
		}
		for texel,j in layer.grid{

			base : u32 = prev_layer.grid[j].color
			blend : u32 = texel.color


			result_color := blend_op_mul(base,blend)
			temp[j].color = result_color
		}
		prev_layer = layer
	}
	copy(group.grid[:],temp[:])
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
	@static current_layer_id : i32 = 0
	@static current_group_id : i32 = 0
	@static prev_group_id  : i32 = 0

	//layer controls
	
	for group in &layer_groups.buffer{
		buf_push(&group_names,group.name)
		for layer in group.layers.buffer{
			buf_push(&group.layers_names,layer.name)
		}
	}

	current_group = buf_ptr(&layer_groups,u64(current_group_id))
	current_layer = buf_ptr(&current_group.layers,u64(current_layer_id))

	input_text("Layer Group Name",transmute([]u8)input_group_name)
	same_line()
	if button("AddLayerGroup"){
		group_name := strings.clone(input_group_name)

		add_layer_group(input_group_name)
		current_group = buf_ptr(&layer_groups,u64(current_group_id))
	}
	combo("LayerGroups",&current_group_id,group_names.buffer[:])
	if current_group_id != prev_group_id{
		current_layer_id = 0
	}

	color_edit4("ColorButton",&colora)
	checkbox("Show Grid",&is_show_grid)
	if is_show_grid  == false{
		grid_color = Vec4{0,0,0,0}
	}else{
		grid_color = Vec4{0.6,0.6, 0.6, 1}
	}

	selected_color = color_convert_float4to_u32(Vec4{colora[0],colora[1],colora[2],colora[3]})

	input_text("Layer Name",transmute([]u8)input_layer_name)
	same_line()
	if button("AddLayer"){
		new_layer : Layer
		new_layer.size = {64,64}
		new_layer.name = strings.clone(input_layer_name)

		add_layer(current_group,new_layer)
		current_layer = buf_ptr(&current_group.layers,u64(current_layer_id))
	}
	if button("Save"){
		//save sprite with name
		// so it can be ided in animation editor
	}
	//Load any saved sprites to the board
	//ask if you want to save current before loading if modified from last save.

	if begin_list_box("Layers"){
		for layer,i in &current_group.layers.buffer{
			
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

	combo("Layers",&current_layer_id,current_group.layers_names.buffer[:])

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

	for layer in current_group.layers.buffer{
		if layer.is_show == false{continue}

		stride := layer.size.x
		x : int
		y : int
		idx : int
		for zoxel,i in layer.grid{
			sel_origin : Vec2
			sel_origin.x = origin.x + f32(x * int(grid_step))
			sel_origin.y = origin.y + f32(y * int(grid_step))
			selected_p := sel_origin 

			selectd_size := Vec2{sel_origin.x + grid_step,sel_origin.y + grid_step}
			pix_col : Vec4
			color_convert_u32to_float4(&pix_col,zoxel.color)
			draw_list_add_rect_filled(draw_list,selected_p,selectd_size,zoxel.color)
			if x == int(stride - 1){
				y = (y + 1) % int(stride)
			}
			x = (x + 1) % int(stride)
		}	
	}

	//if show_output{
	if true{
		stride := current_group.size.x
		x : int
		y : int
		idx : int
		flatten_group(current_group)
		for zoxel in current_group.grid{
			sel_origin : Vec2
			sel_origin.x = origin.x + f32(x * int(grid_step))
			sel_origin.y = origin.y + f32(y * int(grid_step))
			selected_p := sel_origin 

			selectd_size := Vec2{sel_origin.x + grid_step,sel_origin.y + grid_step}
			pix_col : Vec4
			color_convert_u32to_float4(&pix_col,zoxel.color)
			draw_list_add_rect_filled(draw_list,selected_p,selectd_size,zoxel.color)
			if x == int(stride - 1){
				y = (y + 1) % int(stride)
			}
			x = (x + 1) % int(stride)
		}
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
	end()


	if !begin("Animator Editor"){
		end()
	}

	//list all the sprites
	combo("Sprites",&current_group_id,group_names.buffer[:])
	
	//create instance of selected sprite in sprite editor
	//draw_list_add_image_quad(draw_list,)
	//draw_list_add_image_quad()
	//rotate scale and place 
	//editable origin 

	//animation timeline allow setting of keyframes

	end()
	prev_group_id = current_group_id

	buf_clear(&current_group.layers_names)
	buf_clear(&group_names)
}