extends Node3D

class_name CharacterFirstPersonOutput

const CAMERA_OFFSET_FROM_CHARACTER_ORIGIN = Vector3(0, 0.75, 0)

@onready var camera_: Camera3D = $Camera3D

func display_character_transform(character_transform: CharacterTransformState) -> void:
	camera_.transform = compute_camera_transform(character_transform)

func compute_camera_transform(character_transform: CharacterTransformState) -> Transform3D:
	var camera_position: Vector3 = character_transform.position() + CAMERA_OFFSET_FROM_CHARACTER_ORIGIN
	var mouse_look_rotation_in_euler_angles := Vector3(
		deg_to_rad(character_transform.pitch()), deg_to_rad(character_transform.yaw()), 0)
	var mouse_look_rotation_basis := Basis.from_euler(mouse_look_rotation_in_euler_angles)
	return Transform3D(mouse_look_rotation_basis, camera_position)