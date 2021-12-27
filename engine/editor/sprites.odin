package editor
import gfx "../graphics"
import container "../containers"
import imgui "../external/odin-imgui"
import reflect "core:reflect"
import enginemath "../math"
import ref "../reflecthelper"
import mem "core:mem"
import os "core:os"
import path "core:path"
import fmt "core:fmt"


init_sprite_editor :: proc() {

}


show_sprite_editor :: proc(show: bool) {
	using imgui
	using os
	using container
	using fmt
	if !begin("Sprite Editor") {
		end()
		return
	}

	//Show textures in data folder 
	//(eventually we will have a data directory viewer so we can set a structure for assets)//Show textures in data folder 
	//(eventually we will have a data directory viewer so we can set a structure for assets)
	if handle, err := os.open("data"); err == os.ERROR_NONE {
		if file_infos, err := os.read_dir(handle, 100); err == os.ERROR_NONE {
			for file in &file_infos {
				if file.is_dir {
					text(aprintf("DIR: (%s)",file.name))
				} else {
					if path.ext(file.name,false) == ".png"{
							text(file.name)
						tex_path := tprintf("data/%s",file.name)
						//println(tex_path)
						if t,ok := gfx.get_texture_from_file(tex_path);ok{
							full_size := imgui.Vec2{f32(t.dim.x), f32(t.dim.y)}
							small_size := imgui.Vec2{120, 120}
							image(Texture_ID(uintptr(t.gpu_handle.ptr)), small_size)
							//if begin_drag_drop_source(imgui.Drag_Drop_Flags.SourceAllowNullId){
							//	set_drag_drop_payload("_image_id",nil,0)
								image(Texture_ID(uintptr(t.gpu_handle.ptr)), small_size)
								if (is_item_active() && !is_item_hovered()){
									mp : Vec2
									get_mouse_pos(&mp)
								printf("ITEM DROPPED MP is : %v",mp)

								}
							//	end_drag_drop_source()
							//}
						}
					}
				}
			}
		}
	}
/*
	//pick by drag  and drop or select and than click to  place\
	if is_mouse_released(imgui.Mouse_Button.Left){
		printf("Payload %v",payload)
		if payload != nil{
			mp : Vec2
			get_mouse_pos(&mp)
			printf("ITEM DROPPED MP is : %v",mp)
		}
	}
	*/
	//if is_mouse_released(imgui.Mouse_Button.Left){
	//}
	//insert this into the scene

	//allow selectable tree view in scene view so we can insert into the scene

	//allow selectable tree object to be a prefab saved in data folder.//pick by drag  and drop or select and than click to  place

	//insert this into the scene

	//allow selectable tree view in scene view so we can insert into the scene

	//allow selectable tree object to be a prefab saved in data folder.

	end()

}
