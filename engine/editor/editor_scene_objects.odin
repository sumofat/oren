package editor
import gfx "../graphics"
import container "../containers"
import imgui  "../external/odin-imgui"
import reflect "core:reflect"
import enginemath "../math"
import ref "../reflecthelper"
import mem "core:mem"
//node_id : u64
//import la "core:math/linalg"

EditorSceneTree :: struct{
	root : ^gfx.SceneObject,
	is_showing : bool,
}

editor_scene_tree_init :: proc(tree : ^EditorSceneTree){

}

print_so :: proc(so : ^gfx.SceneObject,asset_ctx : ^gfx.AssetContext){
	using ref
	using container
	using reflect
	using mem
	using gfx

	if ok,struct_info  := get_struct_info(so^);ok{
		for type, i in struct_info.types{
			imgui.text(struct_info.names[i])
			ptr_to_offset := rawptr(uintptr(so) + struct_info.offsets[i])

			if struct_info.names[i] == "children"{
				
					s_ti := type_info_base(type).variant.(Type_Info_Struct)
					buffer_type := s_ti.types[0]
					buffer_type_ti := type_info_base(buffer_type).variant.(Type_Info_Struct)
					da_ti := buffer_type_ti.types[0]
					d_ti := type_info_base(da_ti).variant.(Type_Info_Dynamic_Array)

					e_size := d_ti.elem_size
					e_ti := d_ti.elem
					arra := (^mem.Raw_Dynamic_Array)(ptr_to_offset)
					at_byte_index : u64

					for i := 0; i < arra.len;i+=1{
						value := cast(^u64)rawptr(uintptr(arra.data) + uintptr(at_byte_index))
						

							//imgui.input_int("",value)
							//print_type(e_ti, rawptr(uintptr(arra.data) + uintptr(at_byte_index)))
							child_so := buf_get(&asset_ctx.scene_objects,(value^))
							if imgui.tree_node(value,"child",child_so.name){
								at_byte_index = at_byte_index + cast(u64)e_size
								print_so(&child_so,&asset_ctx)
								imgui.tree_pop();
							}
					}
			}else{
				print_type(type,ptr_to_offset)
			}
		}
	}
}

editor_scene_tree_display :: proc(so : ^gfx.SceneObject,ctx : ^gfx.AssetContext,id : u64){
	using container
	using reflect
	using enginemath
	using gfx
	using ref
	if so != nil{
		is_tree_node := false
		if len(so.name) > 0{
			node_id := cast(rawptr)uintptr(id)
			is_tree_node = imgui.tree_node(node_id,"test",so.name)

		}
		else{
			node_id := cast(rawptr)uintptr(id)
			is_tree_node = imgui.tree_node(node_id,"Selectable Node")
		}
		
		if is_tree_node{
			
			//print_struct_from_ptr_value(so)
			print_so(so,ctx)
/*
			for i := 0;i < cast(int)buf_len(so.children.buffer);i+=1{
				child_so_id := buf_get(&so.children.buffer,u64(i))
				child := buf_get(&ctx.scene_objects,child_so_id)
				editor_scene_tree_display_recursively(&child,ctx,child_so_id);
			}
*/
			imgui.tree_pop();
		}
	}
}

fmj_editor_scene_tree_show :: proc(tree : ^EditorSceneTree,s : ^gfx.Scene,ctx : ^gfx.AssetContext){
	using container

	imgui.set_next_window_size(imgui.Vec2{520,600},imgui.Cond.FirstUseEver)
	if !imgui.begin("Scene Objects",&tree.is_showing){
		imgui.end()
		return
	}

	if imgui.tree_node("SceneObjects"){
		//Get the first root node
			if buf_len(s.buffer.buffer) > 0{
				so_id := buf_get(&s.buffer.buffer,u64(0))
				so := buf_chk_out(&ctx.scene_objects,so_id);
				editor_scene_tree_display(so,ctx,so_id);
				buf_chk_in(&ctx.scene_objects);	
			}
		
		imgui.tree_pop();
	}
	imgui.end();
}