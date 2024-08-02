class_name CharacterHealthState extends RefCounted

static var DEFAULT := CharacterHealthState.new()

var health: int

func _init(health: int = 100) -> void:
	self.health = health

func duplicate() -> CharacterHealthState:
	return CharacterHealthState.new(health)

func serialize_to_stream(serialized_data_stream: StreamPeerBuffer) -> void:
	serialized_data_stream.put_u8(health)

static func consume_and_deserialize(serialized_data_stream: StreamPeerBuffer) -> CharacterHealthState:
	return CharacterHealthState.new(serialized_data_stream.get_u8())

func _to_string() -> String:
	return "CharacterHealthState<health=%s>" % [
		health
	]