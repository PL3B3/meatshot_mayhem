extends Object
class_name ServerCharacterState

enum SERVER_CHARACTER_STATE {
	PHYSICS_STATE,
	HEALTH_STATE
}

var physics_state_: CharacterPhysicsState
var health_state_: CharacterHealthState

func _init(physics_state: CharacterPhysicsState, health_state: CharacterHealthState) -> void:
	physics_state_ = physics_state
	health_state_ = health_state

func physics_state() -> CharacterPhysicsState:
	return physics_state_

func health_state() -> CharacterHealthState:
	return health_state_

func to_dict() -> Dictionary:
	return {
		SERVER_CHARACTER_STATE.PHYSICS_STATE: physics_state_.to_dict(),
		SERVER_CHARACTER_STATE.HEALTH_STATE: health_state_.to_dict()
	}

static func from_dict(dict: Dictionary) -> ServerCharacterState:
	return ServerCharacterState.new(
		CharacterPhysicsState.from_dict(dict[SERVER_CHARACTER_STATE.PHYSICS_STATE]),
		CharacterHealthState.from_dict(dict[SERVER_CHARACTER_STATE.HEALTH_STATE])
	)

func _to_string() -> String:
	return "ServerCharacterState<PHYSICS_STATE=%s, HEALTH_STATE=%s>" % [
		physics_state_,
		health_state_    
	]