extends RefCounted
class_name ClientOwnCharacterState

enum CLIENT_OWN_CHARACTER_STATE {
	PHYSICS_STATE,
	ABILITY_TRIGGER_STATE,
	HEALTH_STATE,
	INPUT_STATE
}

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

func to_dict() -> Dictionary:
	return {
		CLIENT_OWN_CHARACTER_STATE.PHYSICS_STATE: physics_state_.to_dict(),
		CLIENT_OWN_CHARACTER_STATE.ABILITY_TRIGGER_STATE: ability_trigger_state_.to_dict(),
		CLIENT_OWN_CHARACTER_STATE.HEALTH_STATE: health_state_.to_dict(),
		CLIENT_OWN_CHARACTER_STATE.INPUT_STATE: input_state_.to_dict()
	}

static func from_dict(dict: Dictionary) -> ClientOwnCharacterState:
	return ClientOwnCharacterState.new(
		CharacterPhysicsState.from_dict(dict[CLIENT_OWN_CHARACTER_STATE.PHYSICS_STATE]),
		CharacterAbilityTriggerState.from_dict(dict[CLIENT_OWN_CHARACTER_STATE.ABILITY_TRIGGER_STATE]),
		CharacterHealthState.from_dict(dict[CLIENT_OWN_CHARACTER_STATE.HEALTH_STATE]),
		InputState.from_dict(dict[CLIENT_OWN_CHARACTER_STATE.INPUT_STATE])
	)

func serialize() -> PackedByteArray:
	var serialized_data_stream := StreamPeerBuffer.new()
	physics_state_.serialize_to_stream(serialized_data_stream)
	ability_trigger_state_.serialize_to_stream(serialized_data_stream)
	health_state_.serialize_to_stream(serialized_data_stream)
	# no need to serialize input state, as it's not used on client
	return serialized_data_stream.data_array

static func deserialize(serialized_data: PackedByteArray) -> ClientOwnCharacterState:
	var serialized_data_stream := StreamPeerBuffer.new()
	serialized_data_stream.data_array = serialized_data
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
