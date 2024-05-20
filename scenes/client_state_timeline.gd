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

# func get_current_entity_state(entity_id: int):
# 	return get_entity_state(get_current_tick(), entity_id)

# func get_entity_state(tick: int, entity_id: int):
# 	var state_for_tick = get_state(tick)
# 	return Utils.get_or_default(state_for_tick, entity_id, {})

# func get_remote_character_states(tick: int) -> Dictionary:
# 	var state_for_tick := get_state(tick)
# 	if state_for_tick != null:
# 		return state_for_tick.remote_character_states()
# 	else:
# 		return {}

# func get_own_character_state(tick: int) -> CharacterPhysicsState:
# 	var state_for_tick := get_state(tick)
# 	if state_for_tick != null:
# 		return state_for_tick.own_character_state()
# 	else:
# 		return null

func get_current_tick():
	return world_states_.size() - 1

func get_next_tick():
	return get_current_tick() + 1

func has_states():
	return world_states_.size() > 0
