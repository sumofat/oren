package buffalo_slot

import gt "../../game_types"

BuffaloSlotMachine :: struct{
	state : gt.SlotMachineState,
}

buf_slot_state : BuffaloSlotMachine

init :: proc(){
	using gt
	gt.example_init(&buf_slot_state.state)
	//state_init(&buf_slot_state.state)

}

update :: proc(){
	gt.update(&buf_slot_state.state)
}