package reflecthelper

import reflect "core:reflect"

ReflectStruct :: struct{
	types : []^reflect.Type_Info,
	names : []string,
	tags  : []reflect.Struct_Tag,
	offsets : []uintptr,
}

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

get_struct :: proc(type : reflect.Type_Info) ->(success : bool,elements : ReflectStruct){
	using reflect
	result : ReflectStruct;
	if named_type,ok := type.variant.(Type_Info_Named); ok{
		if is_struct(named_type.base){
			result = get_elements(named_type.base)
			return true,result
		}
	}
	return false,result
}


