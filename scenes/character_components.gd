extends Node
class_name CharacterComponents

const MOVEMENT_BODY_SCENE := preload("res://scenes/movement/character_movement_actuator.tscn")
const FIRST_PERSON_DISPLAY_SCENE := preload("res://scenes/character/character_first_person_display_output.tscn")
const THIRD_PERSON_DISPLAY_SCENE := preload("res://scenes/character/character_third_person_display.tscn")

var movement_body_: CharacterMovementActuator
var first_person_display_: CharacterFirstPersonOutput
var third_person_display_: CharacterThirdPersonDisplay

func _init(
	movement_body: CharacterMovementActuator, 
	first_person_display: CharacterFirstPersonOutput, 
	third_person_display: CharacterThirdPersonDisplay) -> void:
	if movement_body != null:
		movement_body_ = movement_body
		add_child(movement_body)
	if first_person_display != null:
		first_person_display_ = first_person_display
		add_child(first_person_display)
	if third_person_display != null:
		third_person_display_ = third_person_display
		add_child(third_person_display)

static func create_for_network_mode(network_mode: int) -> CharacterComponents:
	match network_mode:
		CONSTANTS.NetworkEntityMode.SERVER:
			return CharacterComponents.new(
				MOVEMENT_BODY_SCENE.instantiate(), 
				FIRST_PERSON_DISPLAY_SCENE.instantiate(),
				THIRD_PERSON_DISPLAY_SCENE.instantiate())
		CONSTANTS.NetworkEntityMode.OWN_CLIENT: 
			return CharacterComponents.new(
				MOVEMENT_BODY_SCENE.instantiate(), 
				FIRST_PERSON_DISPLAY_SCENE.instantiate(),
				null)
		CONSTANTS.NetworkEntityMode.OTHER_CLIENT:
			return CharacterComponents.new(
				null, 
				null,
				THIRD_PERSON_DISPLAY_SCENE.instantiate())
		_:
			push_error("Network mode %d is not a value of NetworkEntityMode. Returning null" % network_mode)
			return null

func movement_body() -> CharacterMovementActuator:
	return movement_body_

func first_person_display() -> CharacterFirstPersonOutput:
	return first_person_display_

func third_person_display() -> CharacterThirdPersonDisplay:
	return third_person_display_
