package reflecthelper

import reflect "core:reflect"
import intrinsics "core:intrinsics"
import tokenizer "../parser"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"
import "core:fmt"

ReflectStruct :: struct{
	types : []^reflect.Type_Info,
	names : []string,
	tags  : []reflect.Struct_Tag,
	offsets : []uintptr,
}

/*
get_elements :: proc(ptr : $T) -> ReflectStruct{
	using reflect
	result : ReflectStruct;
	if ptr != nil{
		id := typeid_of(type_of(ptr^))
		result.types = struct_field_types(id)
		result.names = struct_field_names(id)
		result.tags  = struct_field_tags(id)
		result.offsets = struct_field_offsets(id)
	}
	return result;
}
*/


get_struct_from_info :: proc(type : ^reflect.Type_Info) ->(success : bool,info : reflect.Type_Info_Struct,named_type : reflect.Type_Info_Named){
	using reflect
	result : Type_Info_Struct
	named_result : Type_Info_Named
	if named_type,ok := type.variant.(Type_Info_Named); ok{
		if is_struct(named_type.base){
			//result = get_elements(named_type.base.variant.(Type_Info_Struct))
			result = named_type.base.variant.(Type_Info_Struct)
			return true,result,named_type
		}
	}
	return false,result,named_result
}

get_struct_info :: proc(instance_of_type : $T)-> (success : bool,struct_info : reflect.Type_Info_Struct)where !intrinsics.type_is_pointer(T){
	using reflect
	result : Type_Info_Struct;
	info := type_info_of(T)
	if ok,s_info,ni := get_struct_from_info(info);ok{
		return true,s_info;
	}
	return false,result;
}

is_type :: proc(info : ^reflect.Type_Info,$T : typeid) -> bool{
	if info.id == typeid_of(T){
		return true
	}else{
		return false;
	}
}


is_buffer :: proc(info : ^reflect.Type_Info) -> bool{
	using reflect
	using tokenizer
	if named_type,ok := info.variant.(Type_Info_Named);info != nil && ok{
		
		name := named_type.name
		if strings.contains(name,"con.Buffer"){
			return true			
		}
	}
	return false
}

get_buffer_type :: proc(info : ^reflect.Type_Info) -> (typeid,bool){
	using reflect
	if named_type,ok := info.variant.(Type_Info_Named);info != nil && ok{
		name := named_type.name
		if strings.contains(name,"con.Buffer"){
			if struct_type,ok := named_type.base.variant.(Type_Info_Struct); ok{
				for type , i in struct_type.types{
					if is_dynamic_array(type){
						//elem.base.id
						d_type := type_info_base(type).variant.(Type_Info_Dynamic_Array)
						return d_type.elem.id,true
					}
				}
			}
		}
	}
	return nil,false
}
