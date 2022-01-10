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

ActionPaintPixelDiffData :: struct{
	idx : i32,
	layer_id : i32,
	color : u32,
	prev_color : u32,
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

ActionsTypes :: union{
	PaintAdd,
	LayerSwap,
	LayerAdd,
	//LayerDelete,
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

Zoxel :: struct{
	id : u64,
	ref : u64,
	color : u32,//for now 32 bit color could be other bit size
}

Layer :: struct{
	id : i32,
	name : string,
	grid : [dynamic]Zoxel,
	is_show : bool,
	is_solo : bool,	
	size : eng_m.f2,
	blend_mode : BlendType,
	selected_blend_mode : i32,
}

LayerGroup :: struct{
	id : i32,
	name : string,
	//layers : con.Buffer(Layer),
	layer_ids : con.Buffer(i32),
	layers_names : con.Buffer(string),
	gpu_image_id : u64,
	grid : [dynamic]Zoxel,
	size : eng_m.f2,
	size_in_bytes : int,
	current_layer_id : i32,
}

layer_groups : con.Buffer(LayerGroup)

group_names : con.Buffer(string)
blend_mode_names : []string

grid_step : f32 = 17.0
preview_grid_step : f32 = 6

current_group : ^LayerGroup
current_layer : ^Layer

selected_color : u32
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