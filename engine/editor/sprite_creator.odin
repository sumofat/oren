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
import reflect "core:reflect"
import runtime "core:runtime"
import mem "core:mem"

//TODO(Ray): Sprite Editor
/*
# undo / redo
	| In order for Undo Redo to be sensical we need to insert at the current undone layer
	| so we can redo and undo properly and not lose history.
	| record changes / delete / add layers
	| Have to implent all valid changes first before it can be called decent
	| record layer renames 
	| record layer blending changes
	| has to work for all layer groups / sprites active in memory
# brushes
	a. show texel selection with pink outlines
# Swatches
# fill
# eyepicker
2. solo 
3. blending started but only mul implemented now
4. fix skipping whem  moving mouse fast.(may not be neccessary for a while)
6. output button : creates sprites in memory 
# layer moving 
	a. Simple one created can switch layer rows but cannot move to a specific
	   row can emulate this in imgui with a dummylayer inbetween each layer?

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
	layer_master_list = con.buf_init(0,Layer)
	urdo.actions = con.buf_init(0,ActionsTypes)
	stroke =  con.buf_init(0,ActionPaintPixelDiffData)
	blend_mode_names = reflect.enum_field_names(BlendType)

	input_group_name = "MAXGROUPNAME"
	add_layer_group("Default")
}

init_layer_group :: proc(name : string) -> LayerGroup{
	result : LayerGroup

	default_layer : Layer
	default_layer.name = "background"
	default_layer.size = eng_m.f2{64,64}

	result.name = strings.clone(name)
	result.layers_names = con.buf_init(0,string)
	result.grid = make([dynamic]Zoxel,int(default_layer.size.x * default_layer.size.y),int(default_layer.size.x * default_layer.size.y))
	//result.layers = con.buf_init(0,Layer)
	result.size = default_layer.size
	result.size_in_bytes = int(default_layer.size.x * default_layer.size.y)
	result.layer_ids = con.buf_init(0,i32)
	layer_id := add_layer(&result,default_layer)
	input_layer_name = "MAXIMUMLAYERNAME"

	master_layer_id := con.buf_get(&result.layer_ids,u64(layer_id))

	default_layer_ptr := con.buf_ptr(&layer_master_list,u64(master_layer_id))
	for zoxel in &default_layer_ptr.grid{
		color :u32 = 0xFFFFFFFF
		zoxel.color = color
	}
	default_layer.name = "draw layer 1"
	layer_id = add_layer(&result,default_layer)

	return result
}

//painting ops 
start_stroke_idx : u64
end_stroke_idx : u64
paint_on_grid_at :: proc(grid_p : eng_m.f2,layer : ^Layer,color : u32){
	if grid_p.x <  0 || grid_p.y < 0{
		return
	}
	size_x := int(clamp(grid_p.x,0,layer.size.x))
	size_y := int(clamp(grid_p.y,0,layer.size.y))
	mul_sizes := int(layer.size.x) * size_y
	painting_idx := int( size_x + mul_sizes)
	if painting_idx >= 0 && painting_idx < int(layer.size.x * layer.size.y) - 1{
		prev_color := layer.grid[painting_idx].color
		if prev_color != color{
			layer.grid[painting_idx].color = color
			pixel_diff : ActionPaintPixelDiffData
			pixel_diff.idx = i32(painting_idx)
			pixel_diff.color = color
			pixel_diff.prev_color = prev_color
			pixel_diff.layer_id = layer.id
			if is_started_paint == false {
				is_started_paint = true
				start_stroke_idx = con.buf_push(&urdo.pixel_diffs,pixel_diff)
				end_stroke_idx = start_stroke_idx
			}else{
				end_stroke_idx = con.buf_push(&urdo.pixel_diffs,pixel_diff)
			}	
		}
		
	}
}


add_layer_group :: proc(name : string) -> int{
	new_group : LayerGroup = init_layer_group(name)
	return int(con.buf_push(&layer_groups,new_group))
}

get_layer :: proc(group : ^LayerGroup,layer_id : int) -> Layer{
	master_layer_id := con.buf_get(&group.layer_ids,u64(layer_id))
	return con.buf_get(&layer_master_list,u64(master_layer_id))
}

add_layer :: proc(group : ^LayerGroup, layer_desc : Layer)  -> (layer_id : i32){
	new_layer : Layer = layer_desc
	new_layer.id = group.current_layer_id
	group.current_layer_id += 1
	new_layer.grid = make([dynamic]Zoxel,int(layer_desc.size.x * layer_desc.size.y),int(layer_desc.size.x * layer_desc.size.y))
	master_layer_id := con.buf_push(&layer_master_list,new_layer)
 	group_layer_id := i32(con.buf_push(&group.layer_ids,i32(master_layer_id)))
	if group_layer_id == 0 || group_layer_id == 1{
		return group_layer_id	
	}
	la : LayerAdd
	la.group_id = group.id
	la.layer_id = new_layer.id
	la.holding_idx = i32(master_layer_id)
	la.insert_idx = group_layer_id
	//con.buf_push(&urdo.actions,la)
	insert_undo(la)
	return group_layer_id	
}

remove_layer :: proc(group : ^LayerGroup,id : u64){
	holding_idx := con.buf_get(&group.layer_ids,id)
	con.buf_del(&group.layer_ids,id)
	lr : LayerRemove
	lr.group_id = group.id
	//lr.layer_id = i32(id)
	lr.holding_idx = holding_idx	
	lr.insert_idx = i32(id)
	insert_undo(lr)
}

insert_undo :: proc(action : ActionsTypes){
	insert_id := current_undo_id
	con.buf_insert(&urdo.actions,insert_id,action)
	if con.buf_len(urdo.actions) > 1{
		current_undo_id += 1
	}
}

unpack_color_32 :: proc(color : u32)-> [4]u8{

	result : [4]u8
	result[0] = u8(color) 		//r
	result[1] = u8(color >> 8)	//g
	result[2] = u8(color >> 16)	//b
	result[3] = u8(color >> 24)	//a
	return result
}

pack_color_32 :: proc(colors : [4]u8) -> u32{
	return u32((colors[0]) | (colors[1] << 8) | (colors[2] << 16) | (colors[3] << 24) )
}

blend_op_multiply :: proc(base : u32,blend : u32) -> u32{
	result_unpacked : [4]u8
	blend_channels := unpack_color_32(blend)
	base_channels :=  unpack_color_32(base)
	a2 := f32(blend_channels[3]) / 255.0
	a1 := f32(base_channels[3])  / 255.0
	for i in 0..2{
		bl := f32(blend_channels[i]) / 255.0
		ba := f32(base_channels[i]) / 255.0
		bl = clamp(bl * ba,0.0,1.0)
		result_unpacked[i] = clamp(u8((ba * (1-a2) + bl * (a2)) * 255),0,255)//clamp(u8(((ba * (1 - a1) + bl * a2) * 255)),0,255)
	}		
	result_unpacked[3] = 255//blend_channels[3]
	
	final_color := u32((u32(result_unpacked[3]) << 24) | (u32(result_unpacked[2]) << 16) | (u32(result_unpacked[1]) << 8) | u32(result_unpacked[0]) )
	return final_color
}

blend_op_normal :: proc(base : u32,blend : u32) -> u32{
	result_unpacked : [4]u8
	blend_channels := unpack_color_32(blend)
	base_channels :=  unpack_color_32(base)
	a2 := f32(blend_channels[3]) / 255.0
	a1 := f32(base_channels[3])  / 255.0
	for i in 0..2{
		bl := f32(blend_channels[i]) / 255.0
		ba := f32(base_channels[i]) / 255.0
		result_unpacked[i] = clamp(u8((ba * (1-a2) + bl * (a2)) * 255),0,255)//clamp(u8(((ba * (1 - a1) + bl * a2) * 255)),0,255)
	}		
	result_unpacked[3] = 255//blend_channels[3]
	
	final_color := u32((u32(result_unpacked[3]) << 24) | (u32(result_unpacked[2]) << 16) | (u32(result_unpacked[1]) << 8) | u32(result_unpacked[0]) )
	return final_color
}

flatten_group :: proc(group : ^LayerGroup){
	//starting from bottom to top layer apply final blend and
	//pixel color and filtering to image
	temp : [dynamic]Zoxel = make([dynamic]Zoxel,int(group.size.x * group.size.y),int(group.size.x * group.size.y))
	defer{delete(temp)}
	for layer_id,i in group.layer_ids.buffer{
		//nothing to blend to
		layer := con.buf_get(&layer_master_list,u64(layer_id))
		if layer.is_show == false{
			//copy(group.grid[:],layer.grid[:])
			continue
		}
		for texel,j in layer.grid{

			base : u32 = temp[j].color
			blend : u32 = layer.grid[j].color
			if layer.blend_mode == .Normal{
				result_color := blend_op_normal(base,blend)
				temp[j].color = result_color
			}else if layer.blend_mode == .Multiply{
				result_color := blend_op_multiply(base,blend)
				temp[j].color = result_color
			}
		}
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
	@static colora : [4]f32 = {0,0,0,1}
	@static current_group_id : i32 = 0
	@static prev_group_id  : i32 = 0

	//layer controls
	
	for group in &layer_groups.buffer{
		buf_push(&group_names,group.name)
		for layer_id in group.layer_ids.buffer{
			layer := con.buf_get(&layer_master_list,u64(layer_id))
			buf_push(&group.layers_names,layer.name)
		}
	}

	current_group = buf_ptr(&layer_groups,u64(current_group_id))
	_layer_id := buf_get(&current_group.layer_ids,u64(current_layer_id))
	current_layer = buf_ptr(&layer_master_list,u64(_layer_id))
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

		current_layer_id = add_layer(current_group,new_layer)
		current_layer_id := buf_get(&current_group.layer_ids,u64(current_layer_id))
		current_layer = buf_ptr(&layer_master_list,u64(current_layer_id))
	}
	if button("Save"){
		//save sprite with name
		// so it can be ided in animation editor
	}
	//Load any saved sprites to the board
	//ask if you want to save current before loading if modified from last save.
	remove_id : int = -1
	swap_id_a : int = -1
	swap_id_b : int = -1
	pay_load : int
	if begin_list_box("Layers"){
		for layer_id,i in &current_group.layer_ids.buffer{
			layer := con.buf_ptr(&layer_master_list,u64(layer_id))
			push_id(i32(i))
			text(layer.name)
			if begin_drag_drop_source(Drag_Drop_Flags.SourceAllowNullId){
				pay_load = i
				set_drag_drop_payload("LAYERS_DND_ROW",rawptr(&pay_load),size_of(int))
				text(layer.name)
				end_drag_drop_source()
			}
			if begin_drag_drop_target(){
				if payload := accept_drag_drop_payload("LAYERS_DND_ROW");payload != nil{
					swap_id_a = (^int)(payload.data)^
					swap_id_b = i
					
				}
			}
			pop_id()

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
			same_line()
			push_item_width(40)
			push_id(i32(i))
			combo("BlendType",&layer.selected_blend_mode,blend_mode_names)
			layer.blend_mode = BlendType(layer.selected_blend_mode)
			pop_id()

			same_line()
			
			same_line()
			if button(fmt.tprintf("remove %d",i)){
				if i != 0{
					if i <= int(current_layer_id){
						current_layer_id -= 1
					} 
					remove_id = i
					//remove_layer(current_group,u64(i))
				}
			}
		}
		if remove_id >= 0{
			remove_layer(current_group,u64(remove_id))
		}
		if  swap_id_a >= 0 && swap_id_b >= 0{
			ls : LayerSwap
			ls.prev_layer_id = swap_id_a
			ls.layer_id = swap_id_b
			//current_undo_id = buf_push(&urdo.actions,ls)
			insert_undo(ls)
			buf_swap(&current_group.layer_ids,u64(swap_id_a),u64(swap_id_b))
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
	if is_window_focused(Focused_Flags.None){
		if is_mouse_down(Mouse_Button.Left){
			paint_on_grid_at(f2{grid_offset.x,grid_offset.y},current_layer,selected_color)
		}

		if is_mouse_down(Mouse_Button.Right){
			paint_on_grid_at(f2{grid_offset.x,grid_offset.y},current_layer,0x00000000)
		}

		if is_mouse_down(Mouse_Button.Middle){
			scrolling.x += io.mouse_delta.x
			scrolling.y += io.mouse_delta.y
		}

		if is_mouse_released(Mouse_Button.Left){
			is_started_paint = false
			pa : PaintAdd
			pa.stroke = PaintStroke{start_stroke_idx,end_stroke_idx}
			//current_undo_id = buf_push(&urdo.actions,pa)
			insert_undo(pa)
		}
		if is_mouse_released(Mouse_Button.Right){
			is_started_paint = false
			pa : PaintAdd
			pa.stroke = PaintStroke{start_stroke_idx,end_stroke_idx}
			//current_undo_id = buf_push(&urdo.actions,pa)
			insert_undo(pa)
		}

		grid_step += io.mouse_wheel
	}

	for layer_id in current_group.layer_ids.buffer{
		layer := con.buf_get(&layer_master_list,u64(layer_id))
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



	if !begin("TEST WINDOW"){
	}

	//if show_output{
	if true{
		get_cursor_screen_pos(&canvas_p0)
		canvas_size : Vec2
		get_content_region_avail(&canvas_size)
		canvas_p1 := Vec2{canvas_p0.x + canvas_size.x,canvas_p0.y + canvas_size.y}
		origin : Vec2 = {canvas_p0.x, canvas_p0.y}
		stride := current_group.size.x
		x : int
		y : int
		idx : int
		flatten_group(current_group)
		for zoxel in current_group.grid{
			sel_origin : Vec2
			sel_origin.x = origin.x + f32(x * int(preview_grid_step))
			sel_origin.y = origin.y + f32(y * int(preview_grid_step))
			selected_p := sel_origin 

			selectd_size := Vec2{sel_origin.x + preview_grid_step,sel_origin.y + preview_grid_step}
			draw_list_add_rect_filled(draw_list,selected_p,selectd_size,zoxel.color)
			if x == int(stride - 1){
				y = (y + 1) % int(stride)
			}
			x = (x + 1) % int(stride)
		}
	}
	end()

	if !begin("Animator Editor"){
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


	//Action HIstory
	if !begin("History Viewer"){

	}

	no_undo : 
	if button("UNDO"){
			if current_undo_id >= buf_len(urdo.actions){
				current_undo_id = buf_len(urdo.actions) - 1
				break no_undo
			}
			undo_action := buf_get(&urdo.actions,current_undo_id)
			switch a in undo_action {
				case PaintAdd:{
					//restore prev pixel
					stroke := a.stroke
					pixels := urdo.pixel_diffs.buffer[stroke.start_idx:stroke.end_idx + 1]
					for pixel in pixels{
						if layer_idx,ok := get_layer_idx_with_id(current_group^,u64(pixel.layer_id));ok{
							layer_id := current_group.layer_ids.buffer[layer_idx]
							layer := buf_ptr(&layer_master_list,u64(layer_id))
							layer.grid[pixel.idx].color = pixel.prev_color
						}else{
							tprintf("Todo failed to find layerid %d not applying undo operation \n",pixel.layer_id)
						}
					}
					if current_undo_id > 0{
						current_undo_id -= 1			
					}
				}
				case LayerSwap:{
					buf_swap(&current_group.layer_ids,u64(a.layer_id),u64(a.prev_layer_id))
					if current_undo_id > 0{
						current_undo_id -= 1			
					}
				}
				case LayerAdd:{
					buf_del(&current_group.layer_ids,u64(a.insert_idx))
					if current_layer_id == a.insert_idx{
						current_layer_id = 0
					}
					if current_undo_id > 0{
						current_undo_id -= 1			
					}
				}
				case LayerRemove:{
					buf_insert(&current_group.layer_ids,u64(a.insert_idx),i32(a.holding_idx))
					if current_layer_id == a.insert_idx{
						current_layer_id = 0
					}
					if current_undo_id > 0{
						current_undo_id -= 1			
					}
				}
			}
	}

	no_redo :  
	if button("REDO"){
			if current_undo_id >= buf_len(urdo.actions){
				break no_redo
			}
			undo_action := buf_get(&urdo.actions,current_undo_id)
			switch a in undo_action {
				case PaintAdd:{
					//restore prev pixel
					stroke := a.stroke
					pixels := urdo.pixel_diffs.buffer[stroke.start_idx:stroke.end_idx + 1]
					for pixel in pixels{
						if layer_idx,ok := get_layer_idx_with_id(current_group^,u64(pixel.layer_id));ok{
							layer_id := current_group.layer_ids.buffer[layer_idx]
							layer := buf_ptr(&layer_master_list,u64(layer_id))
							layer.grid[pixel.idx].color = pixel.color
						}else{
							tprintf("Todo failed to find layerid %d not applying redo operation \n",pixel.layer_id)
						}
					}
					if current_undo_id >= 0{
						current_undo_id += 1			
					}
				}
				case LayerSwap:{
					buf_swap(&current_group.layer_ids,u64(a.prev_layer_id),u64(a.layer_id))
					if current_undo_id >= 0{
						current_undo_id += 1			
					}
				}
				case LayerAdd:{
					buf_insert(&current_group.layer_ids,u64(a.insert_idx),i32(a.holding_idx))
					if current_layer_id == a.insert_idx{
						current_layer_id = 0
					}
					if current_undo_id >= 0{
						current_undo_id += 1			
					}
				}
				case LayerRemove:{
					buf_del(&current_group.layer_ids,u64(a.insert_idx))
					if current_layer_id == a.insert_idx{
						current_layer_id = 0
					}
					if current_undo_id >= 0{
						current_undo_id += 1			
					}
				}
			}
	}

	

	for action,i in urdo.actions.buffer{
		if i == int(current_undo_id){
			text("<<<<----->>>>")
		}
		switch a in action{
			case  PaintAdd : {
				text("Brush Stroke")
			}
			case LayerSwap : {
				text("Layer Move")
			}
			case LayerAdd : {
				text("Layer Add")
			}
			case LayerRemove : {
				text("Layer Remove")
			}
		}
	}

	end()
}

get_layer_idx_with_id :: proc(group : LayerGroup,id : u64)-> (u64,bool){
	for layer_id,i in group.layer_ids.buffer{
		layer := con.buf_get(&layer_master_list,u64(layer_id))
		if layer.id == i32(id){
			return u64(i),true
		}
	}
	return 0,false
}