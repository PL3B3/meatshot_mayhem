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

func serialize_to_stream(serialized_data_stream: StreamPeerBuffer) -> void:
	serialized_data_stream.put_u16(SerdeUtil.POSITION_AXIS_SERDE.serialize_float_to_u16(position_.x))
	serialized_data_stream.put_u16(SerdeUtil.POSITION_AXIS_SERDE.serialize_float_to_u16(position_.y))
	serialized_data_stream.put_u16(SerdeUtil.POSITION_AXIS_SERDE.serialize_float_to_u16(position_.z))
	serialized_data_stream.put_u16(SerdeUtil.PITCH_DEG_SERDE.serialize_float_to_u16(pitch_))
	serialized_data_stream.put_u16(SerdeUtil.YAW_DEG_SERDE.serialize_float_to_u16(yaw_))

static func consume_and_deserialize(serialized_data_stream: StreamPeerBuffer) -> CharacterTransformState:
	return CharacterTransformState.new(
		Vector3(
			SerdeUtil.POSITION_AXIS_SERDE.deserialize_float_from_u16(serialized_data_stream.get_u16()),
			SerdeUtil.POSITION_AXIS_SERDE.deserialize_float_from_u16(serialized_data_stream.get_u16()),
			SerdeUtil.POSITION_AXIS_SERDE.deserialize_float_from_u16(serialized_data_stream.get_u16())),
		SerdeUtil.PITCH_DEG_SERDE.deserialize_float_from_u16(serialized_data_stream.get_u16()),
		SerdeUtil.YAW_DEG_SERDE.deserialize_float_from_u16(serialized_data_stream.get_u16()))

func _to_string() -> String:
	return "CharacterTransformState<POSITION=%s, PITCH=%s, YAW=%s>" % [
		position_,
		pitch_,
		yaw_    
	]
