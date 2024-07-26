class_name SerdeUtil extends RefCounted

const MIN_PITCH: float = -90.0
const MAX_PITCH: float = 90.0
const MIN_YAW: float = 0.0
const MAX_YAW: float = 360.0
const UINT16_MAX = (1 << 16) - 1 # 65535

static func position_axis_to_u16(position_axis_value: float) -> int:
	var position_normalized_0_to_1: float = clamp((position_axis_value - (-500)) / 1000, 0, 1)
	return int(lerp(0, UINT16_MAX, position_normalized_0_to_1))

static func u16_to_position_axis(position_axis_as_u16: int) -> float:
	var position_normalized_0_to_1: float = float(position_axis_as_u16) / UINT16_MAX
	return lerp(-500, 500, position_normalized_0_to_1)

static func pitch_to_u16(pitch_deg: float) -> int:
	var pitch_normalized_0_to_1: float = clamp((pitch_deg - MIN_PITCH) / (MAX_PITCH - MIN_PITCH), 0, 1)
	return int(lerp(0, UINT16_MAX, pitch_normalized_0_to_1))

static func u16_to_pitch(pitch_as_u16: int) -> float:
	var pitch_normalized_0_to_1: float = float(pitch_as_u16) / float(UINT16_MAX)
	return lerp(MIN_PITCH, MAX_PITCH, pitch_normalized_0_to_1)

static func yaw_to_u16(yaw_deg: float) -> int:
	var yaw_normalized_0_to_1: float = clamp((yaw_deg - MIN_YAW) / (MAX_YAW - MIN_YAW), 0, 1)
	return int(lerp(0, UINT16_MAX, yaw_normalized_0_to_1))

static func u16_to_yaw(yaw_as_u16: int) -> float:
	var yaw_normalized_0_to_1: float = float(yaw_as_u16) / float(UINT16_MAX)
	return lerp(MIN_YAW, MAX_YAW, yaw_normalized_0_to_1)