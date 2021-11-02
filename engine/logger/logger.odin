package logger
import fmt "core:fmt"

logs : [dynamic]string
is_init : bool = false

init_log :: proc(){
	is_init = true
	logs = make([dynamic]string,0,1000)
}

print_log :: proc(log : ..any){
	if len(logs) >= 999{
		clear(&logs)
	}
	fmted_log := fmt.aprint(log)
	append(&logs,fmted_log)
}

