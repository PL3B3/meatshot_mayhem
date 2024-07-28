extends Node3D

class_name CharacterFirstPersonOutput

const CAMERA_OFFSET_FROM_CHARACTER_ORIGIN = Vector3(0, 0.75, 0)
const CHARACTER_SPEED_RUN_THRESHOLD: float = 20.0

@onready var camera_: Camera3D = $Camera3D
@onready var health_label_: Label = $HealthLabel
@onready var shotgun_: Shotgun = $Camera3D/Shotgun
@onready var animation_tree_: AnimationTree = $AnimationTree

func display_character_state(character_transform: CharacterTransformState, health: int) -> void:
	camera_.transform = compute_camera_transform(character_transform)
	health_label_.text = str(health)

func compute_camera_transform(character_transform: CharacterTransformState) -> Transform3D:
	var camera_position: Vector3 = character_transform.position() + CAMERA_OFFSET_FROM_CHARACTER_ORIGIN
	var mouse_look_rotation_in_euler_angles := Vector3(
		deg_to_rad(character_transform.pitch()), deg_to_rad(character_transform.yaw()), 0)
	var mouse_look_rotation_basis := Basis.from_euler(mouse_look_rotation_in_euler_angles)
	return Transform3D(mouse_look_rotation_basis, camera_position)

func play_walking_audio_blended_by_speed(character_physics_state: CharacterPhysicsState) -> void:
	var walking_audio_blend_ratio: float
	if character_physics_state.is_grounded():
		var current_speed := character_physics_state.velocity().length()
		walking_audio_blend_ratio = clampf(current_speed / CHARACTER_SPEED_RUN_THRESHOLD, 0, 1)
	else:
		walking_audio_blend_ratio = 0
	animation_tree_.set("parameters/BlendResetToFootstepsAudio/blend_amount", walking_audio_blend_ratio)

func play_fire_gun_animation() -> void:
	shotgun_.play_first_person_shoot_animation()

func get_tracer_origin_position() -> Vector3:
	return shotgun_.get_tracer_origin_position()
