package graphics

import con "../containers" 
import enginemath "../math"

import imgui  "../external/odin-imgui";
import runtime "core:runtime"

import reflect_helper "../reflecthelper"
import reflect "core:reflect"
import mem "core:mem"

//TODO(Ray):Need to fixed these to work with multipointers
input_matrix4x4 :: proc(f4x4value : enginemath.f4x4){
	//imgui.input_float4("",cast([4]f32)f4x4value[0])
	//imgui.input_float4("",cast([4]f32)f4x4value[1])
	//imgui.input_float4("",cast([4]f32)f4x4value[2])
	//imgui.input_float4("",cast([4]f32)f4x4value[3])
}

print_quat :: proc(data : rawptr){
	quat_value := (cast(^enginemath.Quat)data)^
	//imgui.input_float4("quat",transmute([4]f32)quat_value)
}

print_float :: proc(data : rawptr){
	value := (cast(^f32)data)
	imgui.input_float("float",value)
}

//TODO(Ray):Major issue with something getting passed unexpectedly
print_f2 :: proc(data : rawptr){
	f2value := cast(^[2]f32)((cast(^enginemath.f2)data))
	//imgui.input_float2("f2",f2value)
}

print_f3 :: proc(data : rawptr){
	f3value := (cast(^enginemath.f3)data)^
	//imgui.input_float3("f3",cast([3]f32)f3value)
}

print_f4 :: proc(data : rawptr){
	value := (cast(^enginemath.f4)data)^
//	imgui.input_float4("f4",cast([4]f32)value)
}

print_f4x4 :: proc(data : rawptr){
	f4x4value :=  (cast(^enginemath.f4x4)data)^
//	input_matrix4x4(f4x4value)
}

print_buffer :: proc(type : ^runtime.Type_Info,data : rawptr){
	using reflect_helper
	using con
	id,ok := get_buffer_type(type)
	if typeid_of(u64) == id{
			buf_val := (cast(^Buffer(u64))data)^
			for k := 0; k < cast(int)buf_len(buf_val);k+=1{
			value := i32(buf_get(&buf_val,u64(k)))
			imgui.input_int("",&value)
		}
	}
}

print_integer :: proc(ti : ^runtime.Type_Info,data : rawptr){
	value := cast(^i32)data
	imgui.input_int("",value)
}

print_dynamic_array :: proc(s_type : ^runtime.Type_Info,data : rawptr){
	using con
	using reflect
	d_ti := type_info_base(s_type).variant.(Type_Info_Dynamic_Array)
	e_size := d_ti.elem_size
	e_ti := d_ti.elem
	arra := (^mem.Raw_Dynamic_Array)(data)
	at_byte_index : u64

	for i := 0; i < arra.len;i+=1{
		print_type(e_ti, rawptr(uintptr(arra.data) + uintptr(at_byte_index)))
		at_byte_index = at_byte_index + cast(u64)e_size
	}
}

print_enum :: proc(ti : ^runtime.Type_Info,data : rawptr){
	using reflect
	e_ti := type_info_base(ti).variant.(Type_Info_Enum)
	for e , i in e_ti.names{
		if (^i64)(data)^ == transmute(i64)e_ti.values[i]{
			imgui.text(e_ti.names[i])
		}
	}
}

print_type :: proc(ti : ^runtime.Type_Info,data : rawptr){
	using reflect
	using enginemath
	using reflect_helper
	if is_type(ti,Quat){
		print_quat(data)
	}else if is_type(ti,f3){
		print_f3(data)
	}else if is_type(ti,f4x4){
		print_f4x4(data)
	}else if is_dynamic_array(ti){
		print_dynamic_array(ti,data)
	}else if is_struct(ti){
		print_struct(ti,data)
	}else if is_integer(ti){
		print_integer(ti,data)
	}else if is_enum(ti){
		print_enum(ti,data)
	}else if is_type(ti,f2){
		print_f2(data)
	}else if is_type(ti,f4){
		print_f4(data)
	}else if is_type(ti,f32){
		print_float(data)
	}
}

print_struct :: proc(ti : ^runtime.Type_Info,data : rawptr){
	using reflect_helper
	
	if ok,si,ni :=  get_struct_from_info(ti);ok{
		imgui.text(ni.name)

		for type, i in si.types{
			ptr_to_offset := rawptr(uintptr(data) + si.offsets[i])
			imgui.text(si.names[i])
			print_type(type,ptr_to_offset)
		}
	}
}

print_struct_from_ptr_value :: proc(ptr : $type){
	using reflect_helper
	if ok,struct_info  := get_struct_info(ptr^);ok{
		for type, i in struct_info.types{
			imgui.text(struct_info.names[i])
			ptr_to_offset := rawptr(uintptr(ptr) + struct_info.offsets[i])
			print_type(type,ptr_to_offset)
		}
	}
}
