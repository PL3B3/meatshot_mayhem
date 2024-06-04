extends Object
class_name ClientOwnCharacterState

enum CLIENT_OWN_CHARACTER_STATE {
	PHYSICS_STATE,
	ABILITY_TRIGGER_STATE
}

var physics_state_: CharacterPhysicsState
var ability_trigger_state_: CharacterAbilityTriggerState

func _init(physics_state: CharacterPhysicsState, ability_trigger_state: CharacterAbilityTriggerState):
	physics_state_ = physics_state
	ability_trigger_state_ = ability_trigger_state

func physics_state() -> CharacterPhysicsState:
	return physics_state_

func ability_trigger_state() -> CharacterAbilityTriggerState:
	return ability_trigger_state_

func to_dict() -> Dictionary:
	return {
		CLIENT_OWN_CHARACTER_STATE.PHYSICS_STATE: physics_state_.to_dict(),
		CLIENT_OWN_CHARACTER_STATE.ABILITY_TRIGGER_STATE: ability_trigger_state_.to_dict()
	}

static func from_dict(dict: Dictionary) -> ClientOwnCharacterState:
	return ClientOwnCharacterState.new(
		CharacterPhysicsState.from_dict(dict[CLIENT_OWN_CHARACTER_STATE.PHYSICS_STATE]),
		CharacterAbilityTriggerState.from_dict(dict[CLIENT_OWN_CHARACTER_STATE.ABILITY_TRIGGER_STATE])
	)

func _to_string() -> String:
	return "ClientOwnCharacterState<PHYSICS_STATE=%s, ABILITY_TRIGGER_STATE=%s>" % [
		physics_state_,
		ability_trigger_state_    
	]