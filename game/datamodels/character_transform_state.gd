extends RefCounted
class_name CharacterTransformState

enum CHARACTER_TRANSFORM_STATE {
	POSITION,
	PITCH,
	YAW
}

var position_: Vector3
var pitch_: float
var yaw_: float

func _init(position: Vector3, pitch: float, yaw: float):
	position_ = position
	pitch_ = pitch
	yaw_ = yaw

func position() -> Vector3:
	return position_

func pitch() -> float:
	return pitch_

func yaw() -> float:
	return yaw_

func to_dict() -> Dictionary:
	return {
		CHARACTER_TRANSFORM_STATE.POSITION: position_,
		CHARACTER_TRANSFORM_STATE.PITCH: pitch_,
		CHARACTER_TRANSFORM_STATE.YAW: yaw_
	}

static func from_dict(dict: Dictionary) -> CharacterTransformState:
	return CharacterTransformState.new(
		dict[CHARACTER_TRANSFORM_STATE.POSITION],
		dict[CHARACTER_TRANSFORM_STATE.PITCH],
		dict[CHARACTER_TRANSFORM_STATE.YAW]
	)

func serialize() -> PackedByteArray:
	var serialized_input := StreamPeerBuffer.new()
	serialized_input.put_u16(SerdeUtil.position_axis_to_u16(position_.x))
	serialized_input.put_u16(SerdeUtil.position_axis_to_u16(position_.y))
	serialized_input.put_u16(SerdeUtil.position_axis_to_u16(position_.z))
	serialized_input.put_u16(SerdeUtil.pitch_to_u16(pitch_))
	serialized_input.put_u16(SerdeUtil.yaw_to_u16(yaw_))
	return serialized_input.data_array

static func deserialize(serialized_data: PackedByteArray) -> CharacterTransformState:
	var serialized_input := StreamPeerBuffer.new()
	serialized_input.data_array = serialized_data
	return CharacterTransformState.new(
		Vector3(
			SerdeUtil.u16_to_position_axis(serialized_input.get_u16()),
			SerdeUtil.u16_to_position_axis(serialized_input.get_u16()),
			SerdeUtil.u16_to_position_axis(serialized_input.get_u16())),
		SerdeUtil.u16_to_pitch(serialized_input.get_u16()),
		SerdeUtil.u16_to_yaw(serialized_input.get_u16()))

func _to_string() -> String:
	return "CharacterTransformState<POSITION=%s, PITCH=%s, YAW=%s>" % [
		position_,
		pitch_,
		yaw_    
	]
