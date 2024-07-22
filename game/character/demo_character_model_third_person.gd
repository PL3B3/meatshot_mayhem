class_name DemoCharacterThirdPersonModel extends Node3D

@onready var animation_tree_: AnimationTree = $AnimationTree
@onready var shotgun_: Shotgun = $BodyPitchPivot/BodyWaddlePivot/SmootherBody/Shotgun
@onready var blink_animation_player_: AnimationPlayer = $BlinkAnimationPlayer

func display_character_state(pitch_deg: float, speed: float) -> void:
	$BodyPitchPivot.rotation_degrees.x = pitch_deg
	animation_tree_.set("parameters/BlendIdleWalk/blend_amount", clampf(speed, 0, 1))

func play_shoot_animation() -> void:
	shotgun_.play_third_person_shoot_animation()

func play_blink_animation() -> void:
	blink_animation_player_.stop()
	blink_animation_player_.play("blink")

func get_tracer_origin_position() -> Vector3:
	return shotgun_.get_tracer_origin_position()
