package systems

import con "../../engine/containers"
import library "core:dynlib"

Procs :: struct{
}

SubGame :: struct{
	directory : string,
	lib : library.Library,
	init_sym : rawptr,
	update_sym : rawptr,
}

libraries : con.Buffer(SubGame)

init_sub_games :: proc(){
	libraries = con.buf_init(100,SubGame)
}

load_sub_game :: proc(path : string) -> (sg : SubGame,result : bool){
	using library 

	if lib,ok := load_library(path);ok{
		new_sub_game : SubGame
		new_sub_game.lib = lib
		new_sub_game.directory = path
		if sym,ok := get_proc(lib,"init");ok{
			new_sub_game.init_sym = sym
		}

		if sym,ok := get_proc(lib,"update");ok{
			new_sub_game.update_sym = sym
		}
		assert(new_sub_game.init_sym != nil)
		assert(new_sub_game.update_sym != nil)

		con.buf_push(&libraries,new_sub_game)
		return new_sub_game,true
	} 
	return SubGame{},false
}

get_proc :: proc(lib : library.Library,symbol : string)-> (ptr: rawptr, found: bool){
	return library.symbol_address(lib,symbol)	
}



