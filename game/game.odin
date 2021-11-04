package game
import game_types "game_types"
import e_math "../engine/math"
import math "core:math"
import linalg "core:math/linalg"
import logger "../engine/logger"
/*
//TODO(Ray):We dont really want to have this in the game but we need access to platformstate
package platform "engine/platform"
*/
is_init : bool = false
init :: proc(){
	using game_types
	using e_math
	using math
	using logger
	init_asteroids()
	deg : f32 = 0.0
	ref_vector : f3 = f3{1,0,0} * 5
	for i in 0..300{
		radian : f32 = linalg.radians(deg)
		
		print_log("radian: ",radian)
		velocity := linalg.mul(linalg.quaternion_angle_axis(radian,f3{0,0,1}),ref_vector)
		print_log("velocity: ",velocity)
		add_asteroid(f3{0,0,0},quat_identity,f3{10,10,1},velocity)
		deg += 1
	}
	is_init = true
}

update :: proc(dt : f32){
	using game_types
}

