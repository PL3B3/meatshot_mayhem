extends Node
class_name NetworkEntity

var network_mode_

func _init(entity_id: int, network_mode):
	name = str(entity_id)
	network_mode_ = network_mode

func get_entity_id() -> int:
	assert(name.is_valid_int(), "Network entity name %s must be a valid int" % [name])
	return name.to_int()

func get_network_mode():
	return network_mode_
