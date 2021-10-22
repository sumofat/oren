package editor
import gfx "../graphics"
import container "../containers"
import imgui  "../external/odin-imgui"
import reflect "core:reflect"
import enginemath "../math"
import ref "../reflecthelper"
//node_id : u64
//import la "core:math/linalg"

EditorSceneTree :: struct{
	root : ^gfx.SceneObject,
	is_showing : bool,
}

editor_scene_tree_init :: proc(tree : ^EditorSceneTree){

}

editor_scene_tree_display_recursively :: proc(so : ^gfx.SceneObject,ctx : ^gfx.AssetContext,id : u64){
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
			ref_result := get_elements(so);
			//id := typeid_of(type_of(so^))
			//types := reflect.struct_field_types(id)
			//names := reflect.struct_field_names(id)
			for type, i in ref_result.types{
				if named_type,ok := type.variant.(Type_Info_Named); ok{
					//struct_type,ok := type.variant.(Type_Info_Struct)
					imgui.text(ref_result.names[i])
					//if struct_type,oks := named_type.base.(Type_Info_Struct); oks{
					if reflect.is_struct(named_type.base){
						if type.id == typeid_of(Transform){
								imgui.text("Transform")
							//sid := typeid_of(type_of(so.children))
							info_struct := named_type.base.variant.(Type_Info_Struct)//struct_type.names
							subnames := info_struct.names;
							subtypes := info_struct.types;
							for type, s in subtypes{
								if type.id == typeid_of(f3) && subnames[s] == "p"{
									valueofp := struct_field_value_by_name(so.transform, "p")
									//if type_of(type) == f3{
										//imgui.text(subnames[s])
										//imgui.input_float3("Vec3",so.transform.p.xyz)
									
									//testvalue := valueofp.(la.Vector3f32)
									imgui.input_float3("f3",cast([3]f32)valueofp.(f3))
									//}
								//}
								}
								
								//imgui.text(named_type.names[s])
							}
						}
					}
				}
			}

			//imgui.input_float3("position",so.transform.p.xyz);
			for i := 0;i < cast(int)buf_len(so.children.buffer);i+=1{
				child_so_id := buf_get(&so.children.buffer,u64(i))
				child := buf_get(&ctx.scene_objects,child_so_id)
				editor_scene_tree_display_recursively(&child,ctx,child_so_id);
			}
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
		imgui.text("STart OF TREE")
		for i := 0;i < cast(int)buf_len(s.buffer.buffer);i+=1{
			so_id := buf_get(&s.buffer.buffer,u64(i))
			so := buf_chk_out(&ctx.scene_objects,so_id);
			editor_scene_tree_display_recursively(so,ctx,so_id);
			buf_chk_in(&ctx.scene_objects);
		}
		imgui.tree_pop();
	}
	imgui.end();
}