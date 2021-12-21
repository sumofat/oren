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
import game_types "game_types"
import con "../engine/containers"

import buf_slot "games/buffalo_slot"

is_init : bool = false

sub_game : systems.SubGame

SubGameProc :: struct{
	name : string,
	//type : typeid,
	init_func : proc(),
	update_func : proc(),
}

game_procs : con.Buffer(SubGameProc)

current_game_proc : SubGameProc
libs_is_showing : bool = true

init :: proc(){
	using e_math
	using math
	using logger
	using gfx
	using enet
	using server
	network_init()

	connect("localhost",3000)
	game_procs = con.buf_init(1,SubGameProc)
	
	new_sg_proc : SubGameProc = {"buf_slot",buf_slot.init,buf_slot.update}

	con.buf_push(&game_procs,new_sg_proc)

	//send network request to get user info

	//and currently active games
	if !imgui.begin("Playable Games",&libs_is_showing){
			imgui.end()
			return
	}

	//show user games to select and ui
	for game_proc in game_procs.buffer{
		imgui.text(game_proc.name)
		if game_proc.name == "buf_slot"{
			current_game_proc = game_proc
		}
	}
	imgui.end();
	
	assert(current_game_proc.init_func != nil)

	current_game_proc.init_func()
	//update_proc = game_types.update
	//init_basic_machine()

	is_init = true
}


update :: proc(dt : f32){
	using systems
	//and currently active games
	libs_is_showing = true
	if !imgui.begin("Playable Games",&libs_is_showing){
			imgui.end()
			return
	}

	//show user games to select and ui
	for game_proc in game_procs.buffer{
		imgui.text(game_proc.name)

		if game_proc.name == "buf_slot"{
			current_game_proc = game_proc
		}
	}
	imgui.end();
	/*
	if !imgui.begin("Playable Games",&libs_is_showing){
			imgui.end()
			return
	}


	imgui.end();
*/
	//create a disk based descriptiono of the game
	//load description, dll and images get dir to assets
	//render game where appropiate in UI
	current_game_proc.update_func()

	//update_machine()
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
