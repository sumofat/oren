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
# move layers
	| calculate bounds rect while drawing on layer
	| when move/rotate without selecting anything whole layer is always auto selected
	| Have to be able to move layer contents
	| Rotate layer contents
	| Scale layer contents
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
# brushes
	| allow brush size change(basics done but not centered around selected pixel)
	| show texel selection with pink outlines
	| line tool allow for setting width specifically 2x1 line tool (Requestd by Timothy)
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
	
	current_selection.grid = make([dynamic]u32,int(default_size.x * default_size.y),int(default_size.x * default_size.y))
	
	urdo.actions = con.buf_init(0,ActionsTypes)
	stroke =  con.buf_init(0,ActionPaintPixelDiffData)
	blend_mode_names = reflect.enum_field_names(BlendType)

	input_group_name = "MAXGROUPNAME"
	add_layer_group("Default")

	using gfx

	//create a gpu texture that can be written to by the cpu
	gfx.image_blank(&texture,default_size,4,4)
	heap_idx := gfx.texture_add(&texture,&gfx.default_srv_desc_heap)
	blank_image_gpu_handle = gfx.get_gpu_handle_srv(gfx.device,gfx.default_srv_desc_heap.heap.value,heap_idx)

	max_gpu_buffer_size : u64 = u64(size_of(u32) * default_size.x * default_size.y)
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
}

init_layer_group :: proc(name : string) -> LayerGroup{
	result : LayerGroup

	default_layer : Layer
	default_layer.name = "background"
	default_layer.size = default_size

	result.name = strings.clone(name)
	result.layers_names = con.buf_init(0,string)
	result.grid = make([dynamic]u32,int(default_layer.size.x * default_layer.size.y),int(default_layer.size.x * default_layer.size.y))
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
		zoxel = color
	}
	
	default_layer.name = "draw layer 1"
	layer_id = add_layer(&result,default_layer)

	return result
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
	new_layer.bounds.top = max(f32)
	new_layer.bounds.left = max(f32)
	group.current_layer_id += 1
	new_layer.grid = make([dynamic]u32,int(layer_desc.size.x * layer_desc.size.y),int(layer_desc.size.x * layer_desc.size.y))
	
	lc : LayerCache
	//lc.id = i32(con.buf_len(layer_cache_list))
	lc.layer_id = layer_id
	lc.size = layer_desc.size
	lc.grid = make([dynamic]u32,int(layer_desc.size.x * layer_desc.size.y),int(layer_desc.size.x * layer_desc.size.y))
	
	/*
	for c in &lc.grid{
		c = 0xFFFFFFFF
	}
	*/

	new_layer.cache = lc

	master_layer_id := con.buf_push(&layer_master_list,new_layer)
 	group_layer_id := i32(con.buf_push(&group.layer_ids,i32(master_layer_id)))
	
	if group_layer_id == 0 || group_layer_id == 1{
		return group_layer_id	
	}

	rect : eng_m.f4 = {0,0,group.size.x - 1,group.size.y - 1}
	
	flatten_group_init(group)
	push_to_gpu()
	//TODO(Ray):Reinstate this later.
/*
	la : LayerAdd
	la.group_id = group.id
	la.layer_id = new_layer.id
	la.holding_idx = i32(master_layer_id)
	la.insert_idx = group_layer_id
	//con.buf_push(&urdo.actions,la)
	insert_undo(la)
*/
	return group_layer_id	
}

remove_layer :: proc(group : ^LayerGroup,id : u64){
	holding_idx := con.buf_get(&group.layer_ids,id)
	con.buf_del(&group.layer_ids,id)

	flatten_group_init(group)	
	push_to_gpu()
/*
	lr : LayerRemove
	lr.group_id = group.id
	//lr.layer_id = i32(id)
	lr.holding_idx = holding_idx	
	lr.insert_idx = i32(id)
	insert_undo(lr)
*/
}

move_selection :: proc(layer : ^Layer,p : imgui.Vec2,selection : Selection){
	if p.x <  0 || p.y < 0{
		return
	}

	//copy the layer to the selection grid
	//replace the current layer grid with the selection grid temporarily
	stride := layer.size.x

	x := p.x//selection.bounds.left
	start_x := x
	y := p.y//selection.bounds.top
	//dest_start := &selection.grid[0]//&selection.grid[int((y * stride) + x)]
	row_size := layer.size.x * size_of(u32)//(layer.bounds.right - layer.bounds.left) * size_of(u32)
	if row_size > layer.size.x * size_of(u32){
		return
	}
	bounds_size_y := layer.bounds.right - layer.bounds.left
	bounds_size_x := layer.bounds.bottom - layer.bounds.top
	for row := int(layer.bounds.top);row < int(layer.bounds.bottom);row += 1{
		x = start_x
		for col := int(layer.bounds.left);col < int(layer.bounds.right);col += 1{
			src_index := int((row * int(stride)) + col)
			src_texel := layer.grid[src_index]
			//layer.grid[src_index] = 0x00000000
			dest_row := y
			dest_column := x

			dest_index := int((y *  stride) + x)

			current_selection.grid[int(dest_index)] = src_texel
			x += 1
		}
		y += 1
	}
	//also reset bounds to offset from  the new  p.x
	layer.bounds.left = p.x
	layer.bounds.right =  p.x + bounds_size_x
	layer.bounds.top = p.y
	layer.bounds.bottom = p.y + bounds_size_y
}

move_origin :: proc(layer : ^Layer,offset : eng_m.f2,selection : Selection){

}

rotate_selection :: proc(layer : ^Layer,degrees : f32,selection : Selection){
	//get the origin of selection or layer
}

scale_selection :: proc(layer : ^Layer,amount : i32,selection : Selection){

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

//painting ops 
start_stroke_idx : u64
end_stroke_idx : u64
paint_on_grid_at :: proc(grid_p : eng_m.f2,layer : ^Layer,color : u32,brush_size : i32) -> (draw_rect : eng_m.f4){
	if grid_p.x <  0 || grid_p.y < 0{
		return
	}

	if layer.bounds.top > (grid_p.y){
		layer.bounds.top = (grid_p.y)
	}
	if layer.bounds.left > (grid_p.x){
		layer.bounds.left = (grid_p.x)
	}
	brush_max_y := (grid_p.y) + f32(brush_size)
	if layer.bounds.bottom < brush_max_y{
		layer.bounds.bottom = brush_max_y
	}
	brush_max_x := (grid_p.x) + f32(brush_size)
	if layer.bounds.right < brush_max_x{
		layer.bounds.right = brush_max_x
	}

	//TODO(Ray): Later on we will need support for negative indices as the brush
	//should go left and up of the pointer as well for intuitive drawing
	drawn_rect : eng_m.f4
	drawn_rect.x = grid_p.x
	drawn_rect.y = grid_p.y

	//half_dim := brush_size

	for row : i32 = 0;row < brush_size;row +=1{
		for col : i32 = 0;col < brush_size;col += 1{
			x := grid_p.x + f32(col)
			y := grid_p.y + f32(row)
			size_x := int(clamp(x,0,layer.size.x - 1))
			size_y := int(clamp(y,0,layer.size.y - 1))
			drawn_rect.z = f32(size_x) + 1
			drawn_rect.w = f32(size_y) + 1

			//NOTE(RAY):I cant remember why we mul size here.
			stride := int(layer.size.x)
			mul_sizes := stride * size_y
			painting_idx := int( size_x + mul_sizes)
			if painting_idx >= 0 && painting_idx < int(layer.size.x * layer.size.y) - 1{
				prev_color := layer.grid[painting_idx]
				//if prev_color != color{
					layer.grid[painting_idx] = color
					pixel_diff : ActionPaintPixelDiffData
					pixel_diff.idx = i32(painting_idx)
					pixel_diff.color = color
					pixel_diff.prev_color = prev_color
					pixel_diff.layer_id = layer.id
					if is_started_paint == false {
						is_started_paint = true
						//start_stroke_idx = con.buf_push(&urdo.pixel_diffs,pixel_diff)
						//end_stroke_idx = start_stroke_idx
					}else{
						//end_stroke_idx = con.buf_push(&urdo.pixel_diffs,pixel_diff)
					}	
				//}
				
			}
		}
	}
	return drawn_rect
}

push_to_gpu :: proc(){
	top_layer_idx : u64 = con.buf_len(current_group.layer_ids) - 1
	top_layer_id : i32
	top_layer : Layer
	found := false
	for i := con.buf_len(current_group.layer_ids);i > 0;i -= 1{
		top_layer_id = con.buf_get(&current_group.layer_ids,u64(i - 1))
		top_layer = con.buf_get(&layer_master_list,u64(top_layer_id))
		
		if top_layer.is_show{
			found = true
			break
		}
	}
	if found == true{
		mem.copy(mapped_buffer_data,mem.raw_dynamic_array_data(top_layer.cache.grid),(cast(int)len(current_group.grid) - 1) * size_of(u32))
	}
}

flatten_group :: proc(group : ^LayerGroup,drawn_rect : eng_m.f4){
	//starting from bottom to top layer apply final blend and
	//pixel color and filtering to image
	prev_layer_id := con.buf_get(&group.layer_ids,u64(0))

	prev_layer := con.buf_ptr(&layer_master_list,u64(prev_layer_id))
	for layer_id,i in group.layer_ids.buffer{
		//nothing to blend to
		layer := con.buf_ptr(&layer_master_list,u64(layer_id))
		if i != 0{
			prev_layer = con.buf_ptr(&layer_master_list,u64(prev_layer_id))
		}	

		if layer.is_show == false{
			continue
		}
		
		for row : i32 = i32(drawn_rect.y);row < i32(drawn_rect.w);row +=1{
			for col : i32 = i32(drawn_rect.x);col < i32(drawn_rect.z);col += 1{ 
				x := f32(col)
				y := f32(row)
				size_x := int(clamp(x,0,layer.size.x - 1))
				size_y := int(clamp(y,0,layer.size.y - 1))
				mul_sizes := int(layer.size.x) * size_y
				painting_idx := int( size_x + mul_sizes)
				{
					base : u32 = prev_layer.cache.grid[painting_idx]
					blend : u32 = layer.grid[painting_idx]
					//if base == 0 && blend == 0{continue}
					if layer.blend_mode == .Normal{
						result_color := blend_op_normal(base,blend)
						layer.cache.grid[painting_idx] = result_color
					}else if layer.blend_mode == .Multiply{
						result_color := blend_op_multiply(base,blend)
						layer.cache.grid[painting_idx] = result_color
					}
				}
			}
		}
		prev_layer_id = layer_id
	}
}

flatten_group_init :: proc(group : ^LayerGroup){
	//starting from bottom to top layer apply final blend and
	//pixel color and filtering to image
	prev_layer_id := con.buf_get(&group.layer_ids,u64(0))
	prev_layer := con.buf_ptr(&layer_master_list,u64(prev_layer_id))

	for layer_id,i in group.layer_ids.buffer{
		//nothing to blend to
		layer := con.buf_get(&layer_master_list,u64(layer_id))
		if i != 0{
			prev_layer = con.buf_ptr(&layer_master_list,u64(prev_layer_id))
		}

		if layer.is_show == false{
			continue
		}

		for texel,j in layer.grid{
			base : u32 = prev_layer.cache.grid[j]
			blend : u32 = layer.grid[j]
			//if base == 0 && blend == 0{continue}
			if layer.blend_mode == .Normal{
				result_color := blend_op_normal(base,blend)
				layer.cache.grid[j] = result_color
			}else if layer.blend_mode == .Multiply{
				result_color := blend_op_multiply(base,blend)
				layer.cache.grid[j] = result_color
			}
		}
		prev_layer_id = layer_id
	}
//	copy(group.grid[:],temp[:])
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

	color_edit4("ColorButton",&colora)
	checkbox("Show Grid",&is_show_grid)
	input_int("Brush Size",&current_brush_size)
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
		new_layer.size = default_size
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

	if button("Move tool"){
		//copy bounds rect from layer to selection
		

		is_move_mode = !is_move_mode
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

	origin : Vec2 = {canvas_p0.x + scrolling.x, canvas_p0.y + scrolling.y}
	mouse_pos_in_canvas : Vec2
	get_mouse_pos(&mouse_pos_in_canvas)
	mouse_pos_in_canvas.x = mouse_pos_in_canvas.x - origin.x
	mouse_pos_in_canvas.y = mouse_pos_in_canvas.y - origin.y

	mouse_grid_p : Vec2
	mouse_grid_p.x = mouse_pos_in_canvas.x / grid_step
	mouse_grid_p.y = mouse_pos_in_canvas.y / grid_step

	grid_offset : Vec2 = {mouse_grid_p.x,mouse_grid_p.y}
	sel_origin : Vec2
	sel_origin.x = origin.x + ((grid_offset.x) * (grid_step))
	sel_origin.y = origin.y + ((grid_offset.y) * (grid_step))
	selected_p := sel_origin

	drawn_rect : eng_m.f4
	if is_window_focused(Focused_Flags.None){

		if is_move_mode == true && is_mouse_down(Mouse_Button.Left){
			//and movemode is true and mouse down left button held
			//offset the pixels in the direction of the 
			//keeping the pixels alive even if they go off the canvas 
			//and only finalizing after enter is pushed.

//for now the selection is the whole layer.

			move_selection(current_layer,grid_offset,current_selection)
			if is_move_mode{
				copy(current_layer.grid[:],current_selection.grid[:])
				flatten_group_init(current_group)
				push_to_gpu()
			}
		}else if is_mouse_down(Mouse_Button.Left){
			drawn_rect = paint_on_grid_at(f2{grid_offset.x,grid_offset.y},current_layer,selected_color,current_brush_size)
			has_painted = true
		}

		if is_mouse_down(Mouse_Button.Right){
			drawn_rect = paint_on_grid_at(f2{grid_offset.x,grid_offset.y},current_layer,0x00000000,current_brush_size)
			has_painted = true
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

		grid_step += (io.mouse_wheel * 0.1)

	}

	set_cursor_screen_pos(origin)
	current_size := default_size * grid_step

	if has_painted{
		//drawn_rect_test : eng_m.f4 = {grid_offset.x,grid_offset.y,grid_offset.x + 2,grid_offset.y + 2}
		flatten_group(current_group,drawn_rect)
//		flatten_group_init(current_group)
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
	draw_list_add_rect_filled(draw_list,selected_p,selected_size,color_convert_float4to_u32(Vec4{1,0,1,0.25}))

	//draw bounds of current layer
	draw_list_add_rect(draw_list,selected_p,selected_size,color_convert_float4to_u32(Vec4{1,0,0,0.9}))
	bound_p_origin := Vec2{origin.x + current_layer.bounds.left * grid_step,origin.y + current_layer.bounds.top * grid_step}
	bound_p_size := Vec2{origin.x + current_layer.bounds.right * grid_step,origin.y + current_layer.bounds.bottom * grid_step}
	draw_list_add_rect(draw_list,bound_p_origin,bound_p_size,color_convert_float4to_u32(Vec4{1,0,0,0.9}))



	end()

/*
	//calculate bounding rects
	//top is highest row in grid
	//right is highest col 
	//lef is low col
	//bot is low row in grid
	for layer_id in current_group.layer_ids.buffer{
		layer := buf_get(&layer_master_list,u64(layer_id))
		stride := current_group.size.x
		t : i32 = 0
		r : i32 = max(i32)
		l : i32 = 0
		b : i32 = max(i32)
		for row := 0;row < int(current_group.size.y);row+=1{
			for col := 0;col < int(current_group.size.x);col+= 1{
				index := (row * int(stride)) + col
				texel := layer.grid[index].color
				if texel != 0{
					if t < row{
						t = index
					}else if l < col{
						l = index
					}else if r > col{
						r = index
					}else if b > row{
						b = index
					} 
				}
			}
		}

		draw_list_add_rect_filled(draw_list,selected_p,selectd_size,zoxel.color)
		///layer.bounding_rect = {0,0,0,0}
	}
	//if move tool is active show bounds and controls
	//buttons for scale move and rotate
	/*
	r = rotate
	s = scale
	m = move
	r...s...r
	.		.
	.		.
	s   m   s
	.		.
	.		.
	r   s...r
	*/
*/

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