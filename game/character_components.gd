extends Node
class_name CharacterComponents

const MOVEMENT_BODY_SCENE := preload("res://game/movement/character_movement_actuator.tscn")
const FIRST_PERSON_DISPLAY_SCENE := preload("res://game/character/character_first_person_display_output.tscn")
const THIRD_PERSON_DISPLAY_SCENE := preload("res://game/character/character_third_person_display.tscn")
const HITSCAN_ACTION_SCENE := preload("res://game/character/character_ability_hitscan_action.tscn")

var movement_body_: CharacterMovementActuator
var first_person_display_: CharacterFirstPersonOutput
var third_person_display_: CharacterThirdPersonDisplay
var ability_trigger_state_machine_: CharacterAbilityTriggerStateMachine
var ability_action_: AbstractCharacterAbilityAction

func _init(
	movement_body: CharacterMovementActuator, 
	first_person_display: CharacterFirstPersonOutput, 
	third_person_display: CharacterThirdPersonDisplay,
	ability_trigger_state_machine: CharacterAbilityTriggerStateMachine,
	ability_action: AbstractCharacterAbilityAction
) -> void:
	movement_body_ = movement_body
	first_person_display_ = first_person_display
	third_person_display_ = third_person_display
	ability_trigger_state_machine_ = ability_trigger_state_machine
	ability_action_ = ability_action
	__add_child_if_not_null(movement_body)
	__add_child_if_not_null(first_person_display)
	__add_child_if_not_null(third_person_display)
	__add_child_if_not_null(ability_action)

static func create_for_network_mode(network_mode: int) -> CharacterComponents:
	match network_mode:
		CONSTANTS.NetworkEntityMode.SERVER:
			return CharacterComponents.new(
				MOVEMENT_BODY_SCENE.instantiate(), 
				FIRST_PERSON_DISPLAY_SCENE.instantiate(),
				THIRD_PERSON_DISPLAY_SCENE.instantiate(),
				null,
				HITSCAN_ACTION_SCENE.instantiate())
		CONSTANTS.NetworkEntityMode.OWN_CLIENT: 
			return CharacterComponents.new(
				MOVEMENT_BODY_SCENE.instantiate(), 
				FIRST_PERSON_DISPLAY_SCENE.instantiate(),
				null,
				CharacterAbilityTriggerStateMachine.new(),
				HITSCAN_ACTION_SCENE.instantiate())
		CONSTANTS.NetworkEntityMode.OTHER_CLIENT:
			return CharacterComponents.new(
				null, 
				null,
				THIRD_PERSON_DISPLAY_SCENE.instantiate(),
				null,
				HITSCAN_ACTION_SCENE.instantiate())
		_:
			push_error("Network mode %d is not a value of NetworkEntityMode. Returning null" % network_mode)
			return null

func movement_body() -> CharacterMovementActuator:
	return movement_body_

func first_person_display() -> CharacterFirstPersonOutput:
	return first_person_display_

func third_person_display() -> CharacterThirdPersonDisplay:
	return third_person_display_

func ability_trigger_state_machine() -> CharacterAbilityTriggerStateMachine:
	return ability_trigger_state_machine_

func ability_action() -> AbstractCharacterAbilityAction:
	return ability_action_

func __add_child_if_not_null(node: Node) -> void:
	if node != null:
		add_child(node)
