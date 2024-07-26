class_name SerdeUtil extends RefCounted

static var YAW_DEG_SERDE := FloatToU16SerDe.new(0, 360)
static var PITCH_DEG_SERDE := FloatToU16SerDe.new(-180, 180)
static var POSITION_AXIS_SERDE := FloatToU16SerDe.new(-500, 500)
static var POSITION_Y_AXIS_SERDE := FloatToU16SerDe.new(-10, 50)
static var VELOCITY_AXIS_SERDE := FloatToU16SerDe.new(-100, 100)

class FloatToU16SerDe:
	const UINT16_MAX = (1 << 16) - 1 # 65535

	var float_value_lower_bound: float
	var float_value_upper_bound: float

	func _init(float_value_lower_bound: float, float_value_upper_bound: float) -> void:
		self.float_value_lower_bound = float_value_lower_bound
		self.float_value_upper_bound = float_value_upper_bound

	func serialize_float_to_u16(raw_float_value: float) -> int:
		assert(raw_float_value >= float_value_lower_bound)
		assert(raw_float_value <= float_value_upper_bound)
		var value_range_magnitude: float = float_value_upper_bound - float_value_lower_bound
		var value_normalized_0_to_1: float = (raw_float_value - float_value_lower_bound) / value_range_magnitude
		return int(lerp(0, UINT16_MAX, value_normalized_0_to_1))

	func deserialize_float_from_u16(serialized_float_u16: int) -> float:
		var value_normalized_0_to_1: float = float(serialized_float_u16) / float(UINT16_MAX)
		return lerp(float_value_lower_bound, float_value_upper_bound, value_normalized_0_to_1)
