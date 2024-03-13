extends Node
class_name CharacterNetworkEntity

var character_movement_scene = preload("res://scenes/movement/character_movement_actuator.tscn")
var character_fps_display_scene = preload("res://scenes/character/character_first_person_display_output.tscn")

var network_owner_id_: int
var entity_id_: int
var physics_state_: CharacterPhysicsState
var input_: InputState

func _init(network_owner_id, entity_id, physics_state, input):
	network_owner_id_ = network_owner_id
	entity_id_ = entity_id
	physics_state_ = physics_state
	input_ = input

func _ready():
	pass

func register(current_network_id):
	# returns object containing registration info for both states and GameComponents
	pass
