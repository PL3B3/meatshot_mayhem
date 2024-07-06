extends RefCounted
class_name ClientStateTimeline

const RING_BUFFER_SIZE := 100

var world_states_: Array[ClientStateSnapshot] = []
var current_tick_: int = -1

func _init() -> void:
	world_states_.resize(RING_BUFFER_SIZE)

func add_next_state(next_state: ClientStateSnapshot) -> int:
	current_tick_ += 1
	var index_in_ringbuffer_to_insert: int = current_tick_ % RING_BUFFER_SIZE
	world_states_[index_in_ringbuffer_to_insert] = next_state
	return current_tick_

func get_state(tick: int) -> ClientStateSnapshot:
	assert(tick > -1 and tick <= current_tick_, "Tick must be between 0 and timeline size %d" % current_tick_)
	return world_states_[tick % RING_BUFFER_SIZE]

func get_current_state() -> ClientStateSnapshot:
	return get_state(get_current_tick())

func get_current_tick() -> int:
	return current_tick_

func get_next_tick() -> int:
	return get_current_tick() + 1

func has_states() -> bool:
	return current_tick_ > -1

func get_inputs_since_tick(start_tick_inclusive: int) -> Array[InputState]:
	var inputs_since_start_tick_inclusive: Array[InputState] = []
	for tick in range(start_tick_inclusive, get_next_tick()):
		inputs_since_start_tick_inclusive.append(get_state(tick).own_character_state().input_state())
	return inputs_since_start_tick_inclusive
