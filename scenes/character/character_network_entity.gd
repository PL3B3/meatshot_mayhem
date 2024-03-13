extends NetworkEntity
class_name CharacterNetworkEntity

var character_movement_scene = preload("res://scenes/movement/character_movement_actuator.tscn")
var character_first_person_display_scene = preload("res://scenes/character/character_first_person_display_output.tscn")
var character_third_person_display_scene = preload("res://scenes/character/character_third_person_display.tscn")

var network_owner_id_: int
var entity_id_: int
var physics_state_: CharacterPhysicsState
var input_: InputState

var character_movement_
var character_first_person_display_
var character_third_person_display_

func _init(entity_id, network_mode):
	super(entity_id, network_mode)

func _ready():
	match network_mode_:
		CONSTANTS.NetworkEntityMode.SERVER, CONSTANTS.NetworkEntityMode.OWN_CLIENT:
			__add_movement_calculator()
			__add_first_person_display()
		CONSTANTS.NetworkEntityMode.OTHER_CLIENT:
			__add_third_person_display()

func get_movement_calculator() -> CharacterMovementActuator:
	return character_movement_

func get_first_person_display() -> CharacterFirstPersonOutput:
	return character_first_person_display_

func get_third_person_display() -> CharacterThirdPersonDisplay:
	return character_third_person_display_

func __add_movement_calculator():
	character_movement_ = character_movement_scene.instantiate()
	add_child(character_movement_)

func __add_first_person_display():
	character_first_person_display_ = character_first_person_display_scene.instantiate()
	add_child(character_first_person_display_)

func __add_third_person_display():
	character_third_person_display_ = character_third_person_display_scene.instantiate()
	add_child(character_third_person_display_)
