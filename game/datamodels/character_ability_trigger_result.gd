extends Object
class_name CharacterAbilityTriggerResult

var is_triggered: bool
var next_trigger_state: CharacterAbilityTriggerState

func _init(is_triggered: bool, next_trigger_state: CharacterAbilityTriggerState) -> void:
    self.is_triggered = is_triggered
    self.next_trigger_state = next_trigger_state