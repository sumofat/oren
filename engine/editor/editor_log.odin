package editor
import imgui  "../external/odin-imgui"
import logger "../logger"

//line_offsets : [dynamic]int
buf : imgui.Text_Buffer
max_logs :: 10000

show_log :: proc(open : ^bool){
	using imgui
	imgui.set_next_window_size(imgui.Vec2{500,300},imgui.Cond.FirstUseEver)
	imgui.begin("Log",open)
	imgui.begin_child("scrolling",Vec2{0,0},false,imgui.Window_Flags.HorizontalScrollbar)

	//clipper : imgui.List_Clipper
	//list_clipper_begin(&clipper,i32(len(line_offsets)))
	//for list_clipper_step(&clipper){
	//	for line_no := clipper.display_start;line_no < clipper.display_end;line_no += 1{
		for log in logger.logs{
			imgui.text_unformatted(log)
		}
	//}
	imgui.end_child()
	imgui.end()

	if len(logger.logs) > max_logs{
		clear(&logger.logs)
	}
}
