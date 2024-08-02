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

func duplicate() -> CharacterPhysicsState:
	return CharacterPhysicsState.new(position_, velocity_, is_grounded_)

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

func serialize_to_stream(serialized_data_stream: StreamPeerBuffer) -> void:
	serialized_data_stream.put_u16(SerdeUtil.POSITION_AXIS_SERDE.serialize_float_to_u16(position_.x))
	serialized_data_stream.put_u16(SerdeUtil.POSITION_Y_AXIS_SERDE.serialize_float_to_u16(position_.y))
	serialized_data_stream.put_u16(SerdeUtil.POSITION_AXIS_SERDE.serialize_float_to_u16(position_.z))
	serialized_data_stream.put_u16(SerdeUtil.VELOCITY_AXIS_SERDE.serialize_float_to_u16(velocity_.x))
	serialized_data_stream.put_u16(SerdeUtil.VELOCITY_AXIS_SERDE.serialize_float_to_u16(velocity_.y))
	serialized_data_stream.put_u16(SerdeUtil.VELOCITY_AXIS_SERDE.serialize_float_to_u16(velocity_.z))
	serialized_data_stream.put_u8(int(is_grounded_))

static func consume_and_deserialize(serialized_data_stream: StreamPeerBuffer) -> CharacterPhysicsState:
	return CharacterPhysicsState.new(
		Vector3(
			SerdeUtil.POSITION_AXIS_SERDE.deserialize_float_from_u16(serialized_data_stream.get_u16()),
			SerdeUtil.POSITION_Y_AXIS_SERDE.deserialize_float_from_u16(serialized_data_stream.get_u16()),
			SerdeUtil.POSITION_AXIS_SERDE.deserialize_float_from_u16(serialized_data_stream.get_u16())),
		Vector3(
			SerdeUtil.VELOCITY_AXIS_SERDE.deserialize_float_from_u16(serialized_data_stream.get_u16()),
			SerdeUtil.VELOCITY_AXIS_SERDE.deserialize_float_from_u16(serialized_data_stream.get_u16()),
			SerdeUtil.VELOCITY_AXIS_SERDE.deserialize_float_from_u16(serialized_data_stream.get_u16())),
		bool(serialized_data_stream.get_u8()))

func _to_string() -> String:
	return "CharacterPhysicsState<POSITION=%s, VELOCITY=%s, IS_GROUNDED=%s>" % [
		position_,
		velocity_,
		is_grounded_
	]
