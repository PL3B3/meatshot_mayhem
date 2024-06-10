extends Node3D

class_name CharacterThirdPersonDisplay

@onready var eye_pivot_: Node3D = $EyePivot

func display_character_transform(character_transform: CharacterTransformState) -> void:
	position = character_transform.position()
	rotation_degrees.y = character_transform.yaw()
	eye_pivot_.rotation_degrees.x = character_transform.pitch()

