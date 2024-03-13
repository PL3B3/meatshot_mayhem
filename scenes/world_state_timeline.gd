extends Object

class_name WorldStateTimeline

"""
Indexed by tick, then by id, then data type
{
	15: {
		1014: {
			PhysicsState: PhysicsStateData{...}
			Input: Input{...}
		}
		8472: {
			PhysicsState: PhysicsStateData{...}
		}
	},
	16: {
		1014: {
			PhysicsState: PhysicsStateData{...}
			Input: Input{...}
		}
		8472: {
			PhysicsState: PhysicsStateData{...}
		}
	}
}
"""
#var world_state_per_tick_: Dictionary = {}
#var latest_tick_: int = 0
#
#func set_state(tick: int, state_type, entity_id, state_value):
	#latest_tick_ = max(latest_tick_, tick)
	#var world_state_for_tick: Dictionary = compute_if_absent(world_state_per_tick_, tick, {})
	#var states_for_type: Dictionary = compute_if_absent(world_state_for_tick, state_type, {})
	#states_for_type[entity_id] = state_value
#
#func advance_tick_and_copy_latest_state():
	#var latest_state: Dictionary = compute_if_absent(world_state_per_tick_, latest_tick_, {})
	#world_state_per_tick_[latest_tick_ + 1] = latest_state.duplicate(true)
	#latest_tick_ += 1
	#return latest_tick_
#
#static func compute_if_absent(dictionary, key, default_value):
	#if !dictionary.has(key):
		#dictionary[key] = default_value
	#return dictionary[key]

var world_states_: Array = []

func add_next_state(next_state: Dictionary):
	world_states_.push_back(next_state)
	return get_current_tick()

func get_state(tick: int) -> Dictionary:
	if tick < 0 or tick >= world_states_.size():
		print("Cannot retrieve state for tick %d. Current tick is %d." % [tick, get_current_tick()])
		return {}
	return world_states_[tick]

func get_current_state() -> Dictionary:
	return get_state(get_current_tick())

func get_current_entity_state(entity_id: int):
	return get_entity_state(get_current_tick(), entity_id)

func get_entity_state(tick: int, entity_id: int):
	var state_for_tick = get_state(tick)
	return Utils.get_or_default(state_for_tick, entity_id, {})

func get_current_tick():
	return world_states_.size() - 1

func has_states():
	return world_states_.size() > 0
