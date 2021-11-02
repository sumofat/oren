package game
import game_types "game_types"
/*
//TODO(Ray):We dont really want to have this in the game but we need access to platformstate
package platform "engine/platform"
*/
is_init : bool = false
init :: proc(){
	using game_types
	init_asteroids()
	add_asteroid()
	is_init = true
}

update :: proc(dt : f32){
	using game_types
	if is_init == false{
		init()
	}
}

