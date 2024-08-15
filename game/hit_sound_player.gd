class_name HitSoundPlayer extends AudioStreamPlayer

const MIN_VOLUME: float = -5
const MAX_VOLUME: float = 5
const DAMAGE_SCALE: float = 100

func play_hit_sound(damage: int) -> void:
	volume_db = lerp(MIN_VOLUME, MAX_VOLUME, damage / DAMAGE_SCALE)
	pitch_scale = 1.0 - pow(damage / DAMAGE_SCALE, 2)
	play()
