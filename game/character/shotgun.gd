class_name Shotgun extends Node3D

@onready var shoot_animation_player_: AnimationPlayer = $ShootAnimationPlayer
@onready var gun_model_: MeshInstance3D = $GunModel

func play_first_person_shoot_animation() -> void:
	shoot_animation_player_.stop()
	shoot_animation_player_.play("shoot_first_person")

func play_third_person_shoot_animation() -> void:
	shoot_animation_player_.stop()
	shoot_animation_player_.play("shoot_third_person")

func get_tracer_origin_position() -> Vector3:
	return gun_model_.global_position
