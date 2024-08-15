class_name HitSoundPlayer extends AudioStreamPlayer

const DAMAGE_SCALE: float = 100

func play_hit_sound(damage: int) -> void:
	pitch_scale = 1.0 - pow(damage / DAMAGE_SCALE, 2)
	play()
