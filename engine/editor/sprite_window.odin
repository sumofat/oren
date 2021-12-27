package editor
import imgui "../external/odin-imgui"
import fmt "core:fmt"
import oren "../../oren"
import con "../containers"
import gfx "../graphics"

show_sprite_debug :: proc(show : bool){
	using imgui
	using fmt
	using con
	
	if !begin("Sprite Debug"){
		end()
		return
	}
	for sb in gfx.sprite_buffers{
		text(aprintf("sprite buffer length : %d",buf_len(sb)))
	}

	end()
}
