extends RefCounted
class_name CharacterPhysicsState

enum CHARACTER_PHYSICS_STATE { 
	POSITION, 
	VELOCITY, 
	IS_GROUNDED 
}

var position_: Vector3 = Vector3.ZERO
var velocity_: Vector3 = Vector3.ZERO
var is_grounded_: bool = false

func _init(position: Vector3, velocity: Vector3, is_grounded: bool) -> void:
	position_ = position
	velocity_ = velocity
	is_grounded_ = is_grounded

func position() -> Vector3:
	return position_

func velocity() -> Vector3:
	return velocity_

func is_grounded() -> bool:
	return is_grounded_

func to_dict() -> Dictionary:
	return {
		CHARACTER_PHYSICS_STATE.POSITION: position_,
		CHARACTER_PHYSICS_STATE.VELOCITY: velocity_,
		CHARACTER_PHYSICS_STATE.IS_GROUNDED: is_grounded_
	}

static func from_dict(dict: Dictionary) -> CharacterPhysicsState:
	return CharacterPhysicsState.new(
		dict[CHARACTER_PHYSICS_STATE.POSITION],
		dict[CHARACTER_PHYSICS_STATE.VELOCITY],
		dict[CHARACTER_PHYSICS_STATE.IS_GROUNDED]
	)

func _to_string() -> String:
	return "CharacterPhysicsState<POSITION=%s, VELOCITY=%s, IS_GROUNDED=%s>" % [
		position_,
		velocity_,
		is_grounded_
	]
