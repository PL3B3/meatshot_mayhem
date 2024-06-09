extends Node3D

class_name CharacterFirstPersonOutput

const CAMERA_OFFSET_FROM_CHARACTER_ORIGIN = Vector3(0, 0.75, 0)

@onready var camera_ = $Camera3D

func display_character_transform(character_transform: CharacterTransformState) -> Transform3D:
	camera_.global_position = character_transform.position() + CAMERA_OFFSET_FROM_CHARACTER_ORIGIN
	var camera_rotation_in_euler_angles = Vector3(
		deg_to_rad(character_transform.pitch()), deg_to_rad(character_transform.yaw()), 0)
	camera_.basis = Quaternion.from_euler(camera_rotation_in_euler_angles)
	camera_.make_current()
	return camera_.global_transform
