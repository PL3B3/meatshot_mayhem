extends RefCounted

class_name InputState

enum INPUT_STATE_KEY { YAW, PITCH, IS_JUMPING, IS_SLOW_WALKING, DIRECTION, CLIENT_TICK }
enum BIT_MASK {
	IS_JUMPING = 1 << 0,
	IS_SLOW_WALKING = 1 << 1
}

static var DEFAULT := InputState.new(0, 0, false, false, Vector2(), 0)
static var POSSIBLE_NORMALIZED_MOVE_DIRECTIONS: Array[Vector2] = [
	Vector2(0,-1).normalized(),
	Vector2(0,0).normalized(),
	Vector2(0,1).normalized(),
	Vector2(1,-1).normalized(),
	Vector2(1,0).normalized(),
	Vector2(1,1).normalized(),
	Vector2(-1,-1).normalized(),
	Vector2(-1,0).normalized(),
	Vector2(-1,1).normalized()
]

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

func serialize() -> PackedByteArray:
	var serialized_input := StreamPeerBuffer.new()

	var flags_as_u8: int = 0
	if is_jumping_:
		flags_as_u8 = flags_as_u8 | BIT_MASK.IS_JUMPING
	if is_slow_walking_:
		flags_as_u8 = flags_as_u8 | BIT_MASK.IS_SLOW_WALKING
	var move_direction_as_u8 := __convert_direction_to_uint8(direction_)

	serialized_input.put_u16(SerdeUtil.YAW_DEG_SERDE.serialize_float_to_u16(yaw_))
	serialized_input.put_u16(SerdeUtil.PITCH_DEG_SERDE.serialize_float_to_u16(pitch_))
	serialized_input.put_u8(flags_as_u8)
	serialized_input.put_u8(move_direction_as_u8)
	serialized_input.put_32(client_tick_)

	return serialized_input.data_array

static func deserialize(serialized_data: PackedByteArray) -> InputState:
	var serialized_input := StreamPeerBuffer.new()
	serialized_input.data_array = serialized_data

	var yaw_as_u16 := serialized_input.get_u16()
	var pitch_as_u16 := serialized_input.get_u16()
	var flags_as_u8 := serialized_input.get_u8()
	var move_direction_as_u8 := serialized_input.get_u8()
	var client_tick := serialized_input.get_32()
	
	var yaw: float = SerdeUtil.YAW_DEG_SERDE.deserialize_float_from_u16(yaw_as_u16)
	var pitch: float = SerdeUtil.PITCH_DEG_SERDE.deserialize_float_from_u16(pitch_as_u16)
	var is_jumping := bool(flags_as_u8 & BIT_MASK.IS_JUMPING)
	var is_slow_walking := bool(flags_as_u8 & BIT_MASK.IS_SLOW_WALKING)
	var move_direction := __convert_uint8_to_direction(move_direction_as_u8)

	return InputState.new(yaw, pitch, is_jumping, is_slow_walking, move_direction, client_tick)

static func __convert_direction_to_uint8(direction: Vector2) -> int:
	for index: int in range(POSSIBLE_NORMALIZED_MOVE_DIRECTIONS.size()):
		var possible_move_direction := POSSIBLE_NORMALIZED_MOVE_DIRECTIONS[index]
		if possible_move_direction.is_equal_approx(direction):
			return index
	return -1

static func __convert_uint8_to_direction(direction_index: int) -> Vector2:
	return POSSIBLE_NORMALIZED_MOVE_DIRECTIONS[direction_index]

func _to_string():
	return str(to_dict())
