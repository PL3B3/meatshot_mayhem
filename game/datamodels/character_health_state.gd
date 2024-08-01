extends RefCounted
class_name CharacterHealthState

const DEFAULT_HEALTH := 100
static var DEFAULT_HEALTH_STATE := CharacterHealthState.new(DEFAULT_HEALTH)

var health_: int

func _init(health: int):
	health_ = health

func health() -> int:
	return health_

func serialize_to_stream(serialized_data_stream: StreamPeerBuffer) -> void:
	serialized_data_stream.put_u8(health_)

static func consume_and_deserialize(serialized_data_stream: StreamPeerBuffer) -> CharacterHealthState:
	return CharacterHealthState.new(serialized_data_stream.get_u8())

func _to_string() -> String:
	return "CharacterHealthState<HEALTH=%s>" % [
		health_    
	]
