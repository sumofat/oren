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
	count : u32,
	amount : u32,
	symbol : SlotSymbol,
}

SlotGridTile :: struct{
	symbol : SlotSymbol,
	t : pkg_entity.TRS,
	is_top_row : bool,
}

SlotGrid :: struct{
	tile_size : e_math.f2,
	playable_size : e_math.f2,
	tile_grid : con.Buffer(SlotGridTile),
	stride : f32,
	sprite_layer : ^gfx.SpriteLayer,
}

SlotSymbol :: struct{
	sprite_id : u64,
	layer_id : u64,
}

SlotLine :: struct{
	slots : con.Buffer(u64),//index into slotgrid.tile_grid	
	is_spin_complete : bool,
}

SlotSprite :: struct{
	sprite_id : u64,
	texture_id : u64,
	layer : ^gfx.SpriteLayer,
}

slot_sprites : con.Buffer(SlotSprite)

//test machine
machine : SlotMachine
paytable : SlotMachinePayTable

symbol_payouts : SymbolPayout


texture_ids : [dynamic]u64

random_number_state : rand.Rand
accum_time : f32 = 1000
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
current_stop_row : int

safe_modulo :: proc(x : int , n : int)-> int{
	return (x % n + n) % n
}

check_result :: proc(){
	using con
	using machine
	using gfx.asset_ctx
	using logger

	max_size := int(machine.grid.tile_size.x - 1)

	lower_bound := safe_modulo(current_stop_row - 2,max_size) + 1
	upper_bound := (current_stop_row + 2) % int(max_size)
	results : [5]f32
	for row in 0..4{
		prev_column_sprite : ^gfx.Sprite
		same_row_count : u32 = 1
		matching_type : u64
		for column in 0..int(machine.grid.tile_size.y) - 1{
			idx := (lower_bound * int(grid.stride)) + column
			tile := buf_ptr(&grid.tile_grid,u64(idx))
			sprite := gfx.get_sprite(machine.grid.sprite_layer,tile.symbol.sprite_id)
			if column == 0{
				matching_type = sprite.texture_id
			}else if matching_type == sprite.texture_id && column > 0{
				
				//print_log("match found on row: ",row," column : ",column," sprite ID : ",sprite.texture_id," prev Id ",prev_column_sprite.texture_id)
				same_row_count += 1
				sprite.visible = false
				if prev_column_sprite != nil{
					prev_column_sprite.visible = false
				}

			}else if column > 0{

				break
			}
			prev_column_sprite = sprite
		}
		if same_row_count >= 2{
			results[row] = bet_amount * f32(same_row_count)
		}
		lower_bound = (lower_bound + 1) % int(machine.grid.tile_size.x)

//		print_log("found matches : ",same_row_count)

	}

	if is_results_counted == false{
		highest_result : f32
		is_results_counted = true
		for result in results{
			if result > highest_result{
				highest_result = result
			}
		}
		total_money += highest_result
		print_log("highest result awarded :",highest_result)
	}
	
}

animate_slot :: proc(slot_idx : int,offset_y : f32,stop_at_zero : bool = false,stop_row : int = -1) -> bool{
	using con
	using gfx.asset_ctx

	line := buf_ptr(&machine.lines,u64(slot_idx))
	if line.is_spin_complete == false{
		for i := 0;i < int(buf_len(line.slots));i+=1{
			tile_id := buf_get(&line.slots,u64(i))
			tile := buf_ptr(&machine.grid.tile_grid,tile_id)
			next_tile_id := buf_get(&line.slots,u64((i + 1) % int(buf_len(line.slots))))
			next_tile := buf_ptr(&machine.grid.tile_grid,next_tile_id)
			assert(tile != nil)
			assert(next_tile != nil)
			sprite := gfx.get_sprite(machine.grid.sprite_layer,tile.symbol.sprite_id)
			sprite.visible = true
			if stop_at_zero && tile.t.p.y < 1 && tile.t.p.y > -1 && i == stop_row{
				assert(stop_row > -1)
				line.is_spin_complete = true
				return true
			}else{
				tile.t.p.y += offset_y
				//check if we will wrap and if so wrap
				if tile.t.p.y > (abs(origin_top)){
					//wrap to bottom
					tile.t.p.y =  next_tile.t.p.y - height_of_rows
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
		sprite := gfx.get_sprite(machine.grid.sprite_layer,tile.symbol.sprite_id)
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

pick_random_row_for_slot :: proc(slot_idx : int)-> int{
	return int(rand.float32_range(0,machine.grid.tile_size.x))
}

//first init
assign_random_sprite_to_grid :: proc(){
	using con
	using machine
	using gfx.asset_ctx
	using platform.ps

	for row in 0..grid.tile_size.x - 1{
		for column in 0..machine.grid.tile_size.y - 1{
			idx := (row * grid.stride) + column
			tile := buf_ptr(&grid.tile_grid,u64(idx))
			sprite := gfx.get_sprite(machine.grid.sprite_layer,tile.symbol.sprite_id)
			tex_id := u64(rand.float32_range(0,6))
			sprite.texture_id = texture_ids[tex_id]

			//set sprite position on grid
			sprite_matrix := con.buf_ptr(&asset_tables.matrix_buffer,sprite.m_id)
			mat := con.buf_get(&asset_tables.matrix_buffer,u64(sprite.proj_id))
			trs_mat := linalg.matrix4_from_trs(tile.t.p,tile.t.r,tile.t.s)
			mul_mat := linalg.matrix_mul(mat,trs_mat)
			sprite_matrix^ = mul_mat
		}
	}
}

show_temp_ui :: proc(is_showing : ^bool){
	if !imgui.begin("Slot Temp UI",is_showing){
		imgui.end()
		return
	}

	if imgui.button("Start Spin"){
		is_spinning = true
		accum_time = 0
		is_results_counted = false
		wait_before_next_spin = 0
		is_spin_complete = false
		current_stop_row := pick_random_row_for_slot(0)
		total_money -= bet_amount
		assign_random_sprite_to_grid()
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
			accum_time = 0
			wait_before_next_spin = 0
			is_results_counted = false
			total_money -= bet_amount
			is_spin_complete = false
			assign_random_sprite_to_grid()
			for i in 0..4{
				line := con.buf_ptr(&machine.lines,u64(i))
				line.is_spin_complete = false
			}
		}
	}
	imgui.end()
}


update_machine :: proc(){
	using platform.ps
	show_temp_ui(&is_show_temp_ui)
	if accum_time < 1{
		accum_time += platform.ps.time.delta_seconds
		for i in 0..4{
			animate_slot(i, 100 * time.delta_seconds)
		}
	}else{
		is_spinning = false
		finish_count : int
		for i in 0..4{
			if animate_slot(i,80 * time.delta_seconds,true,current_stop_row){
				finish_count += 1
			}
		}
		if finish_count >= 4{
			is_spin_complete = true
		}
	}

	if is_spinning == false && is_spin_complete{
		check_result()	
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

//slot tiles
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/asteroid.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/bill.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/hen.png"))
	
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/watermelon.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/ruby.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/pear.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/apple.png"))

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
	symbol_payouts.entries = buf_init(symbol_entry_count,SymbolPayoutEntry)
	for i in 0..symbol_entry_count - 1{
		entry : SymbolPayoutEntry
		entry.amount = u32(100 * (i + 1))
		entry.count = u32(1 * (i + 1))

		entry.symbol.layer_id = 0//default for now

		t : pkg_entity.TRS
		t.p = f3{0,0,0}
		t.r = quat_identity
		t.s = f3{10,10,1}

		entry.symbol.sprite_id = gfx.add_sprite(tiles_layer,t.p,t.r,t.s,"")

		buf_push(&symbol_payouts.entries,entry)
	}

	total_lines := grid.tile_size.y
	machine.lines = buf_init(5,SlotLine)
	for i in 0..total_lines - 1{
		new_line := SlotLine{con.buf_init(u64(grid.tile_size.x),u64),false}
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
			tile.symbol = buf_get(&symbol_payouts.entries,u64(idx)).symbol
			tile.t.r = quat_identity
			tile.t.s = f3{10,10,1}
			tile.t.p.x = start_row
			tile.t.p.y = start_column
			if row == 5{
				tile.is_top_row = true
			}
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
	assign_random_sprite_to_grid()
}

/*
animate_test :: proc(){
	using gfx.asset_ctx
	using platform.ps
	using con
	using logger

	//move slots down
	for i := 0;i < int(buf_len(machine.lines));i+=1{
		line := buf_ptr(&machine.lines,u64(i))
		//TODO(Ray):File a bug report on not being able to for loop over a dynamic array here
		//compiler failed silently for some reason switched to indexing
		for j := 0;j < int(buf_len(line.slots));j+=1{
			tile_id := buf_get(&line.slots,u64(j))
			next_tile_id := buf_get(&line.slots,u64((j + 1) % int(buf_len(line.slots))))
			tile := buf_ptr(&machine.grid.tile_grid,tile_id)
			next_tile := buf_ptr(&machine.grid.tile_grid,next_tile_id)

			assert(tile != nil)
			assert(next_tile != nil)

			sprite := gfx.get_sprite(nil,tile.symbol.sprite_id)

			if is_spinning{
				tile.t.p.y += 100 * time.delta_seconds
				if i == 0 && (j == 0 || j == 14){
					print_log("tile id : ",tile.symbol.sprite_id)
					print_log("this tile y : %v : origin_top : %v : next tile y : %v",tile.t.p.y,abs(origin_top),next_tile.t.p.y)

				}

				if tile.t.p.y > (abs(origin_top)){
					//wrap to bottom
					tile.t.p.y =  next_tile.t.p.y - height_of_rows
				}
			}else if is_spin_complete == false{
				
				//tile.t.p.y += 100 * time.delta_seconds
				next_y := tile.t.p.y + 100 * time.delta_seconds

				//animate to target
				/*
				if tile.t.p.y > (abs(origin_top)){
					//wrap to bottom
					tile.t.p.y =  next_tile.t.p.y - height_of_rows
				}*/

				if next_y/*tile.t.p.y*/ > (abs(origin_top)){
					tile.t.p.y = abs(origin_top)
					
					if i >= int(machine.grid.tile_size.y) - 1{//if this is the last column
						is_spin_complete = true
					}
				}else{
					tile.t.p.y = next_y
				}
			}

			//set sprite position
			sprite_matrix := con.buf_ptr(&asset_tables.matrix_buffer,sprite.m_id)

			mat := con.buf_get(&asset_tables.matrix_buffer,u64(sprite.proj_id))
			trs_mat := linalg.matrix4_from_trs(tile.t.p,tile.t.r,tile.t.s)
			mul_mat := linalg.matrix_mul(mat,trs_mat)
			sprite_matrix^ = mul_mat
		}
	}

	//when they wrap assign random sprite to that gridslot

}
*/