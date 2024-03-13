extends Object
class_name CharacterPhysicsState

enum CHARACTER_PHYSICS_STATE_KEY { POSITION, VELOCITY, IS_GROUNDED }

var position_: Vector3 = Vector3.ZERO
var velocity_: Vector3 = Vector3.ZERO
var is_grounded_: bool = false

func _init(position, velocity, is_grounded):
	position_ = position
	velocity_ = velocity
	is_grounded_ = is_grounded

func position():
	return position_

func velocity():
	return velocity_

func is_grounded():
	return is_grounded_

func to_dict():
	return {
		CHARACTER_PHYSICS_STATE_KEY.POSITION: position_,
		CHARACTER_PHYSICS_STATE_KEY.VELOCITY: velocity_,
		CHARACTER_PHYSICS_STATE_KEY.IS_GROUNDED: is_grounded_
	}

static func from_dict(dict: Dictionary):
	return CharacterPhysicsState.new(
		dict[CHARACTER_PHYSICS_STATE_KEY.POSITION],
		dict[CHARACTER_PHYSICS_STATE_KEY.VELOCITY],
		dict[CHARACTER_PHYSICS_STATE_KEY.IS_GROUNDED]
	)

