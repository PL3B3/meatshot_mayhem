extends Object
class_name ClientOwnCharacterState

enum CLIENT_OWN_CHARACTER_STATE {
	ENTITY_ID,
	PHYSICS_STATE
}

var entity_id_: int
var physics_state_: CharacterPhysicsState

func _init(entity_id: int, physics_state: CharacterPhysicsState):
	entity_id_ = entity_id
	physics_state_ = physics_state

func entity_id() -> int:
	return entity_id_

func physics_state() -> CharacterPhysicsState:
	return physics_state_

func to_dict() -> Dictionary:
	return {
		CLIENT_OWN_CHARACTER_STATE.ENTITY_ID: entity_id_,
		CLIENT_OWN_CHARACTER_STATE.PHYSICS_STATE: physics_state_.to_dict()
	}

static func from_dict(dict: Dictionary) -> ClientOwnCharacterState:
	return ClientOwnCharacterState.new(
		dict[CLIENT_OWN_CHARACTER_STATE.ENTITY_ID],
		CharacterPhysicsState.from_dict(dict[CLIENT_OWN_CHARACTER_STATE.PHYSICS_STATE])
	)

func _to_string() -> String:
	return "ClientOwnCharacterState<ENTITY_ID=%s, PHYSICS_STATE=%s>" % [
		entity_id_,
		physics_state_    
	]
