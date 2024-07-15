extends RefCounted
class_name ServerCharacterState

var physics_state: CharacterPhysicsState
var health_state: CharacterHealthState

func _init(physics_state: CharacterPhysicsState, health_state: CharacterHealthState) -> void:
	self.physics_state = physics_state
	self.health_state = health_state

func _to_string() -> String:
	return "ServerCharacterState<physics_state=%s, health_state=%s>" % [
		physics_state,
		health_state    
	]
