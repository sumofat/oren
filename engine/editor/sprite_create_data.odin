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
import thread "core:thread"

BoundingRect :: struct{
	left : f32,
	top : f32,
	right : f32,
	bottom : f32,	
}

BoundingQuad :: struct{
	tl : eng_m.f2,
	bl : eng_m.f2,
	tr : eng_m.f2,
	br : eng_m.f2,
}	

ActionPaintPixelDiffData :: struct{
	idx : i32,
	layer_id : i32,
	color : eng_m.f4,
	prev_color : eng_m.f4,
}

PaintStroke :: struct{
	start_idx : u64,
	end_idx : u64,
}

PaintAdd :: struct{
	stroke : PaintStroke,
}

LayerSwap ::  struct{
	prev_layer_id : int,
	layer_id : int,
}

LayerAdd :: struct{
	group_id : i32,
	layer_id : i32,
	holding_idx : i32,
	insert_idx : i32,
}

LayerRemove :: struct{
	group_id : i32,
	layer_id : i32,
	holding_idx : i32,
	insert_idx : i32,
}

ActionsTypes :: union{
	PaintAdd,
	LayerSwap,
	LayerAdd,
	LayerRemove,
//	LayerModeChange,
//	EditoColorChange,
}


UndoRedo :: struct{
	pixel_diffs : con.Buffer(ActionPaintPixelDiffData),
	actions : con.Buffer(ActionsTypes),
}

BlendType :: enum{
	Normal,
	Multiply,
	Add,
}

/*
Zoxel :: struct{
	//id : u64,
	//ref : u64,
	color : u32,//for now 32 bit color could be other bit size
}
*/

Layer :: struct{
	id : i32,
	name : string,
	grid : [dynamic]eng_m.f4,
	is_show : bool,
	is_solo : bool,	
	size : eng_m.f2,
	blend_mode : BlendType,
	selected_blend_mode : i32,
	bounds : BoundingRect,
	bounds_quad : BoundingQuad,
	cache : LayerCache,
}

Brush :: struct{

}

Line :: struct{

}

TransformTool :: struct{
	is_selection : bool,
	selection : Selection,
	origin : eng_m.f2,//layermode this is middle of canvas
}
	
ToolMode :: enum{
	None,
	Brush,	
	Line,
	Move,
	Rotate,
	Scale,
	TransformTool,
}	
	
		
Selection ::	 struct{
	layer_id : i32,
	size : eng_m.f2,//always the same size as the current layer
	//bounds : BoundingRect,
	bounds_quad : BoundingQuad,
	grid : [dynamic]eng_m.f4,
}	

/*		
name -> laye		r_id
all_whit		e scratch_layer -> x -|__cache_layer0
base		_layer -> 0              _|
		
cachl0 -		> c0    -|__cache_layer1
laye		r1 -> 1 	_|
		
cachl1 -		> c1    -|__cache_layer2
laye		r2 -> 2 	_|
		
cachl2 -		> c2    -|__cache_layer3
laye		r3 -> 3 	_|
*/		

LayerCache :: struct{
	id : i32,
	layer_id : i32,
	size : eng_m.f2,
	grid : [dynamic]eng_m.f4,
}

LayerGroup :: struct{
	id : i32,
	name : string,
	layer_ids : con.Buffer(i32),
	layers_names : con.Buffer(string),
	gpu_image_id : u64,
	grid : [dynamic]eng_m.f4,
	size : eng_m.f2,
	size_in_bytes : int,
	current_layer_id : i32,
}   

layer_groups : con.Buffer(LayerGroup)

group_names : con.Buffer(string)
blend_mode_names : []string

grid_step : f32 = 1.0
preview_grid_step : f32 = 6

current_group : ^LayerGroup
current_layer : ^Layer

selected_color : eng_m.f4
is_show_grid : bool = true
grid_color := imgui.Vec4{50, 500, 50, 40}

input_layer_name : string
input_group_name : string

//undo ops
urdo : UndoRedo
current_undo_id : u64
stroke : con.Buffer(ActionPaintPixelDiffData)

is_started_paint : bool
current_layer_id : i32 = 1

layer_master_list : con.Buffer(Layer)
//layer_cache_list : con.Buffer(LayerCache)

has_painted := false

buffer_gpu_arena : platform.GPUArena
texture : gfx.Texture
default_size : eng_m.f2 = {512,512}
blank_image_gpu_handle : platform.D3D12_GPU_DESCRIPTOR_HANDLE
mapped_buffer_data : rawptr;
current_brush_size : i32 = 4

current_selection : Selection

current_tool_mode : ToolMode
tool_mode_change_request : ToolMode

scratch_bounds : BoundingRect
scratch_bounds_quad : BoundingQuad
scratch_grid : [dynamic]eng_m.f4
temp_layer_grid : [dynamic]eng_m.f4

canvas_origin : eng_m.f2

test_angle : f64
test_x : f32
test_y : f32
has_first_paint : bool
test_selected_points : [dynamic]imgui.Vec2
origin : imgui.Vec2
mouse_input_thread : ^thread.Thread
