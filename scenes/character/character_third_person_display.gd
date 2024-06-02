extends Node3D

class_name CharacterThirdPersonDisplay

@onready var mesh = $Body

func display_character_transform(character_transform: CharacterTransformState):
	mesh.global_position = character_transform.position()
	var character_rotation_in_euler_angles = Vector3(
		deg_to_rad(character_transform.pitch()), deg_to_rad(character_transform.yaw()), 0)
	mesh.basis = Quaternion.from_euler(character_rotation_in_euler_angles)

