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
import linalg "core:math/linalg"
import thread "core:thread"
import syswin32 "core:sys/win32"
import sync "core:sync"

//TODO(Ray): Sprite Editor
/*
# Architecture
	| In general the code for doing graphics needs to be revamped and cleaned up.
	| 
	| We need a concept for a copyable texture/buffer to the gpu right now its very cumbersome
# brushes
	| The whole painting algorith needs to be redone perhaps with a volume
	| calculated per frame that is painted in rather than just stamping the brush per frame.
	| Calculate the rows per frame and divy them out to threads trying to get locality asmuch as possible
	| Also try to flatten at the same time.
	| Finally simify if it makes sense 
	| NI : allow brush size change(basics done but not centered around selected pixel) 
	| NI : show texel selection with pink outlines kind of have this
	| line tool allow for setting width specifically 2x1 line tool (Requestd by Timothy)'
	| square brush, circle brush, line brush
# Swatches
# ramps 
# pallete creation 
	| allow associating a swatch to a layer 
	| easily allow gradients to be created
	| easily create palletes based on an HSV curve that the user can create and adjust 
	| at any time.
	| 
# fill
# eyepicker

# move layers
	| calculate bounds rect while drawing on layer
	| when move/rotate without selecting anything whole layer is always auto selected
	| Have to be able to move layer contents
	| Rotate layer contents
	| TODO(Ray):Scale layer contents//will do this later for now we need to make brushes better.

#selection 
	| make selections
	| delete selections
	| fill selections
	| Move / Rotate and scale selections
	| magic wand selections 
	| selections based on pixel perfect rules or solid boundary rules
# filters 
	| bicubic
	| nearest neighbor

//low priority
# performance
	| cache the layer composite for each layer so we dont need to flatten the whole
	| stack for every brush stroke only the current layer and the  one below its cached result
	| when we brush we flatten only those layers annd push the result.
	| SimD the pixel writes and reads to do 4 at a time
	| write brush strokes on a seperate thread
	| for operations on large canvas we are slow but 
	| will speed things up when we do GPU based optimizations for now we get correctness done on the 
	| CPU

//Done but needs reviewing
# better canvas
	| use imgui image api to show the final canvas
	| map unmap to write to image every frame or when there is a change
	| do the layer color calcs on cpu

//after we got these basic implemented move to the animation editor
2. solo 
3. blending started but only mul implemented now
4. fix skipping whem  moving mouse fast.(may not be neccessary for a while)
6. output button : creates sprites in memory 
# layer moving 
	a. Simple one created can switch layer rows but cannot move to a specific
	   row can emulate this in imgui with a dummylayer inbetween each layer?

7. final output writes to disk in a mega texture with referencing info for the engine
		outputs all layers on texture with animation data

# undo / redo
//TODO(Ray):More todo as we go along
	| Have to implent all valid changes first before it can be called decent
	| record layer renames 
	| record layer blending changes
	| has to work for all layer groups / sprites active in memory
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
	scratch_grid = make([dynamic]eng_m.f4,int(default_size.x * default_size.y),int(default_size.x * default_size.y))
	current_selection.grid = make([dynamic]eng_m.f4,int(default_size.x * default_size.y),int(default_size.x * default_size.y))
	
	urdo.actions = con.buf_init(0,ActionsTypes)
	stroke =  con.buf_init(0,ActionPaintPixelDiffData)
	blend_mode_names = reflect.enum_field_names(BlendType)

	input_group_name = "MAXGROUPNAME"
	add_layer_group("Default")

	using gfx

	//create a gpu texture that can be written to by the cpu
	//4 32 bit float format
	gfx.image_blank(&texture,default_size,4,(4* 4)) 
	heap_idx := gfx.texture_add_format(&texture,platform.DXGI_FORMAT.DXGI_FORMAT_R32G32B32A32_FLOAT,&gfx.default_srv_desc_heap)
	blank_image_gpu_handle = gfx.get_gpu_handle_srv(gfx.device,gfx.default_srv_desc_heap.heap.value,heap_idx)

	max_gpu_buffer_size : u64 = u64(4 * 4 * default_size.x * default_size.y)
	buffer_gpu_arena = AllocateGPUArena(device.device, max_gpu_buffer_size)
	
	set_arena_constant_buffer(device.device, &buffer_gpu_arena, default_srv_desc_heap.count, default_srv_desc_heap.heap)
	default_srv_desc_heap.count += 1;

	gfx.dest_texture_resource = texture.state
	gfx.src_buffer_resource = buffer_gpu_arena.resource
	gfx.current_image_size = default_size
	gfx.Map(buffer_gpu_arena.resource, 0, nil, &mapped_buffer_data)

	current_group = con.buf_ptr(&layer_groups,u64(0))
	
	//TODO(Ray):Wont work if we change groups need to change this testingn for now
	//temp = make([dynamic]u32,int(current_group.size.x * current_group.size.y),int(current_group.size.x * current_group.size.y))
	//flatten_group(current_group,{0,0,current_group.size.x,current_group.size.y})
	flatten_group_init(current_group)
	has_painted = true
	has_first_paint = false
	current_tool_mode = .Brush
	tool_mode_change_request = .Brush

	//init thread stuff for mouse sampleing etc..
	//sync.ticket_mutex_init(&mouse_sub_sample_tick_mut)
	mouse_sub_samples = make([dynamic]eng_m.f2,0,0)
	mouse_proc : thread.Thread_Proc = subsample_mouse_input
	mouse_input_thread = thread.create_and_start(subsample_mouse_input)
}
mouse_sub_sample_tick_mut : sync.Ticket_Mutex
mouse_sub_samples : [dynamic]eng_m.f2

subsample_mouse_input :: proc(t: ^thread.Thread){
	/*
	sync.ticket_mutex_lock(&mouse_sub_sample_tick_mut)
	defer{
		sync.ticket_mutex_unlock(&mouse_sub_sample_tick_mut)
	}
	*/
	prev_sample_x : i32
	prev_sample_y : i32
	for {
		point : syswin32.Point
		syswin32.get_cursor_pos(&point)
		p : eng_m.f2 = eng_m.f2{f32(point.x),f32(point.y)}
		//fmt.println(p)
		if i32(p.x) == prev_sample_x && i32(p.y) == prev_sample_y{
			continue
		}
		prev_sample_x = i32(p.x)
		prev_sample_y = i32(p.y)
		append(&mouse_sub_samples,p)	
		if len(mouse_sub_samples) > 100{break}
	}
}

begin_move :: proc(){
	tool_mode_change_request = .Move
	//copy the starting point of the move into scratch
	copy(scratch_grid[:],current_layer.grid[:])
	scratch_bounds = current_layer.bounds
	scratch_bounds_quad = bounds_to_points(canvas_origin,scratch_bounds,grid_step) 
}

end_move :: proc(){
	tool_mode_change_request = .Brush
}

begin_rotate :: proc(){
}

end_rotate :: proc(){
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
	@static colora : eng_m.f4 = {0,0,0,1}
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
	defer{
		buf_clear(&current_group.layers_names)
		buf_clear(&group_names)
	}

	current_group = buf_ptr(&layer_groups,u64(current_group_id))
	_layer_id := buf_get(&current_group.layer_ids,u64(current_layer_id))
	current_layer = buf_ptr(&layer_master_list,u64(_layer_id))

	gfx.current_image_size = current_group.size

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

	//color_edit4("ColorButton",([]eng_m.f4)(colora))
	checkbox("Show Grid",&is_show_grid)
	input_int("Brush Size",&current_brush_size)
	if is_show_grid  == false{
		grid_color = Vec4{0,0,0,0}
	}else{
		grid_color = Vec4{0.6,0.6, 0.6, 1}
	}

	selected_color = {0,0,0,1}//eng_m.f4(colora)//color_convert_float4to_u32(Vec4{colora[0],colora[1],colora[2],colora[3]})

	input_text("Layer Name",transmute([]u8)input_layer_name)
	same_line()
	if button("AddLayer"){
		new_layer : Layer
		new_layer.size = default_size
		new_layer.name = strings.clone(input_layer_name)

		current_layer_id = add_layer(current_group,new_layer)
		current_layer_id := buf_get(&current_group.layer_ids,u64(current_layer_id))
		current_layer = buf_ptr(&layer_master_list,u64(current_layer_id))
	}
	if button("Save"){
	}

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
				//reset_selection_grid()
			}
			same_line()
			if button(fmt.tprintf("view/hide %d",i)){
				layer.is_show = ~layer.is_show
				flatten_group_init(current_group)
				push_to_gpu()
			}
			same_line()
			if button(fmt.tprintf("solo %d",i)){
				layer.is_solo = ~layer.is_solo
			}
			same_line()
			push_item_width(40)
			push_id(i32(i))
			if combo("BlendType",&layer.selected_blend_mode,blend_mode_names){
				layer.blend_mode = BlendType(layer.selected_blend_mode)
				flatten_group_init(current_group)
				push_to_gpu()
			}
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
			/*
			ls : LayerSwap
			ls.prev_layer_id = swap_id_a
			ls.layer_id = swap_id_b
			//current_undo_id = buf_push(&urdo.actions,ls)
			insert_undo(ls)
			*/
			buf_swap(&current_group.layer_ids,u64(swap_id_a),u64(swap_id_b))
			flatten_group_init(current_group)
			push_to_gpu()
		}
		end_list_box()
	}

	combo("Layers",&current_layer_id,current_group.layers_names.buffer[:])

	if button("Move"){
		if current_tool_mode == .Move{
			end_move()
		}else{
			begin_move()
		}
	}

	if button("Rotate"){
		if current_tool_mode == .Rotate{
			//end_rotate()
			tool_mode_change_request = .Brush
			copy(current_layer.grid[:],scratch_grid[:])
			current_layer.grid = temp_layer_grid
			copy(current_layer.grid[:],scratch_grid[:])
			current_layer.bounds.left = f32(find_left_bounds(current_layer^))
			current_layer.bounds.right = f32(find_right_bounds(current_layer^))
			current_layer.bounds.top = f32(find_top_bounds(current_layer^))
			current_layer.bounds.bottom = f32(find_bottom_bounds(current_layer^))
		}else{
			//begin_rotate()
			tool_mode_change_request = .Rotate
			//copy the starting point of the move into scratch
			copy(scratch_grid[:],current_layer.grid[:])
			temp_layer_grid = current_layer.grid
			current_layer.grid = scratch_grid

			reset_selection_grid()

			flatten_group_init(current_group)
			push_to_gpu()

			copy(scratch_grid[:],current_layer.grid[:])

			scratch_bounds = current_layer.bounds
			scratch_bounds_quad = bounds_to_points(canvas_origin,scratch_bounds,grid_step)
		}
	}

	//Brush combo box options are
	//1.Squard,circle,line
	//use a seperate thread to subsample mouse input
	//interpolate between frames all the places the mouse was.

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

	origin = {canvas_p0.x + scrolling.x, canvas_p0.y + scrolling.y}
	canvas_origin = f2{origin.x,origin.y}
	
	origin_no_scroll : Vec2 = {canvas_p0.x,canvas_p0.y}
	mouse_pos_in_canvas : Vec2
	raw_mouse_p_in_canvas : Vec2

	get_mouse_pos(&mouse_pos_in_canvas)

	raw_mouse_p_in_canvas.x = mouse_pos_in_canvas.x - origin_no_scroll.x
	raw_mouse_p_in_canvas.y = mouse_pos_in_canvas.y - origin_no_scroll.y

	mouse_pos_in_canvas.x = mouse_pos_in_canvas.x - origin.x
	mouse_pos_in_canvas.y = mouse_pos_in_canvas.y - origin.y

	mouse_grid_p : Vec2
	mouse_grid_p.x = mouse_pos_in_canvas.x / grid_step
	mouse_grid_p.y = mouse_pos_in_canvas.y / grid_step

	grid_offset : Vec2 = {f32(int(mouse_grid_p.x)),f32(int(mouse_grid_p.y))}
	sel_origin : Vec2
	sel_origin.x = origin.x + ((grid_offset.x) * (grid_step))
	sel_origin.y = origin.y + ((grid_offset.y) * (grid_step))
	selected_p := sel_origin
	
	//set_bounds_from_points(bounding_quad,&current_layer.bounds)
	current_layer.bounds_quad = bounds_to_points(f2{origin.x,origin.y},current_layer.bounds,grid_step)
	//draw bounds of current layer
	bounds_color := Vec4{1,0,0,0.9}
	if current_tool_mode == .Move{
		bounds_color = Vec4{0,0,1,1}
	}

	drawn_rect : eng_m.f4
	no_focus_action : 
	if is_window_focused(Focused_Flags.None){
		if raw_mouse_p_in_canvas.x < 0 || raw_mouse_p_in_canvas.y < 0{
			break no_focus_action
		}

		if current_tool_mode == .Move && tool_mode_change_request == .Move && is_mouse_down(Mouse_Button.Left){
			//and movemode is true and mouse down left button held
			//offset the pixels in the direction of the 
			//keeping the pixels alive even if they go off the canvas 
			//and only finalizing after enter is pushed.

			//for now the selection is the whole layer.
			is_moved_true := move_selection(current_layer,grid_offset,current_selection)
			if is_moved_true{
				copy(current_layer.grid[:],current_selection.grid[:])
				reset_selection_grid()
				flatten_group_init(current_group)
				push_to_gpu()	
			}
		}else if current_tool_mode == .Rotate && tool_mode_change_request == .Rotate && is_mouse_down(Mouse_Button.Left){
			test_angle += f64( io.mouse_delta.x)
			is_rotate_true := rotate_selection(origin,current_layer,test_angle,current_selection)
			if is_rotate_true {
				copy(current_layer.grid[:],current_selection.grid[:])
				reset_selection_grid()
				flatten_group_init(current_group)
				push_to_gpu()
			}
			
		}else if current_tool_mode == .Brush && tool_mode_change_request == .Brush && is_mouse_down(Mouse_Button.Left){
			prev_mouse_p := io.mouse_pos
			//println("start")
			/*
			sync.ticket_mutex_lock(&mouse_sub_sample_tick_mut)
			defer{
				sync.ticket_mutex_unlock(&mouse_sub_sample_tick_mut)
			}

			for mouse_sample in mouse_sub_samples{
				io.mouse_pos = imgui.Vec2{f32(mouse_sample.x),f32(mouse_sample.y)};	
				//println(f2{grid_offset.x,grid_offset.y})
				get_mouse_pos(&mouse_pos_in_canvas)

				raw_mouse_p_in_canvas.x = mouse_pos_in_canvas.x - origin_no_scroll.x
				raw_mouse_p_in_canvas.y = mouse_pos_in_canvas.y - origin_no_scroll.y

				mouse_pos_in_canvas.x = mouse_pos_in_canvas.x - origin.x
				mouse_pos_in_canvas.y = mouse_pos_in_canvas.y - origin.y

				mouse_grid_p : Vec2
				mouse_grid_p.x = mouse_pos_in_canvas.x / grid_step
				mouse_grid_p.y = mouse_pos_in_canvas.y / grid_step

				grid_offset : Vec2 = {f32(int(mouse_grid_p.x)),f32(int(mouse_grid_p.y))}
				drawn_rect = paint_on_grid_at(f2{grid_offset.x,grid_offset.y},current_layer,selected_color,current_brush_size)
				//println(f2{grid_offset.x,grid_offset.y})
			}
			//println("end")
			io.mouse_pos = prev_mouse_p
			*/

			drawn_rect = paint_on_grid_at(f2{grid_offset.x,grid_offset.y},current_layer,selected_color,current_brush_size)

			has_painted = true
			has_first_paint = true
		}

		if current_tool_mode == .Brush && tool_mode_change_request == .Brush && is_mouse_down(Mouse_Button.Right){
			drawn_rect = paint_on_grid_at(f2{grid_offset.x,grid_offset.y},current_layer,0x00000000,current_brush_size)
			has_painted = true
			has_first_paint = true
		}

		if is_mouse_down(Mouse_Button.Middle){
			scrolling.x += io.mouse_delta.x
			scrolling.y += io.mouse_delta.y
		}

		if current_tool_mode == .Brush && tool_mode_change_request == .Brush && is_mouse_released(Mouse_Button.Left){
			is_started_paint = false
			pa : PaintAdd
			pa.stroke = PaintStroke{start_stroke_idx,end_stroke_idx}
			//current_undo_id = buf_push(&urdo.actions,pa)
			insert_undo(pa)
		}

		if current_tool_mode == .Brush && tool_mode_change_request == .Brush && is_mouse_released(Mouse_Button.Right){
			is_started_paint = false
			pa : PaintAdd
			pa.stroke = PaintStroke{start_stroke_idx,end_stroke_idx}
			//current_undo_id = buf_push(&urdo.actions,pa)
			insert_undo(pa)
		}

		grid_step += (io.mouse_wheel * 0.1)
	}

	set_cursor_screen_pos(origin)
	current_size := default_size * grid_step

	if has_painted{
		flatten_group(current_group,drawn_rect)
		push_to_gpu()
		has_painted = false
	}

	imgui.image(imgui.Texture_ID(uintptr(blank_image_gpu_handle.ptr)),Vec2{current_size.x,current_size.y})

	if grid_step > 5 && is_show_grid{
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
	}

	selected_size := Vec2{sel_origin.x + f32(current_brush_size) * grid_step,sel_origin.y + f32(current_brush_size) * grid_step}
	grid_offset_offset := Vec2{f32(int(grid_offset.x)),f32(int(grid_offset.y))}
	grid_offset_size := Vec2{grid_offset_offset.x + grid_step,grid_offset_offset.y + grid_step}

	draw_list_add_rect_filled(draw_list,grid_offset_offset,grid_offset_size,color_convert_float4to_u32(Vec4{1,1,0,1}))
	draw_list_add_rect_filled(draw_list,selected_p,selected_size,color_convert_float4to_u32(Vec4{1,0,1,0.25}))

	if current_tool_mode == .Rotate{
		//redraw bounds based on rotated points
		quad_copy := scratch_bounds_quad
		quad_copy.br -= f2{origin.x,origin.y}
		quad_copy.tl -= f2{origin.x,origin.y}
		quad_copy.tr -= f2{origin.x,origin.y}
		quad_copy.bl -= f2{origin.x,origin.y}

		p0 := f2_to_Vec2(scratch_bounds_quad.tl)
		p1 := f2_to_Vec2(scratch_bounds_quad.bl)
		p2 := f2_to_Vec2(scratch_bounds_quad.tr)
		p3 := f2_to_Vec2(scratch_bounds_quad.br)
		draw_list_add_quad(draw_list, p0,p1,p3,p2,color_convert_float4to_u32(bounds_color),2)
		
	}

	bound_p_tl := Vec2{origin.x + current_layer.bounds.left * grid_step,origin.y + current_layer.bounds.top * grid_step}
	bound_p_size := Vec2{origin.x + current_layer.bounds.right * grid_step,origin.y + current_layer.bounds.bottom * grid_step}
	draw_list_add_rect(draw_list,bound_p_tl,bound_p_size,color_convert_float4to_u32(bounds_color))
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
						layer.grid[pixel.idx] = pixel.prev_color
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
						layer.grid[pixel.idx] = pixel.color
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

	if current_tool_mode != tool_mode_change_request{
		current_tool_mode = tool_mode_change_request
	}
	thread.destroy(mouse_input_thread)
	mouse_input_thread = thread.create_and_start(subsample_mouse_input)
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



//TODO(Ray):Preview window
/*
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
*/
