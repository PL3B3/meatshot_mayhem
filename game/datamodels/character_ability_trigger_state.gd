extends RefCounted
class_name CharacterAbilityTriggerState

enum CHARACTER_ABILITY_TRIGGER_STATE {
	TICKS_UNTIL_CAN_TRIGGER
}

var ticks_until_can_trigger_: int

func _init(ticks_until_can_trigger: int):
	ticks_until_can_trigger_ = ticks_until_can_trigger

func ticks_until_can_trigger() -> int:
	return ticks_until_can_trigger_

func to_dict() -> Dictionary:
	return {
		CHARACTER_ABILITY_TRIGGER_STATE.TICKS_UNTIL_CAN_TRIGGER: ticks_until_can_trigger_
	}

static func from_dict(dict: Dictionary) -> CharacterAbilityTriggerState:
	return CharacterAbilityTriggerState.new(
		dict[CHARACTER_ABILITY_TRIGGER_STATE.TICKS_UNTIL_CAN_TRIGGER]
	)

func serialize_to_stream(serialized_data_stream: StreamPeerBuffer) -> void:
	serialized_data_stream.put_u8(ticks_until_can_trigger_)

static func consume_and_deserialize(serialized_data_stream: StreamPeerBuffer) -> CharacterAbilityTriggerState:
	return CharacterAbilityTriggerState.new(serialized_data_stream.get_u8())

func _to_string() -> String:
	return "CharacterAbilityTriggerState<TICKS_UNTIL_CAN_TRIGGER=%s>" % [
		ticks_until_can_trigger_    
	]
