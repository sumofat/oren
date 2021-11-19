package game
//Bootloads the games or parts of the game
//inits basic shared engine systems.
	//login and check server for current games

	//get and dipslay User info UI
	
	//get and Display available games from network
	
	//download if changes
	
	//show on UI available games

import e_math "../engine/math"
import math "core:math"
import linalg "core:math/linalg"
import logger "../engine/logger"
import  gfx "../engine/graphics"
import enet "vendor:enet"
import server "server"
import systems "systems"
import imgui  "../engine/external/odin-imgui";

is_init : bool = false

sub_game : systems.SubGame

@export init :: proc(){
	using e_math
	using math
	using logger
	using gfx
	using enet
	using server
	
	network_init()

	connect("localhost",3000)
	systems.init_sub_games()


	if sub_game,ok := systems.load_sub_game("game/game_types/slot.dll");ok{
		(proc())(sub_game.init_sym)()
	}else{
		//fail
		assert(true)
	}



	//init_basic_machine()

	is_init = true
}

libs_is_showing : bool = true

@export  update :: proc(dt : f32){
	using systems

	
	if !imgui.begin("Loaded Libs",&libs_is_showing){
			imgui.end()
			return
	}
	//show all subgames in imgui in debugging.
	for lib in systems.libraries.buffer{
		imgui.text(lib.directory)	
	}
	imgui.end();
	//create a disk based descriptiono of the game
	//load description, dll and images get dir to assets
	//render game where appropiate in UI


	//update_machine()
	(proc())(sub_game.update_sym)()
}

/*
	init_asteroids()
	new_layer := create_sprite_layer("data/asteroid.png",1)

	deg : f32 = 0.0
	ref_vector : f3 = f3{1,0,0} * 5
	for i in 0..36{
		radian : f32 = linalg.radians(deg)
		
		print_log("radian: ",radian)
		velocity := linalg.mul(linalg.quaternion_angle_axis(radian,f3{0,0,1}),ref_vector)
		print_log("velocity: ",velocity)
		add_asteroid(nil,f3{0,0,0},quat_identity,f3{10,10,1},velocity)

		layer_radian := linalg.radians(deg + 5)
		layer_velocity := linalg.mul(linalg.quaternion_angle_axis(layer_radian,f3{0,0,1}),ref_vector)
		
		add_asteroid(new_layer,f3{0,0,0},quat_identity,f3{10,10,1},layer_velocity * 0.5)
		deg += 10
	}
	*/
