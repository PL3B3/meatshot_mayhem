extends Node3D

class_name CharacterThirdPersonDisplay

@onready var mesh = $Body

func display_character_state(character_position: Vector3, yaw_deg: float, pitch_deg: float):
	mesh.global_position = character_position
	var character_rotation_in_euler_angles = Vector3(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg), 0)
	mesh.basis = Quaternion.from_euler(character_rotation_in_euler_angles)
