extends RefCounted
class_name ClientStateSnapshot

enum CLIENT_STATE_SNAPSHOT {
	OWN_CHARACTER_STATE,
	REMOTE_CHARACTER_STATES
}

var own_character_state_: ClientOwnCharacterState
var remote_character_states_: Dictionary

func _init(own_character_state: ClientOwnCharacterState, remote_character_states: Dictionary):
	own_character_state_ = own_character_state
	remote_character_states_ = remote_character_states

func own_character_state() -> ClientOwnCharacterState:
	return own_character_state_

func remote_character_states() -> Dictionary:
	return remote_character_states_

func to_dict() -> Dictionary:
	return {
		CLIENT_STATE_SNAPSHOT.OWN_CHARACTER_STATE: own_character_state_.to_dict(),
		CLIENT_STATE_SNAPSHOT.REMOTE_CHARACTER_STATES: __serialize_remote_character_states()
	}

func __serialize_remote_character_states() -> Dictionary:
	var serialized_remote_character_states = {}
	for remote_character_entity_id in remote_character_states_:
		var remote_character_state: CharacterTransformState = remote_character_states_[remote_character_entity_id]
		serialized_remote_character_states[remote_character_entity_id] = remote_character_state.to_dict()
	return serialized_remote_character_states

static func from_dict(dict: Dictionary) -> ClientStateSnapshot:
	return ClientStateSnapshot.new(
		ClientOwnCharacterState.from_dict(dict[CLIENT_STATE_SNAPSHOT.OWN_CHARACTER_STATE]),
		__deserialize_remote_character_states(dict[CLIENT_STATE_SNAPSHOT.REMOTE_CHARACTER_STATES])
	)

static func __deserialize_remote_character_states(serialized_states: Dictionary) -> Dictionary:
	var deserialized_remote_character_states = {}
	for remote_character_entity_id in serialized_states:
		deserialized_remote_character_states[remote_character_entity_id] = CharacterTransformState.from_dict(
			serialized_states[remote_character_entity_id])
	return deserialized_remote_character_states

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

