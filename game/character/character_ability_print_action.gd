extends Object
class_name CharacterAbilityPrintAction

var client_or_server_: String

func _init(description: String) -> void:
    client_or_server_ = description

func do_ability() -> void:
    print("Ability has been triggered on %s" % client_or_server_)