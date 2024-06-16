extends Node3D
class_name AbstractCharacterAbilityAction

func perform_ability(
		_camera_transform: Transform3D,
		_remote_character_positions: Array[Vector3]) -> CharacterAbilityResult:
	assert(false, "Child classes must override this method")
	return CharacterAbilityResult.EMPTY_RESULT
