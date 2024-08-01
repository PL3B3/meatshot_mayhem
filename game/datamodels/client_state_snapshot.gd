extends RefCounted
class_name ClientStateSnapshot

var own_character_state_: ClientOwnCharacterState
var remote_character_states_: Dictionary

func _init(own_character_state: ClientOwnCharacterState, remote_character_states: Dictionary):
	own_character_state_ = own_character_state
	remote_character_states_ = remote_character_states

func own_character_state() -> ClientOwnCharacterState:
	return own_character_state_

func remote_character_states() -> Dictionary:
	return remote_character_states_

func serialize() -> PackedByteArray:
	var serialized_data_stream := StreamPeerBuffer.new()
	own_character_state_.serialize_to_stream(serialized_data_stream)
	serialized_data_stream.put_u8(remote_character_states_.size())
	for remote_character_entity_id: int in remote_character_states_:
		var remote_character_state: CharacterTransformState = remote_character_states_[remote_character_entity_id]
		serialized_data_stream.put_u16(remote_character_entity_id)
		remote_character_state.serialize_to_stream(serialized_data_stream)
	return serialized_data_stream.data_array

static func deserialize(serialized_data: PackedByteArray) -> ClientStateSnapshot:
	var serialized_data_stream := StreamPeerBuffer.new()
	serialized_data_stream.data_array = serialized_data
	var own_character_state := ClientOwnCharacterState.consume_and_deserialize(serialized_data_stream)
	var remote_character_transform_state_per_entity_id := {}
	var remote_character_count := serialized_data_stream.get_u8()
	for i in range(remote_character_count):
		var remote_character_entity_id := serialized_data_stream.get_u16()
		remote_character_transform_state_per_entity_id[remote_character_entity_id] = (
			CharacterTransformState.consume_and_deserialize(serialized_data_stream))
	return ClientStateSnapshot.new(own_character_state, remote_character_transform_state_per_entity_id)

func _to_string() -> String:
	return "ClientStateSnapshot<OWN_CHARACTER_STATE=%s, REMOTE_CHARACTER_STATES=%s>" % [
		own_character_state_,
		remote_character_states_    
	]

