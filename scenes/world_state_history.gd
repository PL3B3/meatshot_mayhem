extends Object

class_name WorldStateHistory

"""
Indexed by tick, then by data type, then id
{
	15: {
		physics_data: {
			1014: PhysicsStateData{...}
			8724: PhysicsStateData{...}
		}
		input: {
			1014: Input{...}
		}
	}
}
"""
var world_state_per_tick_: Dictionary = {}
var latest_tick_: int = 0

func set_state(tick: int, state_type, entity_id, state_value):
	latest_tick_ = max(latest_tick_, tick)
	var world_state_for_tick: Dictionary = get_or_compute(world_state_per_tick_, tick, {})
	var states_for_type: Dictionary = get_or_compute(world_state_for_tick, state_type, {})
	states_for_type[entity_id] = state_value

func advance_tick_and_copy_latest_state():
	var latest_state: Dictionary = get_or_compute(world_state_per_tick_, latest_tick_, {})
	world_state_per_tick_[latest_tick_ + 1] = latest_state.duplicate(true)
	latest_tick_ += 1
	return latest_tick_

static func get_or_compute(dictionary, key, default_value):
	if !dictionary.has(key):
		dictionary[key] = default_value
	return dictionary[key]
