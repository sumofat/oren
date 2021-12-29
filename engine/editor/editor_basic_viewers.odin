package editor
import imgui "../external/odin-imgui"
import platform	"../platform"
import gfx "../graphics"
import eng_m "../math"
import la "core:math/linalg"
import math "core:math"
EditorSceneView :: struct{
	main_cam_id : u64,
	scene_cam_id : u64,
	sprite_cam_id : u64,
}

editor_scene_views : EditorSceneView

init_basic_viewers :: proc(){
	using eng_m
	using gfx
		//Main Camera setup
	ot : Transform
	ot.p = f3{};
	ot.r = la.quaternion_angle_axis(cast(f32)la.radians(0.0), f3{0, 0, 1});
	ot.s = f3{1, 1, 1};

	editor_scene_views.main_cam_id = gfx.camera_system_add_camera(ot,gfx.RenderCameraProjectionType.perspective)
	editor_scene_views.scene_cam_id = gfx.camera_system_add_camera(ot,gfx.RenderCameraProjectionType.perspective)
	editor_scene_views.sprite_cam_id = gfx.camera_system_add_camera(ot,gfx.RenderCameraProjectionType.perspective)
}

show_basic_viewers :: proc(){
	using platform
	using gfx
	using editor_scene_views
	show_game_view : bool

		//main editor window
		if imgui.begin("Game View",&show_game_view,imgui.Window_Flags.NoMove){
			if imgui.is_window_hovered(){
				
				//move camera matrix
//					cam_ptr := chk_out_camera(game_cam)					
				//cam_ptr.ot = new_ot
//					chk_in_camera()
			}
			small_size := imgui.get_window_size()
			current_backbuffer_index := GetCurrentBackBufferIndex(swap_chain);    
		    rtv_gpu_handle : D3D12_GPU_DESCRIPTOR_HANDLE = get_camera(main_cam_id).viewport.srv_gpu_handle//get_gpu_handle_srv(device,rtv_descriptor_heap,current_backbuffer_index);
			imgui.image(imgui.Texture_ID(uintptr(rtv_gpu_handle.ptr)),small_size)
		}
		imgui.end()

		if imgui.begin("Scene View",&show_game_view){
			small_size := imgui.get_window_size()
			win_size : imgui.Vec2
			imgui.get_window_content_region_max(&win_size)
		    scene_rt_gpu_id := get_camera(scene_cam_id).viewport.srv_gpu_handle
			imgui.image_button(imgui.Texture_ID(uintptr(scene_rt_gpu_id.ptr)), small_size/*small_size*/)
			//imgui.invisible_button("scene_view",small_size)
			imgui.set_item_allow_overlap()
			imgui.set_cursor_pos(imgui.Vec2{0,0})
			imgui.image(imgui.Texture_ID(uintptr(scene_rt_gpu_id.ptr)),small_size)
			if imgui.is_item_hovered(){
				if imgui.is_mouse_down(imgui.Mouse_Button.Left){
					camera_free(scene_cam_id,ps.input,ps.time.delta_seconds)
				}
				if imgui.is_mouse_released(imgui.Mouse_Button.Left){
					
				}
			}
		}		
		imgui.end()

		if imgui.begin("Sprite View"){
			//camera_free(sprite_cam_id,ps.input,ps.time.delta_seconds)
			if imgui.is_window_hovered(){
			
			}
			small_size := imgui.get_window_size()
		    sprite_rt_gpu_id := get_camera(sprite_cam_id).viewport.srv_gpu_handle
			imgui.image(imgui.Texture_ID(uintptr(sprite_rt_gpu_id.ptr)),small_size)
		}		
		imgui.end()
		
}