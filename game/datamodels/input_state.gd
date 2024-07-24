extends RefCounted

class_name InputState

enum INPUT_STATE_KEY { YAW, PITCH, IS_JUMPING, IS_SLOW_WALKING, DIRECTION, CLIENT_TICK }

static var DEFAULT := InputState.new(0, 0, false, false, Vector2(), 0)

var yaw_: float
var pitch_: float
var is_jumping_: bool
var is_slow_walking_: bool
var direction_: Vector2
var client_tick_: int

func _init(
	yaw: float, 
	pitch: float, 
	is_jumping: bool, 
	is_slow_walking: bool, 
	direction: Vector2, 
	client_tick: int
) -> void:
	yaw_ = yaw
	pitch_ = pitch
	is_jumping_ = is_jumping
	is_slow_walking_ = is_slow_walking
	direction_ = direction
	client_tick_ = client_tick

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

func client_tick():
	return client_tick_

func to_dict() -> Dictionary:
	return {
		INPUT_STATE_KEY.YAW: yaw_,
		INPUT_STATE_KEY.PITCH: pitch_,
		INPUT_STATE_KEY.IS_JUMPING: is_jumping_,
		INPUT_STATE_KEY.IS_SLOW_WALKING: is_slow_walking_,
		INPUT_STATE_KEY.DIRECTION: direction_,
		INPUT_STATE_KEY.CLIENT_TICK: client_tick_
	}

static func from_dict(serialized_data: Dictionary) -> InputState:
	return InputState.new(
		serialized_data[INPUT_STATE_KEY.YAW],
		serialized_data[INPUT_STATE_KEY.PITCH],
		serialized_data[INPUT_STATE_KEY.IS_JUMPING],
		serialized_data[INPUT_STATE_KEY.IS_SLOW_WALKING],
		serialized_data[INPUT_STATE_KEY.DIRECTION],
		serialized_data[INPUT_STATE_KEY.CLIENT_TICK]
	)

func _to_string():
	return str(to_dict())
