extends Node3D

class_name CharacterFirstPersonOutput

const CAMERA_OFFSET_FROM_CHARACTER_ORIGIN = Vector3(0, 0.75, 0)

@onready var camera_ = $Camera3D

func display_character_state(character_position: Vector3, yaw_deg: float, pitch_deg: float):
	camera_.global_position = character_position + CAMERA_OFFSET_FROM_CHARACTER_ORIGIN
	var camera_rotation_in_euler_angles = Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0)
	camera_.basis = Quaternion.from_euler(camera_rotation_in_euler_angles)
