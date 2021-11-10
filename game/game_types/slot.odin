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
	symbol : SlotSymbol,
}

SlotGridTile :: struct{
	symbol : SlotSymbol,
	sprite_id : u64,
	t : pkg_entity.TRS,
}

SlotGrid :: struct{
	tile_size : e_math.f2,
	playable_size : e_math.f2,
	tile_grid : con.Buffer(SlotGridTile),
	stride : f32,
	sprite_layer : ^gfx.SpriteLayer,
}

SlotSymbol :: struct{
	texture_id : u64,
	payout_entry : ^SymbolPayoutEntry,
}

SlotLine :: struct{
	slots : con.Buffer(u64),//index into slotgrid.tile_grid	
	is_spin_complete : bool,
	accum_time : f32,
	speed : f32,
	delay : f32,
	current_stop_row : int,
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
	match_type : SlotSymbol,
	grid_idx : int,
}

slot_sprites : con.Buffer(SlotSprite)

//test machine
machine : SlotMachine
paytable : SlotMachinePayTable

symbol_payouts : SymbolPayout

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

safe_modulo :: proc(x : int , n : int)-> int{
	return (x % n + n) % n
}
/*
Stop on time or on press after time stop on next tile closest to y zero
use distance to calculate the result grid 
*/

get_playable_grid :: proc(result_grid_in : ^[]SlotGridTile){
	using machine
	using con

	assert(result_grid_in != nil)

	tiles : []SlotGridTile = grid.tile_grid.buffer[:]
	max_playable_tile_count := int(grid.playable_size.x * grid.playable_size.y)
	result_grid : []SlotGridTile = result_grid_in^

	vert_stride := grid.tile_size.x
	stride : int = int(grid.stride)

	for l, column in lines.buffer{
		//TODO(Ray): magic number 2 to be replaced based on playable grid size
		lower_bound := safe_modulo(l.current_stop_row - 2,int(vert_stride))
		for row in 0..int(grid.playable_size.x) - 1{
			idx := (lower_bound * stride) + column
			copy(result_grid[row * stride:][:column], tiles[lower_bound * stride:][ : column])
			lower_bound = (lower_bound + 1) % (int(vert_stride))
		}
	}
	result_grid_in^ = result_grid
}


check_payline ::  proc(pay_line_results : ^[dynamic]PayLineResultEntry){
	using machine
	using con

	assert(pay_line_results != nil)
	tile_count :int = int(grid.playable_size.x) * int(grid.playable_size.y)
	playable_grid := make([]SlotGridTile,tile_count)
	defer{
		delete(playable_grid)
	}
	get_playable_grid(&playable_grid)


	pay_lines : [dynamic]con.Buffer(PayLineEntry) = make([dynamic]con.Buffer(PayLineEntry))

	test_payline : con.Buffer(PayLineEntry) = buf_init(1,PayLineEntry)
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
	for pay_line in &pay_lines{
		for entry in pay_line.buffer{
			tile := playable_grid[entry.idx]
			result_entry : PayLineResultEntry
			result_entry.grid_idx = entry.idx
			//TODO(Ray):change this to lookup into thte symbol table when we are 
			result_entry.match_type = tile.symbol
			append(pay_line_results,result_entry)
		}
	}

		//for each payline match in line
			//if no match in slot0 continue to next payline
			//else store matchint tile in payline result
			//at the end take all payline results and based on
			//if we are stacking results or taking the higest one
			//return value won	
}


spin_dir : f32 = -1

animate_slot :: proc(slot_idx : int,offset_y : f32,stop_at_zero : bool = false,stop_row : int = -1) -> bool{
	using con
	using gfx.asset_ctx
	offset_y_spin := offset_y * spin_dir
	line := buf_ptr(&machine.lines,u64(slot_idx))
	if line.is_spin_complete == false{
		for i := 0;i < int(buf_len(line.slots));i+=1{
			tile_id := buf_get(&line.slots,u64(i))
			tile := buf_ptr(&machine.grid.tile_grid,tile_id)
			//spin up
			//next_tile_id := buf_get(&line.slots,u64((i + 1) % int(buf_len(line.slots))))
			//next_tile := buf_ptr(&machine.grid.tile_grid,next_tile_id)
			//spin down
			//u64((i + 1) % int(buf_len(line.slots)))
			next_tile_id := buf_get(&line.slots,u64(safe_modulo(i - 1,int(buf_len(line.slots)))))
			next_tile := buf_ptr(&machine.grid.tile_grid,next_tile_id)
			
			assert(tile != nil)
			assert(next_tile != nil)
			sprite := gfx.get_sprite(machine.grid.sprite_layer,tile.sprite_id)
			sprite.visible = true
			if stop_at_zero && tile.t.p.y < 1 && tile.t.p.y > -1 && i == stop_row{
				assert(stop_row > -1)
				line.is_spin_complete = true
				return true
			}else{
				tile.t.p.y += offset_y_spin
				//check if we will wrap and if so wrap
				if tile.t.p.y < ((origin_top)){
					//wrap to bottom
					tile.t.p.y =  next_tile.t.p.y + height_of_rows
				}
			}
			
			//set sprite position
//			gfx.set_sprite_trs(machine.grid.sprite_layer,tile.symbol.sprite_id,tile.t.p,tile.t.r,tile.t.s)
			sprite_matrix := con.buf_ptr(&asset_tables.matrix_buffer,sprite.m_id)

			mat := con.buf_get(&asset_tables.matrix_buffer,u64(sprite.proj_id))
			trs_mat := linalg.matrix4_from_trs(tile.t.p,tile.t.r,tile.t.s)
			mul_mat := linalg.matrix_mul(mat,trs_mat)
			sprite_matrix^ = mul_mat
		}
	}
	return false
}

animate_slot_row_to_p :: proc(slot_idx : int,position_y : f32,row : int) -> bool{
	using con
	using gfx.asset_ctx

	line := buf_ptr(&machine.lines,u64(slot_idx))
	for i := 0;i < int(buf_len(line.slots));i+=1{
		tile_id := buf_get(&line.slots,u64(i))
		tile := buf_ptr(&machine.grid.tile_grid,tile_id)
		next_tile_id := buf_get(&line.slots,u64((i + 1) % int(buf_len(line.slots))))
		next_tile := buf_ptr(&machine.grid.tile_grid,next_tile_id)
		
		offset_y := tile.t.p.y - position_y
		assert(tile != nil)
		sprite := gfx.get_sprite(machine.grid.sprite_layer,tile.sprite_id)
		tile.t.p.y += offset_y
		//check if we will wrap and if so wrap
		if tile.t.p.y > (abs(origin_top)){
			//wrap to bottom
			tile.t.p.y =  next_tile.t.p.y - height_of_rows
		}

		//set sprite position
		sprite_matrix := con.buf_ptr(&asset_tables.matrix_buffer,sprite.m_id)

		mat := con.buf_get(&asset_tables.matrix_buffer,u64(sprite.proj_id))
		trs_mat := linalg.matrix4_from_trs(tile.t.p,tile.t.r,tile.t.s)
		mul_mat := linalg.matrix_mul(mat,trs_mat)
		sprite_matrix^ = mul_mat
	}
	return false
}

pick_random_row :: proc()-> int{
	return int(rand.float32_range(0,machine.grid.tile_size.x))
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
			rand_symbol_id := u64(rand.float32_range(0,6))
			tile.symbol = buf_get(&symbol_payouts.entries,rand_symbol_id).symbol
			sprite.texture_id = tile.symbol.texture_id

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
	for l in &lines.buffer{
		l.current_stop_row = pick_random_row()
	}

	pay_line_results : [dynamic]PayLineResultEntry = make([dynamic]PayLineResultEntry,0,1)
	defer{
		delete(pay_line_results)
	}

	check_payline(&pay_line_results)

	for plr in pay_line_results{
		//reference an actual symbol table
		//5 500
		//4 400
		//3 300

		//plr.match_type 
	}
}

show_temp_ui :: proc(is_showing : ^bool){
	if !imgui.begin("Slot Temp UI",is_showing){
		imgui.end()
		return
	}

	if imgui.button("Start Spin"){
		is_spinning = true
		
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

accum_time : f32
update_machine :: proc(){
	using platform.ps
	show_temp_ui(&is_show_temp_ui)
	for l,i in &machine.lines.buffer{
		if l.accum_time < l.delay{
			l.accum_time += platform.ps.time.delta_seconds
			l.speed = 800
			animate_slot(i, l.speed * time.delta_seconds)

		}else{
			l.accum_time += platform.ps.time.delta_seconds
			l.speed = 80
			
			is_spinning = false
			finish_count : int
			stride := machine.grid.stride

			if animate_slot(i,l.speed * time.delta_seconds,true,l.current_stop_row){
				finish_count += 1
			}	

			if finish_count >= 4{
				is_spin_complete = true
			}
		}
	}

	if is_spinning == false && is_spin_complete{
	}
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

init_basic_machine :: proc(){
	using con
	using e_math
	using rand

	random_number_state = create(u64(10))

	symbol_payouts.entries = buf_init(1,SymbolPayoutEntry)

//slot tiles
	new_payout_entry : SymbolPayoutEntry
	new_payout_entry.amount[0] = 100
	new_payout_entry.amount[1] = 200
	new_payout_entry.amount[2] = 300
	new_payout_entry.symbol.texture_id = gfx.load_texture_from_path_to_default_heap("data/asteroid.png")
	buf_push(&symbol_payouts.entries,new_payout_entry)
	new_payout_entry.symbol.texture_id = gfx.load_texture_from_path_to_default_heap("data/bill.png")
	
	buf_push(&symbol_payouts.entries,new_payout_entry)
	
	new_payout_entry.symbol.texture_id = gfx.load_texture_from_path_to_default_heap("data/hen.png")
	buf_push(&symbol_payouts.entries,new_payout_entry)
	
	new_payout_entry.symbol.texture_id = gfx.load_texture_from_path_to_default_heap("data/watermelon.png")
	buf_push(&symbol_payouts.entries,new_payout_entry)
	
	new_payout_entry.symbol.texture_id = gfx.load_texture_from_path_to_default_heap("data/ruby.png")
	buf_push(&symbol_payouts.entries,new_payout_entry)
	
	new_payout_entry.symbol.texture_id = gfx.load_texture_from_path_to_default_heap("data/pear.png")
	buf_push(&symbol_payouts.entries,new_payout_entry)
	
	new_payout_entry.symbol.texture_id = gfx.load_texture_from_path_to_default_heap("data/apple.png")
	buf_push(&symbol_payouts.entries,new_payout_entry)

	
/*
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/bill.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/hen.png"))
	
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/watermelon.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/ruby.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/pear.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/apple.png"))
*/

//slot background
	//slot_sprites = buf_init(2,SlotSprite)
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
		new_line := SlotLine{con.buf_init(u64(grid.tile_size.x),u64),false,1000,800,i + 0.2,-1}
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
			rand_symbol_id := u64(rand.float32_range(0,6))
			tile.symbol = con.buf_get(&symbol_payouts.entries,rand_symbol_id).symbol//buf_get(&symbol_payouts.entries,u64(idx)).symbol
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
