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
}

SlotGrid :: struct{
	tile_size : e_math.f2,
	tile_grid : con.Buffer(SlotGridTile),
}

SlotSymbol :: struct{
	sprite_id : u64,
	layer_id : u64,
}

SlotLine :: struct{
	slots : con.Buffer(SlotSymbol),	
}

//test machine
machine : SlotMachine
paytable : SlotMachinePayTable

symbol_payouts : SymbolPayout

texture_ids : [dynamic]u64

random_number_state : rand.Rand
accum_time : f32
is_spinning := true
is_show_temp_ui := true
is_results_counted := false

check_result :: proc(){
	using con
	using machine
	using gfx.asset_ctx

	stride := grid.tile_size.x

	for row in 0..grid.tile_size.x - 1{
		prev_column_sprite_id : u64
		same_row_count : u32
		matching_type : u64
		for column in 0..machine.grid.tile_size.y - 1{
			idx := (row * stride) + column
			tile := buf_ptr(&grid.tile_grid,u64(idx))
			sprite := gfx.get_sprite(nil,tile.symbol.sprite_id)

			if prev_column_sprite_id == sprite.texture_id && column != 0{
				same_row_count += 1
				matching_type = sprite.texture_id
			}
			prev_column_sprite_id = sprite.texture_id
		}
		if same_row_count > 1 && is_results_counted == false{
			is_results_counted = true
			total_money += 100
		}
	}
}

display_grid :: proc(){
	using con
	using machine
	using gfx.asset_ctx

	
	stride := grid.tile_size.x

	for row in 0..grid.tile_size.x - 1{
		for column in 0..machine.grid.tile_size.y - 1{
			idx := (row * stride) + column
			tile := buf_ptr(&grid.tile_grid,u64(idx))
			sprite := gfx.get_sprite(nil,tile.symbol.sprite_id)
			
			if is_spinning{
				tex_id := u64(rand.float32_range(0,6))
				sprite.texture_id = texture_ids[tex_id]
			}

			//set sprite position on grid
			sprite_matrix := con.buf_ptr(&asset_tables.matrix_buffer,sprite.m_id)
			mat := con.buf_get(&asset_tables.matrix_buffer,u64(sprite.proj_id))
			trs_mat := linalg.matrix4_from_trs(tile.t.p,tile.t.r,tile.t.s)
			mul_mat := linalg.matrix_mul(mat,trs_mat)
			sprite_matrix^ = mul_mat
		}
	}
}

add_money : f32
total_money : f32
auto_spin : bool
wait_before_next_spin : f32
bet : f32
bet_amount : f32

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
	}
	imgui.input_float("Amount to add : ",&add_money)
	if imgui.button("Add Money"){
		
		total_money += add_money
		
	}

	imgui.input_float("Bet Amount : ",&bet)

	if is_spinning == false{
		if imgui.button("Set Bet"){
			bet_amount = bet
		}
	}
	imgui.text("Bet Amount : %v",bet_amount)
	imgui.text("Total Money: %v",total_money)

	imgui.checkbox("auto spin",&auto_spin)
	
	if auto_spin && is_spinning == false{
		wait_before_next_spin += platform.ps.time.delta_seconds
		if wait_before_next_spin > 0.5{
			is_spinning = true
			accum_time = 0
			wait_before_next_spin = 0
			is_results_counted = false
			total_money -= bet_amount
		}
	}

	imgui.end()
}

update_machine :: proc(){
	show_temp_ui(&is_show_temp_ui)
	if accum_time < 1{
		accum_time += platform.ps.time.delta_seconds
	}else{
		is_spinning = false
	}

	display_grid()

	if is_spinning == false{
		check_result()	
	}
}

init_basic_machine :: proc(){
	using con
	using e_math
	using rand

	random_number_state = create(u64(10))
    

	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/asteroid.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/bill.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/hen.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/watermelon.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/ruby.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/pear.png"))
	append(&texture_ids,gfx.load_texture_from_path_to_default_heap("data/apple.png"))



	grid : SlotGrid
	grid.tile_size = f2{5,5}
	grid.tile_grid = buf_init(1,SlotGridTile)
	
	//Get these entries from disk or network
	symbol_payouts.entries = buf_init(10,SymbolPayoutEntry)
	for i in 0..24{//(grid.tile_size.x * grid.tile_size.y - 1){
		entry : SymbolPayoutEntry
		entry.amount = u32(100 * (i + 1))
		entry.count = u32(1 * (i + 1))

		entry.symbol.layer_id = 0//default for now

		t : pkg_entity.TRS
		t.p = f3{0,0,0}
		t.r = quat_identity
		t.s = f3{10,10,1}

		entry.symbol.sprite_id = gfx.add_sprite(nil,t.p,t.r,t.s,"")

		buf_push(&symbol_payouts.entries,entry)
	}

	total_lines := 5
	machine.lines = buf_init(5,SlotLine)
	for i in 0..4{
		new_line := SlotLine{con.buf_init(1,SlotSymbol)}
		buf_push(&machine.lines,new_line)
	}

	stride := grid.tile_size.x
	width_of_columns :f32 = 15.0
	column_padding : f32 = 1.0
	total_width_in_units := (width_of_columns * stride)
	origin_left := (total_width_in_units / 2.0) - total_width_in_units
	//origin_left := ((stride / 2.0) * f32(width_of_columns)) - (stride / 2.0)
	start_row := origin_left
	start_column := origin_left
	for row in 0..grid.tile_size.x - 1{
		for column in 0..grid.tile_size.y - 1{
			idx := (row * stride) + column
			tile : SlotGridTile
			tile.symbol = buf_get(&symbol_payouts.entries,u64(idx)).symbol
			tile.t.r = quat_identity
			tile.t.s = f3{10,10,1}
			tile.t.p.x = start_row
			tile.t.p.y = start_column
			start_row += f32(width_of_columns + column_padding)
			buf_push(&grid.tile_grid,tile)

		}
		start_row = origin_left
		start_column += width_of_columns
	}
	machine.grid = grid
}

