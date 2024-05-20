extends Object
class_name CharacterPhysicsState

enum CHARACTER_PHYSICS_STATE { 
    POSITION, 
    VELOCITY, 
    IS_GROUNDED 
}

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
        CHARACTER_PHYSICS_STATE.POSITION: position_,
        CHARACTER_PHYSICS_STATE.VELOCITY: velocity_,
        CHARACTER_PHYSICS_STATE.IS_GROUNDED: is_grounded_
    }

static func from_dict(dict: Dictionary):
    return CharacterPhysicsState.new(
        dict[CHARACTER_PHYSICS_STATE.POSITION],
        dict[CHARACTER_PHYSICS_STATE.VELOCITY],
        dict[CHARACTER_PHYSICS_STATE.IS_GROUNDED]
    )

func _to_string():
    return "CharacterPhysicsState<POSITION=%s, VELOCITY=%s, IS_GROUNDED=%s>" % [
        position_,
        velocity_,
        is_grounded_
    ]
