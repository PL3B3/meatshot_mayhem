class_name ClientDeathDisplay extends Control

@onready var death_screen_animation_player_: AnimationPlayer = $DeathScreenAnimationPlayer

func play_death_animation() -> void:
	death_screen_animation_player_.stop()
	death_screen_animation_player_.play("death_screen_fade_in")
	show()

func hide_death_display() -> void:
	hide()
