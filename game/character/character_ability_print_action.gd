extends AbstractCharacterAbilityAction
class_name CharacterAbilityPrintAction

var client_or_server_: String

func _init(description: String) -> void:
	client_or_server_ = description

func perform_ability(
		_camera_transform: Transform3D,
		_remote_character_positions: Array[Vector3]) -> void:
	print("Ability has been triggered on %s" % client_or_server_)
