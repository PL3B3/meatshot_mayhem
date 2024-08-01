extends RefCounted
class_name ClientOwnCharacterState

var physics_state_: CharacterPhysicsState
var ability_trigger_state_: CharacterAbilityTriggerState
var health_state_: CharacterHealthState
var input_state_: InputState

func _init(
		physics_state: CharacterPhysicsState, 
		ability_trigger_state: CharacterAbilityTriggerState,
		health_state: CharacterHealthState,
		input_state: InputState):
	physics_state_ = physics_state
	ability_trigger_state_ = ability_trigger_state
	health_state_ = health_state
	input_state_ = input_state

func physics_state() -> CharacterPhysicsState:
	return physics_state_

func ability_trigger_state() -> CharacterAbilityTriggerState:
	return ability_trigger_state_

func health_state() -> CharacterHealthState:
	return health_state_

func input_state() -> InputState:
	return input_state_

func serialize_to_stream(serialized_data_stream: StreamPeerBuffer) -> void:
	physics_state_.serialize_to_stream(serialized_data_stream)
	ability_trigger_state_.serialize_to_stream(serialized_data_stream)
	health_state_.serialize_to_stream(serialized_data_stream)
	# no need to serialize input state, as it's not used on client

static func consume_and_deserialize(serialized_data_stream: StreamPeerBuffer) -> ClientOwnCharacterState:
	return ClientOwnCharacterState.new(
		CharacterPhysicsState.consume_and_deserialize(serialized_data_stream),
		CharacterAbilityTriggerState.consume_and_deserialize(serialized_data_stream),
		CharacterHealthState.consume_and_deserialize(serialized_data_stream),
		InputState.DEFAULT)

func _to_string() -> String:
	return "ClientOwnCharacterState<PHYSICS_STATE=%s, ABILITY_TRIGGER_STATE=%s, HEALTH_STATE=%s, INPUT_STATE=%s>" % [
		physics_state_,
		ability_trigger_state_,
		health_state_,
		input_state_
	]
