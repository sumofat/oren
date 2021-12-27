package editor
import imgui "../external/odin-imgui"
import fmt "core:fmt"
import oren "../../oren"
import con "../containers"
import pkg_entity "../entity"
open : bool

show_entity_debug :: proc(show_window : bool){
		using imgui
		using fmt
		using con
		using pkg_entity
		open : bool = true
		if !begin("ECS Debug"){
				end()
				return
		}
		
		//ImGui::CollapsingHeader("CollapsingHeader", &open);
		if collapsing_header("Archetypes",&open){
			for bucket,i in entity_buckets.anythings.buffer{
				text(aprintf("%d",i))
				for comp in bucket.components.buffer{
					text(aprintf("type : %v",comp.t))
				}
				text(aprintf("entity_count : %d",buf_len(bucket.entities)))
			}
		}
		

		if collapsing_header("TRS Info",&open){
			text(aprintf("TRS count : %d",buf_len(trs.anythings)))

			for t in trs.anythings.buffer{
				//text(aprintf())
			}
		}
		
		
		end()
}