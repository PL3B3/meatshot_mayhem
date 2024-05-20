extends Object
class_name ClientRemoteCharacterState

enum CLIENT_REMOTE_CHARACTER_STATE {
	ENTITY_ID,
	TRANSFORM
}

var entity_id_: int
var transform_: CharacterTransformState

func _init(entity_id: int, transform: CharacterTransformState):
	entity_id_ = entity_id
	transform_ = transform

func entity_id() -> int:
	return entity_id_

func transform() -> CharacterTransformState:
	return transform_

func to_dict() -> Dictionary:
	return {
		CLIENT_REMOTE_CHARACTER_STATE.ENTITY_ID: entity_id_,
		CLIENT_REMOTE_CHARACTER_STATE.TRANSFORM: transform_.to_dict()
	}

static func from_dict(dict: Dictionary) -> ClientRemoteCharacterState:
	return ClientRemoteCharacterState.new(
		dict[CLIENT_REMOTE_CHARACTER_STATE.ENTITY_ID],
		CharacterTransformState.from_dict(dict[CLIENT_REMOTE_CHARACTER_STATE.TRANSFORM])
	)

func _to_string() -> String:
	return "ClientRemoteCharacterState<ENTITY_ID=%s, TRANSFORM=%s>" % [
		entity_id_,
		transform_    
	]
