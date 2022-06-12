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
import simd "core:simd"

//Convience functions
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


//Blend OP functions
old_blend_op_multiply :: proc(base : u32,blend : u32) -> u32{
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
	result_unpacked[3] = 255
	
	final_color := u32((u32(result_unpacked[3]) << 24) | (u32(result_unpacked[2]) << 16) | (u32(result_unpacked[1]) << 8) | u32(result_unpacked[0]) )
	return final_color
}

//Blend OP functions
blend_op_multiply :: proc(base : eng_m.f4,blend : eng_m.f4) -> eng_m.f4{
	result_unpacked : eng_m.f4
	//blend_channels := unpack_color_32(blend)
	//base_channels :=  unpack_color_32(base)
	a2 := blend[3]//f32(blend_channels[3]) / 255.0
	a1 := base[3]//f32(base_channels[3])  / 255.0
	for i in 0..2{
		bl := blend[i]//f32(blend_channels[i]) / 255.0
		ba := base[i]//f32(base_channels[i]) / 255.0
		bl = clamp(bl * ba,0.0,1.0)
		result_unpacked[i] = clamp(f32((ba * (1-a2) + bl * (a2))),0,1)//clamp(u8(((ba * (1 - a1) + bl * a2) * 255)),0,255)
	}

	result_unpacked[3] = 1//255

	final_color : eng_m.f4 = {1,1,1,1}//u32((u32(result_unpacked[3]) << 24) | (u32(result_unpacked[2]) << 16) | (u32(result_unpacked[1]) << 8) | u32(result_unpacked[0]) )

	return final_color
}

old_blend_op_normal :: proc(base : u32,blend : u32) -> u32{
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

blend_op_normal :: proc(base : eng_m.f4,blend : eng_m.f4) -> eng_m.f4{
	result_unpacked : eng_m.f4
	//blend_channels := unpack_color_32(blend)
	//base_channels :=  unpack_color_32(base)
	a2 := blend[3]//f32(blend_channels[3]) / 255.0
	a1 := base[3]//f32(base_channels[3])  / 255.0
	for i in 0..2{
		bl := blend[i]//f32(blend_channels[i]) / 255.0
		ba := base[i]//f32(base_channels[i]) / 255.0
		result_unpacked[i] = clamp(f32((ba * (1-a2) + bl * (a2))),0,1)//clamp(u8(((ba * (1 - a1) + bl * a2) * 255)),0,255)
	}		
	result_unpacked[3] = 1//255//blend_channels[3]
	//final_color : eng_m.f4 = //u32((u32(result_unpacked[3]) << 24) | (u32(result_unpacked[2]) << 16) | (u32(result_unpacked[1]) << 8) | u32(result_unpacked[0]) )
	return result_unpacked//final_color
}

bounds_to_points :: proc(origin : eng_m.f2,bounds : BoundingRect,grid_step : f32) -> BoundingQuad{
	using eng_m
	result : BoundingQuad
	//tl
	result.tl = f2{origin.x + current_layer.bounds.left * grid_step,origin.y + current_layer.bounds.top * grid_step}
	//bl
	result.bl = f2{origin.x + current_layer.bounds.left * grid_step,origin.y + current_layer.bounds.bottom * grid_step}
	//tr
	result.tr = f2{origin.x + current_layer.bounds.right * grid_step,origin.y + current_layer.bounds.top * grid_step}
	//br
	result.br = f2{origin.x + current_layer.bounds.right * grid_step,origin.y + current_layer.bounds.bottom * grid_step}
	return result
}

f2_to_Vec2 :: proc(a : eng_m.f2) -> imgui.Vec2{
	return imgui.Vec2{a.x,a.y}
}

is_point_in_rect :: proc(point : eng_m.f2,rect : BoundingRect) -> bool{
    if point.x > rect.left && point.y > rect.bottom && point.x < rect.right && point.y < rect.top{
        return true
    }
    return false
}

is_point_in_quad :: proc(point : eng_m.f2,rect : BoundingQuad) -> bool{
    if point.x > rect.tl.x && point.y > rect.bl.y && point.x < rect.tr.x && point.y < rect.tr.y{
        return true
    }
    return false
}

set_bounds_from_points :: proc(origin_p : eng_m.f2,quad : BoundingQuad) -> BoundingRect{
	quad_copy := quad
	quad_copy.br -= origin_p
	quad_copy.tl -= origin_p
	quad_copy.tr -= origin_p
	quad_copy.bl -= origin_p
	bounds : BoundingRect
	bounds.left = min(min(quad.br.x,quad.bl.x),min(quad.tl.x,quad.tr.x))
	bounds.right = max(max(quad.br.x,quad.bl.x),max(quad.tl.x,quad.tr.x))

	bounds.top = min(min(quad.br.y,quad.bl.y),min(quad.tl.y,quad.tr.y))
	bounds.bottom = max(max(quad.br.y,quad.bl.y),max(quad.tl.y,quad.tr.y))
	return bounds
}

/*
get_bounds_from_points :: proc(rect : BoundingRect,top : eng_m.f2,right : eng_m.f2){
	bounds_origin : f2 = {rect.left + ((rect.right - rect.left) / 2),rect.top + ((rect.bottom - rect.top) / 2)}
	f3_bo := f3{bounds_origin.x,bounds_origin.y,0}
	tr :=  top + f3_bo + right
	tl :=  top + f3_bo + -right
	bl := -top + f3_bo + -right
	br := -top + f3_bo + right

	bounding_quad := BoundingQuad{tl.xy,bl.xy,tr.xy,br.xy}
	//tl
	p0 := f2_to_Vec2(bounding_quad.tl)
	//bl
	p1 := f2_to_Vec2(bounding_quad.bl)
	//tr
	p2 := f2_to_Vec2(bounding_quad.tr)
	//br
	p3 := f2_to_Vec2(bounding_quad.br)
	
	bounds : BoundingRect
	bounds.left = min(min(quad.br.x,quad.bl.x),min(quad.tl.x,quad.tr.x))
	bounds.right = max(max(quad.br.x,quad.bl.x),max(quad.tl.x,quad.tr.x))

	bounds.top = min(min(quad.br.y,quad.bl.y),min(quad.tl.y,quad.tr.y))
	bounds.bottom = max(max(quad.br.y,quad.bl.y),max(quad.tl.y,quad.tr.y))
}
*/


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
		mem.copy(mapped_buffer_data,mem.raw_dynamic_array_data(top_layer.cache.grid),(cast(int)len(current_group.grid) - 1) * size_of(eng_m.f4))
	}
}

//UNDO
insert_undo :: proc(action : ActionsTypes){
	insert_id := current_undo_id
	con.buf_insert(&urdo.actions,insert_id,action)
	if con.buf_len(urdo.actions) > 1{
		current_undo_id += 1
	}
}
