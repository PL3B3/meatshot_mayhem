extends Node3D

class_name CharacterThirdPersonDisplay

const TICKS_IN_A_SECOND: float = 60
const CHARACTER_SPEED_RUN_THRESHOLD: float = 20

@onready var character_model: DemoCharacterThirdPersonModel = $DemoCharacterModel

var last_position: Vector3 = Vector3.ZERO
var estimated_speed: float = 0.0
var ticks_since_last_blink: int = 0
var rng := RandomNumberGenerator.new()

func display_character_transform(character_transform: CharacterTransformState) -> void:
	position = character_transform.position()
	rotation_degrees.y = character_transform.yaw()
	character_model.display_character_state(
		character_transform.pitch(),
		__compute_run_blend_ratio(character_transform.position()))
	__randomly_blink()

func play_shoot_animation() -> void:
	character_model.play_shoot_animation()

func get_tracer_origin_position() -> Vector3:
	return character_model.get_tracer_origin_position()

func __compute_run_blend_ratio(next_position: Vector3) -> float:
	var estimated_speed: float = (next_position - last_position).length() * TICKS_IN_A_SECOND
	last_position = next_position
	return estimated_speed / CHARACTER_SPEED_RUN_THRESHOLD

func __randomly_blink() -> void:
	ticks_since_last_blink += 1
	if ticks_since_last_blink > 60 and rng.randf() > 0.99:
		character_model.play_blink_animation()
		ticks_since_last_blink = 0
