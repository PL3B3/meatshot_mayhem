class_name RemoteCharacterDeathDisplay extends Node3D

const DEATH_DISPLAY_SCENE := preload("res://game/character/remote_character_death_display.tscn")

@onready var __fade_animation_player: AnimationPlayer = $AnimationPlayer
@onready var __body_pitch_pivot: Node3D = $ScaleAndHeightOffset/BodyPitchPivot

static func create_instance() -> RemoteCharacterDeathDisplay:
	return DEATH_DISPLAY_SCENE.instantiate()

func display_character_transform(character_transform: CharacterTransformState) -> void:
	position = character_transform.position()
	rotation_degrees.y = character_transform.yaw()
	__body_pitch_pivot.rotation_degrees.x = character_transform.pitch()
	
	__fade_animation_player.animation_finished.connect(__on_fade_animation_finished)
	__fade_animation_player.play("death_fade")

func __on_fade_animation_finished(__: String) -> void:
	queue_free()
