extends Object
class_name ClientStateTimeline

var world_states_: Array[ClientStateSnapshot] = []

func add_next_state(next_state: ClientStateSnapshot):
	world_states_.push_back(next_state)
	return get_current_tick()

func get_state(tick: int) -> ClientStateSnapshot:
	if tick < 0 or tick >= world_states_.size():
		print("Cannot retrieve state for tick %d. Current tick is %d." % [tick, get_current_tick()])
		return null
	return world_states_[tick]

func get_current_state() -> ClientStateSnapshot:
	return get_state(get_current_tick())

func get_current_tick():
	return world_states_.size() - 1

func get_next_tick():
	return get_current_tick() + 1

func has_states():
	return world_states_.size() > 0

func get_inputs_since_tick(start_tick_inclusive: int) -> Array[InputState]:
	var inputs_since_start_tick_inclusive: Array[InputState] = []
	for tick in range(start_tick_inclusive, get_next_tick()):
		inputs_since_start_tick_inclusive.append(get_state(tick).own_character_state().input_state())
	return inputs_since_start_tick_inclusive
