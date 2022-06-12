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
import m "core:math/linalg/hlsl"
//Layers
init_layer_group :: proc(name : string) -> LayerGroup{
	result : LayerGroup

	default_layer : Layer
	default_layer.name = "background"
	default_layer.size = default_size

	result.name = strings.clone(name)
	result.layers_names = con.buf_init(0,string)
	result.grid = make([dynamic]eng_m.f4,int(default_layer.size.x * default_layer.size.y),int(default_layer.size.x * default_layer.size.y))
	//result.layers = con.buf_init(0,Layer)
	result.size = default_layer.size
	result.size_in_bytes = int(default_layer.size.x * default_layer.size.y)
	result.layer_ids = con.buf_init(0,i32)
	layer_id := add_layer(&result,default_layer)
	input_layer_name = "MAXIMUMLAYERNAME"

	master_layer_id := con.buf_get(&result.layer_ids,u64(layer_id))

	default_layer_ptr := con.buf_ptr(&layer_master_list,u64(master_layer_id))
	for zoxel in &default_layer_ptr.grid{
		color : eng_m.f4 = {1,1,1,1}//0xFFFFFFFF
		zoxel = color
	}
	
	default_layer.name = "draw layer 1"
	layer_id = add_layer(&result,default_layer)
	test_selected_points : [dynamic]imgui.Vec2 = make([dynamic]imgui.Vec2,int(default_layer.size.x * default_layer.size.y),int(default_layer.size.x * default_layer.size.y))

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
	new_layer.grid = make([dynamic]eng_m.f4,int(layer_desc.size.x * layer_desc.size.y),int(layer_desc.size.x * layer_desc.size.y))
	
	lc : LayerCache
	//lc.id = i32(con.buf_len(layer_cache_list))
	lc.layer_id = layer_id
	lc.size = layer_desc.size
	lc.grid = make([dynamic]eng_m.f4,int(layer_desc.size.x * layer_desc.size.y),int(layer_desc.size.x * layer_desc.size.y))
	
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

//we reference the scratch buffer for the copy
//TODO(Ray):Later on when we can resize the canvas we will have to make sure all sizes resize 
//and match
move_selection :: proc(layer : ^Layer,p : imgui.Vec2,selection : Selection) -> bool{
	if p.x <  0 || p.y < 0{
		//return false
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
		return false
	}

	bounds := scratch_bounds
	bounds_size_y := bounds.right - bounds.left
	bounds_size_x := bounds.bottom - bounds.top
	for row := int(bounds.top);row < int(bounds.bottom);row += 1{
		x = start_x
		if y > layer.size.y - 1 || row > int(layer.size.y) - 1{
			break
		}
		if y < 0 || row < 0{
			y+=1
			continue
		}
		for col := int(bounds.left);col < int(bounds.right);col += 1{
			if x > layer.size.x - 1 || col > int(layer.size.x)  - 1{
				break
			}
			if x < 0 || col < 0{
				x += 1
				continue
			}
			src_index := int((row * int(stride)) + col)
			src_texel := scratch_grid[src_index]
			layer.grid[src_index] = 0x00000000
			dest_row := y
			dest_column := x

			dest_index := int((dest_row *  stride) + dest_column)

			current_selection.grid[int(dest_index)] = src_texel
			x += 1
		}

		y += 1
	}

	layer.bounds.left = p.x
	if layer.bounds.left < 0{
		layer.bounds.left = 0
	}
	if layer.bounds.left > layer.size.x - 1{
		layer.bounds.left = layer.size.x
	}

	layer.bounds.right =  p.x + bounds_size_y
	if layer.bounds.right < 0{
		layer.bounds.right = 0
	}
	if layer.bounds.right > layer.size.x - 1{
		layer.bounds.right = layer.size.x
	}

	layer.bounds.top = p.y
	if layer.bounds.top < 0{
		layer.bounds.top = 0
	}

	if layer.bounds.top > layer.size.y - 1{
		layer.bounds.top  = layer.size.y
	}
	layer.bounds.bottom = p.y + bounds_size_x

	if layer.bounds.bottom < 0{
		layer.bounds.bottom = 0
	}
	if layer.bounds.bottom > layer.size.y - 1{
		layer.bounds.bottom  = layer.size.y
	}
	return true
}

rotate_selection :: proc(origin : imgui.Vec2,layer : ^Layer,degrees : f64,selection : Selection) -> bool{
	using eng_m
	using imgui

    rad : f64 = linalg.radians(degrees)
    al_rad : f64 = linalg.radians(0.0)
    bounds := scratch_bounds
	width := bounds.right - bounds.left
	height := bounds.bottom - bounds.top
	
	q : Quat = quat_identity
	x_rot := linalg.quaternion_angle_axis(f32(linalg.radians(180.0)), f3{1,0,0}) //* y_rot
	rot := linalg.quaternion_angle_axis(f32(rad), f3{0, 0, 1}) * x_rot
	up := gfx.quaternion_up(rot)
    right_dir := gfx.quaternion_right(rot)
	
	al_x_rot := linalg.quaternion_angle_axis(f32(linalg.radians(180.0)), f3{1,0,0}) //* y_rot
	al_rot := linalg.quaternion_angle_axis(f32(al_rad), f3{0, 0, 1}) * al_x_rot
	
	al_up := gfx.quaternion_up(al_rot)
    al_right_dir := gfx.quaternion_right(al_rot)

	top := (up * (height * 0.5))
    bottom := (up * (-height * 0.5))
	right := (right_dir * (width * 0.5))
	left := (right_dir * (-width * 0.5))
	
	al_top := (al_up * (height * 0.5))
    al_bottom := (al_up * (-height * 0.5))
	al_right := (al_right_dir * (width * 0.5))
	al_left := (al_right_dir * (-width * 0.5))

	layer_bounds_origin : f3 = {bounds.left + (width * 0.5),bounds.top + (height * 0.5),0}

	test_x = 0
	test_y = 0
	src_x : f32 = 0.0
	src_y : f32 = 0.0
	using math
	max_size_idx := int(layer.size.x * layer.size.y)
	for x := 0;x < int((f32(height * width) - 1) * 2);x += 1{
		full_top := up * (height - test_x)
		full_top.x = (full_top.x)
		full_top.y = (full_top.y)
		full_right := right_dir * (width - test_y)
		full_right.x = (full_right.x)
		full_right.y =  (full_right.y)
		dest_pixel_approx := layer_bounds_origin + left + bottom + full_right + full_top
		
		al_full_top := al_up * (height - test_x)
		al_full_right := al_right_dir * (width - test_y)
		
		src_texel_approx := layer_bounds_origin + al_left + al_bottom + al_full_right + al_full_top
		
		source_pixel_idx := int((int(src_texel_approx.y) * int(current_layer.size.x)) + int(src_texel_approx.x))
		dest_pixel_idx := int((int(dest_pixel_approx.y) * int(current_layer.size.x)) + int(dest_pixel_approx.x))

		factor : f32 = 0.7
		test_x += factor
		if test_x > height - 1{
			test_x = 0
			test_y += factor
		}
		if test_y > width  - 1{test_y = 0}
		src_y = test_x
		src_x = test_y
		
		if (source_pixel_idx > (max_size_idx - 1) || dest_pixel_idx > (max_size_idx - 1)) || 
			(source_pixel_idx < 0 || dest_pixel_idx < 0){
			continue
		}
		selection.grid[dest_pixel_idx] = temp_layer_grid[source_pixel_idx]
	} 

	bounds_origin : f2 = {origin.x + bounds.left + ((bounds.right - bounds.left) / 2),origin.y + bounds.top + ((bounds.bottom - bounds.top) / 2)}
	f3_bo := f3{bounds_origin.x,bounds_origin.y,0}
	tr :=  top + f3_bo + right
	tl :=  top + f3_bo + -right
	bl := -top + f3_bo + -right
	br := -top + f3_bo + right

	scratch_bounds_quad = BoundingQuad{tl.xy,bl.xy,tr.xy,br.xy}
	return true
}

find_top_bounds :: proc(layer : Layer) -> i32{
	for texel,i in layer.grid[:]{
		if texel != 0x00000000{
			return i32(i / int(layer.size.x))
		}
	}
	return min(i32)
}

find_left_bounds :: proc(layer : Layer)-> i32{
	stride := int(layer.size.x)
	for col := 0;col < int(layer.size.x) - 1;col += 1{
		for row := 0;row < int(layer.size.y) - 1;row += 1{
			idx := (row * stride) + col
			texel := layer.grid[idx]
			if texel != 0x00000000{
				return max(0,i32(col - 1))
			}
		}
	}
	return min(i32)
}

find_bottom_bounds :: proc(layer : Layer) -> i32{
	stride := int(layer.size.x)
	for row := int(layer.size.y) - 1;row >= 0;row-=1{
		for col := 0;col < int(layer.size.x ) - 1;col += 1{
			texel := layer.grid[(row * stride) + col]
			if texel != 0x00000000{
				return i32(row)
			}
		}
	}
	return max(i32)
}

find_right_bounds :: proc(layer : Layer)-> i32{
	stride := int(layer.size.x)
	for col := int(layer.size.x);col >= 0;col -= 1{
		for row := 0;row < int(layer.size.y) - 1;row += 1{
			idx := col + (row * stride)
			texel := layer.grid[idx]
			if texel != 0x00000000{
				return min(i32(stride),i32(col + 1))
			}
		}
	}
	return max(i32)
}

//painting ops 
start_stroke_idx : u64
end_stroke_idx : u64
paint_on_grid_at :: proc(grid_p : eng_m.f2,layer : ^Layer,color : eng_m.f4,brush_size : i32) -> (draw_rect : eng_m.f4){
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
					/*
					if is_started_paint == false {
						is_started_paint = true
						//start_stroke_idx = con.buf_push(&urdo.pixel_diffs,pixel_diff)
						//end_stroke_idx = start_stroke_idx
					}else{
						//end_stroke_idx = con.buf_push(&urdo.pixel_diffs,pixel_diff)
					}
					*/	
				//}
			}
		}
	}
	return drawn_rect
}

calculate_dim_of_extents :: proc(from : m.float2,to : m.float2,brush_size : f32) -> m.float4{
	result : m.float4	
	return result
}

test_is_p_in_volume :: proc(from : m.float2,to : m.float2,brush_size : f32) -> bool{
	result : bool
	return result
}

/*
paint_from_to :: proc(from : m.float2,to : m.float2,layer : ^Layer,color : u32,brush_size : i32) -> (draw_rect : eng_m.f4){
	//algorithm
	//go from first to second point sample pixels inside check coverage if over 0.5 paint
	//get a subset of possible pixels based on bounding box and iterate by scanline checking  
	//if we are inside the sum
	bounds := calculate_dim_of_extents(from,to,f32(brush_size))
	for y := bounds.top;y < bounds.bottom;y+=1{
		for x := bounds.left;x < bounds.right;x+=1{
			pixel_of_x := grid[x][y]
			if test_is_p_in_volume(from,to,brush_size,pixel_of_x.p){
				paint_pixel_at_p(pixel_of_x)
			}
		}
	}
}
*/

flatten_group :: proc(group : ^LayerGroup,drawn_rect : eng_m.f4){
	using eng_m
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

		for row : i32 = i32(drawn_rect.y);row < i32(drawn_rect.w);row += 1{
			for col : i32 = i32(drawn_rect.x);col < i32(drawn_rect.z);col += 1{ 
				x := f32(col)
				y := f32(row)
				size_x := int(clamp(x,0,layer.size.x - 1))
				size_y := int(clamp(y,0,layer.size.y - 1))
				mul_sizes := int(layer.size.x) * size_y
				painting_idx := int( size_x + mul_sizes)
				{
					base : f4 = prev_layer.cache.grid[painting_idx]
					blend : f4 = layer.grid[painting_idx]
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

//TODO(Ray): Try flattening only changed pixels.
//Mutithreading is possible but must be done in order in most cases?
//Also find ways to use caching to advantage so we 
//skip re calculating every layer where avoidable.
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
			base : eng_m.f4 = prev_layer.cache.grid[j]
			blend : eng_m.f4 = layer.grid[j]
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
}

/*
//TODO(Ray): Try flattening only changed pixels.
//Mutithreading is possible but must be done in order in most cases?
//Also find ways to use caching to advantage so we 
//skip re calculating every layer where avoidable.
old_flatten_group_init :: proc(group : ^LayerGroup){
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
}
*/

reset_selection_grid :: proc(){
	for texel in &current_selection.grid{
		texel = 0x00000000
	}
}
