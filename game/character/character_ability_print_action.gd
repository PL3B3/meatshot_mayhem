extends AbstractCharacterAbilityAction
class_name CharacterAbilityPrintAction

var client_or_server_: String

func _init(description: String) -> void:
	client_or_server_ = description

func perform_ability(
		_camera_transform: Transform3D,
		_remote_character_position_by_entity_id: Dictionary) -> CharacterAbilityResult:
	print("Ability has been triggered on %s" % client_or_server_)
	return CharacterAbilityResult.EMPTY_RESULT
