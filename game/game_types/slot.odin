package game_types
import pkg_entity "../../engine/entity"
import con "../../engine/containers"
import e_math "../../engine/math"
import platform "../../engine/platform"
import gfx "../../engine/graphics"
import linalg "core:math/linalg"
import logger "../../engine/logger"
import rand "core:math/rand"
import imgui "../../engine/external/odin-imgui"
import server "../server"
//import game "../../game"

SlotMachine :: struct{
//Machine visuals
	lines : con.Buffer(SlotLine),
//backend
	grid : SlotGrid,
	midpoint : f32,
}

SlotMachinePayTable :: struct{
	tile_size : e_math.f2,
	table : con.Buffer(bool),
}

//payouts
SymbolPayout :: struct{
	entries : con.Buffer(SymbolPayoutEntry),
}

SymbolPayoutEntry :: struct{
	//count : [3]u32,//0 = 3x, 1 = 4x, 2 = 5x
	amount : [3]u32,//
	texture_id : u64,
}

SlotGridTile :: struct{
	//symbol : SlotSymbol,
	texture_id : u64,
	sprite_id : u64,
	t : pkg_entity.TRS,
	symbol_payout_id : u64,
}

SlotGrid :: struct{
	tile_size : e_math.f2,
	playable_size : e_math.f2,
	tile_grid : con.Buffer(SlotGridTile),
	stride : f32,
	sprite_layer : ^gfx.SpriteLayer,
}

SlotLine :: struct{
	slots : con.Buffer(u64),//index into slotgrid.tile_grid	
	is_spin_complete : bool,
	is_stop_set: bool,
	accum_time : f32,
	speed : f32,
	delay : f32,
	current_bottom_row : int,
}

SlotSprite :: struct{
	sprite_id : u64,
	texture_id : u64,
	layer : ^gfx.SpriteLayer,
}

PayLineEntry :: struct{
	idx : int,
}

PayLineResultEntry :: struct{
	//match_type : SlotSymbol,
	texture_id : u64,
	grid_idx : int,
	symbol_payout_id : int,
}

slot_sprites : con.Buffer(SlotSprite)
payout_cache : con.AnyCache(u64,SymbolPayoutEntry)

//test machine
machine : SlotMachine
paytable : SlotMachinePayTable

random_number_state : rand.Rand
is_spinning := false
is_spin_complete := true
is_show_temp_ui := true
is_results_counted := false

origin_left : f32
origin_top  : f32//wrap around here

origin_top_playable_tile : f32

origin_wrap_bottom : f32
width_of_columns,height_of_rows :f32 = 15.0,15.0

static_grid : SlotGrid

add_money : f32
total_money : f32
auto_spin : bool
wait_before_next_spin : f32
bet : f32
bet_amount : f32
spin_dir : f32 = -1
stop_row_p :f32 = -30.05

playable_grid : []SlotGridTile
accum_time : f32
show_hide_play_grid := false
current_play_grid_rows_tile_ids : [5][5]u64
pay_lines : [dynamic]con.Buffer(PayLineEntry)

@export update :: proc(){
	using platform.ps
	show_temp_ui(&is_show_temp_ui)
	for l,i in &machine.lines.buffer{
		if l.accum_time < l.delay{
			l.accum_time += platform.ps.time.delta_seconds
			l.speed = 800
			animate_slot(i, l.speed * time.delta_seconds)

		}else if l.is_spin_complete == false{
			l.accum_time += platform.ps.time.delta_seconds
			l.speed = 400
			
			is_spinning = false
			finish_count : int
			stride := machine.grid.stride
			zero_offset_y := l.speed * time.delta_seconds
			if l.is_stop_set == true{
				stop_tile_id := con.buf_get(&l.slots,u64(l.current_bottom_row))
				stop_tile := con.buf_ptr(&machine.grid.tile_grid,stop_tile_id)
				stop_tile_y := stop_tile.t.p.y
			}
			if finish_slot_animation(i,zero_offset_y){//l.speed * time.delta_seconds){
				finish_count += 1
			}	

			if finish_count >= 4{
				l.is_spin_complete = true
			}
		}
	}
}

@export init :: proc(){
	using con
	using e_math
	using rand

	random_number_state = create(u64(10))

//slot tiles
	payout_cache = anycache_init(u64,SymbolPayoutEntry,false)
	new_payout_entry : SymbolPayoutEntry
	new_payout_entry.amount[0] = 100
	new_payout_entry.amount[1] = 200
	new_payout_entry.amount[2] = 300
	new_payout_entry.texture_id = gfx.load_texture_from_path_to_default_heap("data/asteroid.png")
	anycache_add(&payout_cache,0,new_payout_entry)
	new_payout_entry.texture_id = gfx.load_texture_from_path_to_default_heap("data/bill.png")
	anycache_add(&payout_cache,1,new_payout_entry)
	new_payout_entry.texture_id = gfx.load_texture_from_path_to_default_heap("data/hen.png")
	anycache_add(&payout_cache,2,new_payout_entry)
	new_payout_entry.texture_id = gfx.load_texture_from_path_to_default_heap("data/watermelon.png")
	anycache_add(&payout_cache,3,new_payout_entry)
	new_payout_entry.texture_id = gfx.load_texture_from_path_to_default_heap("data/ruby.png")
	anycache_add(&payout_cache,4,new_payout_entry)
	new_payout_entry.texture_id = gfx.load_texture_from_path_to_default_heap("data/pear.png")
	anycache_add(&payout_cache,5,new_payout_entry)
	new_payout_entry.texture_id = gfx.load_texture_from_path_to_default_heap("data/apple.png")

//slot background
	tex_id_slot_bars := gfx.load_texture_from_path_to_default_heap("data/slots/table/reel/bars.png")
	tex_id_backgound := gfx.load_texture_from_path_to_default_heap("data/slots/table/reel/bg.png")
	
	bg_layer : ^gfx.SpriteLayer = gfx.create_sprite_layer("",1)
	tiles_layer : ^gfx.SpriteLayer = gfx.create_sprite_layer("",2)
	

	bg_scale : f3 = f3{90,75,1}
	bg_p :  f3 = f3{-6.5,0,0}
	bg_sprite := add_slot_sprite(tex_id_backgound,gfx.add_sprite(bg_layer,bg_p,quat_identity,bg_scale),bg_layer)
	bar_sprite := add_slot_sprite(tex_id_slot_bars,gfx.add_sprite(bg_layer,bg_p,quat_identity,bg_scale),bg_layer)
		

	grid : SlotGrid
	grid.tile_size = f2{15,5}
	grid.playable_size = f2{5,5}
	grid.tile_grid = buf_init(1,SlotGridTile)
	grid.stride = grid.tile_size.y

	symbol_entry_count := u64(grid.tile_size.x * grid.tile_size.y)
	//Get these entries from disk or network

	total_lines := grid.tile_size.y
	machine.lines = buf_init(5,SlotLine)
	for i in 0..total_lines - 1{
		new_line := SlotLine{con.buf_init(u64(grid.tile_size.x),u64),false,false,1000,800,i + 0.2,-1}
		new_line.is_spin_complete = true
		buf_push(&machine.lines,new_line)
	}

	column_padding : f32 = 1.0
	vertical_stride := grid.tile_size.x
	total_width_in_units := (width_of_columns * grid.stride)
	total_height_in_units := (height_of_rows * vertical_stride)
	origin_left = (total_width_in_units / 2.0) - total_width_in_units
	origin_top =  (total_height_in_units / 2.0) - total_height_in_units
	origin_wrap_bottom = abs(origin_top) - total_height_in_units

	start_row := origin_left
	start_column := origin_top

	for row in 0..grid.tile_size.x - 1{
		for column in 0..grid.tile_size.y - 1{
			idx := (row * grid.stride) + column
			tile : SlotGridTile
			rand_symbol_id := u64(rand.float32_range(0,5))
			tile.texture_id = anycache_get_ptr(&payout_cache,rand_symbol_id).texture_id//con.buf_get(&symbol_payouts.entries,rand_symbol_id).symbol
			tile.symbol_payout_id = rand_symbol_id//= buf_get(&symbol_payouts.entries,u64(idx))
			tile.t.r = quat_identity
			tile.t.s = f3{10,10,1}
			tile.t.p.x = start_row
			tile.t.p.y = start_column

			t : pkg_entity.TRS
			t.p = f3{0,0,0}
			t.r = quat_identity
			t.s = f3{10,10,1}

			tile.sprite_id = gfx.add_sprite(tiles_layer,t.p,t.r,t.s,"")


			start_row += f32(width_of_columns + column_padding)
			tile_id := buf_push(&grid.tile_grid,tile)
			//slot line
			line := buf_ptr(&machine.lines,u64(column))
			buf_push(&line.slots,tile_id)
		}
		start_row = origin_left
		start_column += width_of_columns
	}
	machine.grid = grid
	machine.grid.sprite_layer = tiles_layer
	static_grid = grid
	assign_random_symbol_to_grid()
}

get_playable_grid :: proc(){
	using machine
	using con

	tiles : []SlotGridTile = grid.tile_grid.buffer[:]
	max_playable_tile_count := int(grid.playable_size.x * grid.playable_size.y)

	vert_stride := grid.tile_size.x
	stride : int = int(grid.stride)
	

	for row in 0..int(grid.playable_size.x) - 1{
		for line , column in lines.buffer{
			logger.print_log("pgrid ","idx ",(row*stride + column),playable_grid[(row * stride) + column:(row * stride)+ column + 1])
			copy(playable_grid[(row * stride) + column:(row * stride)+ column + 1], tiles[(row * stride) + column:(row * stride)+ column + 1])
			//lower_bound = (lower_bound + 1) % (int(vert_stride))
		}
	}
}

get_symbol_on_payline ::  proc(pay_line_results : ^[dynamic]con.Buffer(PayLineResultEntry)){
	using machine
	using con

	assert(pay_line_results != nil)
	tile_count :int = int(grid.playable_size.x) * int(grid.playable_size.y)
	playable_grid = make([]SlotGridTile,tile_count)

	get_playable_grid()

	pay_lines : [dynamic]con.Buffer(PayLineEntry) = make([dynamic]con.Buffer(PayLineEntry))
	defer{
		for payline,i  in &pay_lines{
			//delete(payline.buffer)
		}
		delete(pay_lines)
	}
	test_payline : con.Buffer(PayLineEntry) = buf_init(1,PayLineEntry)
	defer{
		buf_free(&test_payline)
	}
	/*
	test payline of 
	x x x x x 24 idx
	x x x x x
	O O O O O
	x x x x x
	x x x x x
0 idx	
	*/

	for i in 0..4{
		entry  : PayLineEntry
		entry.idx = (2 * 5) + i
		buf_push(&test_payline,entry)
	}

	append(&pay_lines,test_payline)

	/*
	test payline of 
	x x x x 24 24 idx
	x x x 18 x
	x x 12 x x
	x 6 x x x
	0 x x x x
0 idx	
	*/

	//new_payline := test_payline.buffer[:] 
	new_payline := []PayLineEntry{{0},{6},{12},{18},{24}}
	new_p_b := buf_copy_slice(new_payline)
	append(&pay_lines,new_p_b)

	/*
	test payline of 
	x x x x x 24 idx
	x x x x x
	x x x x x
	x x x x x
	0 1 2 3 4
0 idx	
	*/

	new_payline = test_payline.buffer[:] 
	new_payline = {{0},{1},{2},{3},{4}}
	new_p_b_2 := buf_copy_slice(new_payline)
	append(&pay_lines,new_p_b_2)

	/*
	test payline of 
	x x x x x 24 idx
	x x x x x
	x x x x x
	5 6 7 8 9
	x x x x x
0 idx	
	*/

	new_payline = test_payline.buffer[:] 
	new_payline = {{5},{6},{7},{8},{9}}
	new_p_b_3 := buf_copy_slice(new_payline)
	append(&pay_lines,new_p_b_3)

	for pay_line in &pay_lines{
		payline_entry : con.Buffer(PayLineResultEntry) = buf_init(5,PayLineResultEntry)

		for entry in pay_line.buffer{
			tile := buf_get(&machine.grid.tile_grid,u64(entry.idx))
			result_entry : PayLineResultEntry
			result_entry.grid_idx = entry.idx
			result_entry.texture_id = tile.texture_id
			result_entry.symbol_payout_id = int(tile.symbol_payout_id)
			buf_push(&payline_entry,result_entry)
		}
		append(pay_line_results,payline_entry)
	}
}


animate_slot :: proc(slot_idx : int,offset_y : f32) -> bool{
	using con
	using gfx.asset_ctx
	using e_math
	offset_y_spin := offset_y * spin_dir
	line := buf_ptr(&machine.lines,u64(slot_idx))
	if line.is_spin_complete == false{
		for i := 0;i < int(buf_len(line.slots));i+=1{
			tile_id := buf_get(&line.slots,u64(i))
			tile := buf_ptr(&machine.grid.tile_grid,tile_id)
			next_tile_id := buf_get(&line.slots,u64(safe_modulo(i - 1,int(buf_len(line.slots)))))
			next_tile := buf_ptr(&machine.grid.tile_grid,next_tile_id)
			
			assert(tile != nil)
			assert(next_tile != nil)
			sprite := gfx.get_sprite(machine.grid.sprite_layer,tile.sprite_id)
			
			tile.t.p.y += offset_y_spin
			//check if we will wrap and if so wrap
			if tile.t.p.y < ((origin_top)){
				//wrap to bottom
				tile.t.p.y =  next_tile.t.p.y + height_of_rows
			}
			
			sprite_matrix := con.buf_ptr(&asset_tables.matrix_buffer,sprite.m_id)

			mat := con.buf_get(&asset_tables.matrix_buffer,u64(sprite.proj_id))
			trs_mat := linalg.matrix4_from_trs(tile.t.p,tile.t.r,tile.t.s)
			mul_mat := linalg.matrix_mul(mat,trs_mat)
			sprite_matrix^ = mul_mat
		}
	}
	return false
}

finish_slot_animation :: proc(slot_idx : int,offset_y : f32) -> bool{
	using con
	using gfx.asset_ctx
	using e_math
	offset_y_spin := offset_y * spin_dir
	line := buf_ptr(&machine.lines,u64(slot_idx))

	if line.is_spin_complete == false{
		play_grid_id := 0
		for i := 0;i < int(buf_len(line.slots));i+=1{
			tile_id := buf_get(&line.slots,u64(i))
			tile := buf_ptr(&machine.grid.tile_grid,tile_id)
			next_tile_id := buf_get(&line.slots,u64(safe_modulo(i - 1,int(buf_len(line.slots)))))
			next_tile := buf_ptr(&machine.grid.tile_grid,next_tile_id)
			
			assert(tile != nil)
			assert(next_tile != nil)

			tile.t.p.y += offset_y_spin
			//check if we will wrap and if so wrap
			is_wrapping := false

			if tile.t.p.y < ((origin_top)){
				//wrap to bottom
				tile.t.p.y =  next_tile.t.p.y + height_of_rows
				is_wrapping = true					
			}
			
			sprite := gfx.get_sprite(machine.grid.sprite_layer,tile.sprite_id)
			
			//if tile.t.p.y < 0.1 && tile.t.p.y > -0.1 && i == line.current_stop_row && line.is_stop_set{
			if tile.t.p.y > -31.1 && tile.t.p.y <= -30.0 && i == line.current_bottom_row && line.is_stop_set{
			///if line.is_stop_set{
				//assert(line.current_bottom_row > -1)
				line.is_spin_complete = true
				return true
			}else if line.is_stop_set == false{
				//check if we will wrap and if so wrap
				if is_wrapping{
				//if true{
					bottom_row := 0
					finish_row_index := bottom_row
					stride := int(machine.grid.tile_size.y)
					for j in 0..int(machine.grid.playable_size.x) - 1{
						//tiles with final ids

						final_tile := playable_grid[(j * stride) + slot_idx : (j*stride) + (slot_idx + 1)]
						
						//tiles to replace the final results
						replace_tile_id := buf_get(&line.slots,u64(finish_row_index))
						replace_tile := buf_ptr(&machine.grid.tile_grid,replace_tile_id)
						
						assert(len(final_tile) > 0 && len(final_tile) == 1)
						replace_tile.texture_id = final_tile[0].texture_id//finish_tile.texture_id
						replace_tile.symbol_payout_id = final_tile[0].symbol_payout_id

						current_play_grid_rows_tile_ids[j][slot_idx] = u64((j * stride) + slot_idx)//u64(finish_row_index)

						finish_row_index = (finish_row_index + 1) % int(machine.grid.tile_size.x)
					}
					line.current_bottom_row = bottom_row
					play_grid_id = bottom_row
					
					line.is_stop_set = true
				}
			}
			sprite_matrix := con.buf_ptr(&asset_tables.matrix_buffer,sprite.m_id)

			mat := con.buf_get(&asset_tables.matrix_buffer,u64(sprite.proj_id))
			trs_mat := linalg.matrix4_from_trs(tile.t.p,tile.t.r,tile.t.s)
			mul_mat := linalg.matrix_mul(mat,trs_mat)
			sprite_matrix^ = mul_mat
		}
	}
	return false
}

//first init
assign_random_symbol_to_grid :: proc(){
	using con
	using machine
	using gfx.asset_ctx
	using platform.ps

	for row in 0..grid.tile_size.x - 1{
		for column in 0..machine.grid.tile_size.y - 1{
			idx := (row * grid.stride) + column
			tile := buf_ptr(&grid.tile_grid,u64(idx))
			sprite := gfx.get_sprite(machine.grid.sprite_layer,tile.sprite_id)
			rand_symbol_id := u64(rand.float32_range(0,5))
			tile.texture_id = anycache_get_ptr(&payout_cache,u64(rand_symbol_id)).texture_id
			tile.symbol_payout_id = rand_symbol_id
			sprite.texture_id = tile.texture_id

			//set sprite position on grid
			sprite_matrix := con.buf_ptr(&asset_tables.matrix_buffer,sprite.m_id)
			mat := con.buf_get(&asset_tables.matrix_buffer,u64(sprite.proj_id))
			trs_mat := linalg.matrix4_from_trs(tile.t.p,tile.t.r,tile.t.s)
			mul_mat := linalg.matrix_mul(mat,trs_mat)
			sprite_matrix^ = mul_mat
		}
	}
}

calculate_results :: proc(){
	using machine
	using con
	pay_line_results : [dynamic]con.Buffer(PayLineResultEntry) = make([dynamic]con.Buffer(PayLineResultEntry),0,1)
	defer{
		for entry in &pay_line_results{
			buf_free(&entry)
		}
		delete(pay_line_results)
	}

	get_symbol_on_payline(&pay_line_results)
	
//we will compunt th ewinndings
	total_won : int

	for payline, i in pay_line_results{
		match_count := 0
		matching_symbol : int = -1
		previous_plr : PayLineResultEntry={0,-1,-1}

		for plr, j in payline.buffer{
			//reference an actual symbol table
			//5 500
			//4 400
			//3 300
			if j  == 1 && previous_plr.symbol_payout_id != plr.symbol_payout_id{
				break
			}else if j == 1 && previous_plr.symbol_payout_id == plr.symbol_payout_id{
				matching_symbol = int(previous_plr.symbol_payout_id)
				match_count = 2
			}else if j > 1 && matching_symbol == int(plr.symbol_payout_id) && match_count > 1{
				match_count += 1
			}else if j != 0{
				break
			}
			previous_plr = plr
		}//TODO(Ray):Magic number must go!!
		if match_count >= 3{
			payout_entry := con.anycache_get_ptr(&payout_cache,u64(matching_symbol))
			total_money += f32(payout_entry.amount[match_count - 3])//f32(matching_symbol.payout_entry.amount[match_count - 3])
		}
	}
	
	
}



show_temp_ui :: proc(is_showing : ^bool){
	if !imgui.begin("Slot Temp UI",is_showing){
		imgui.end()
		return
	}
	
	if imgui.button("Toggle Hide Playable Grid"){

		if show_hide_play_grid == false{
			for row in 0..int(machine.grid.playable_size.x) - 1{
				for column in 0..int(machine.grid.playable_size.y) - 1{
					tile := con.buf_get(&machine.grid.tile_grid,u64(current_play_grid_rows_tile_ids[row][column]))
					sprite := gfx.get_sprite(machine.grid.sprite_layer,tile.sprite_id)
					sprite.visible = false
				}
			}	
		}else{
			stride := int(machine.grid.stride)
			for row in 0..int(machine.grid.tile_size.x) - 1{
				for column in 0..int(machine.grid.tile_size.y) - 1{
					tile := con.buf_get(&machine.grid.tile_grid,u64(row * stride + column))
					sprite := gfx.get_sprite(machine.grid.sprite_layer,tile.sprite_id)
					sprite.visible = true
				}
			}
		}

		show_hide_play_grid = ~show_hide_play_grid
	}

	if imgui.button("Start Spin"){
		is_spinning = true
		spin : server.Spin = {0,0,i32(bet_amount)}
		server.send_message(.RELIABLE,spin,size_of(server.Spin))

		//start animation 
		assign_random_symbol_to_grid()

		calculate_results()

		//request results from server

		//after results are complete and returned
		//animate to show results

		for l in &machine.lines.buffer{
			l.accum_time = 0
		}

		is_results_counted = false
		wait_before_next_spin = 0
		is_spin_complete = false

		total_money -= bet_amount

		for i in 0..4{
			line := con.buf_ptr(&machine.lines,u64(i))
			line.is_spin_complete = false
			line.is_stop_set = false
		}
	}
	imgui.input_float("Amount to add : ",&add_money)
	if imgui.button("Add Money"){
		total_money += add_money
	}

	imgui.input_float("Bet Amount : ",&bet)

	if is_spinning == false && is_spin_complete == true{
		if imgui.button("Set Bet"){
			bet_amount = bet
		}
	}

	imgui.text("Bet Amount : %v",bet_amount)
	imgui.text("Total Money: %v",total_money)

	imgui.checkbox("auto spin",&auto_spin)
	
	if auto_spin && is_spinning == false && is_spin_complete == true{
		wait_before_next_spin += platform.ps.time.delta_seconds
		if wait_before_next_spin > 0.5{
			is_spinning = true

			for l in &machine.lines.buffer{
				l.accum_time = 0
			}

			wait_before_next_spin = 0
			is_results_counted = false
			total_money -= bet_amount
			is_spin_complete = false
			assign_random_symbol_to_grid()
			for i in 0..4{
				line := con.buf_ptr(&machine.lines,u64(i))
				line.is_spin_complete = false
			}
		}
	}
	imgui.end()
}



add_slot_sprite :: proc(texture_id : u64,sprite_id :u64,layer : ^gfx.SpriteLayer) -> ^SlotSprite{
	new_slot_sprite : SlotSprite
	new_slot_sprite.texture_id = texture_id
	new_slot_sprite.sprite_id = sprite_id
	new_slot_sprite.layer = layer

	sprite := gfx.get_sprite(layer,sprite_id)
	assert(sprite != nil)
	sprite.texture_id = texture_id

	id := con.buf_push(&slot_sprites,new_slot_sprite)
	return con.buf_ptr(&slot_sprites,id)
}

render_background :: proc(){

}

