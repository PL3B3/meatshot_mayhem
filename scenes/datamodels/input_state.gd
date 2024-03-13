extends Object

class_name InputState

enum INPUT_STATE_KEY { YAW, PITCH, IS_JUMPING, IS_SLOW_WALKING, DIRECTION }

var yaw_: float
var pitch_: float
var is_jumping_: bool
var is_slow_walking_: bool
var direction_: Vector2

func _init(yaw, pitch, is_jumping, is_slow_walking, direction):
	yaw_ = yaw
	pitch_ = pitch
	is_jumping_ = is_jumping
	is_slow_walking_ = is_slow_walking
	direction_ = direction

func yaw():
	return yaw_

func pitch():
	return pitch_

func is_jumping():
	return is_jumping_

func is_slow_walking():
	return is_slow_walking_

func direction():
	return direction_

func to_dict() -> Dictionary:
	return {
		INPUT_STATE_KEY.YAW: yaw_,
		INPUT_STATE_KEY.PITCH: pitch_,
		INPUT_STATE_KEY.IS_JUMPING: is_jumping_,
		INPUT_STATE_KEY.IS_SLOW_WALKING: is_slow_walking_,
		INPUT_STATE_KEY.DIRECTION: direction_
	}

static func from_dict(serialized_data: Dictionary):
	return InputState.new(
		serialized_data[INPUT_STATE_KEY.YAW],
		serialized_data[INPUT_STATE_KEY.PITCH],
		serialized_data[INPUT_STATE_KEY.IS_JUMPING],
		serialized_data[INPUT_STATE_KEY.IS_SLOW_WALKING],
		serialized_data[INPUT_STATE_KEY.DIRECTION]
	)
	
