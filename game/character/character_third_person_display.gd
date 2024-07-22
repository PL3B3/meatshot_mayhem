extends Node3D

class_name CharacterThirdPersonDisplay

const TICKS_IN_A_SECOND: float = 60
const CHARACTER_SPEED_RUN_THRESHOLD: float = 20

@onready var character_model: DemoCharacterThirdPersonModel = $DemoCharacterModel

var last_position: Vector3 = Vector3.ZERO
var estimated_speed: float = 0.0

func display_character_transform(character_transform: CharacterTransformState) -> void:
	position = character_transform.position()
	rotation_degrees.y = character_transform.yaw()
	character_model.display_character_state(
		character_transform.pitch(),
		__compute_run_blend_ratio(character_transform.position()))
	last_position = character_transform.position()

func play_shoot_animation() -> void:
	character_model.play_shoot_animation()

func __compute_run_blend_ratio(next_position: Vector3) -> float:
	var estimated_speed: float = (next_position - last_position).length() * TICKS_IN_A_SECOND
	return estimated_speed / CHARACTER_SPEED_RUN_THRESHOLD
