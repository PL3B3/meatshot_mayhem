extends Object
class_name ClientInput

enum CLIENT_INPUT {
	INPUT_STATE,
	IS_TRIGGERED
}

var input_state_: InputState
var is_triggered_: bool

func _init(input_state: InputState, is_triggered: bool):
	input_state_ = input_state
	is_triggered_ = is_triggered

func input_state() -> InputState:
	return input_state_

func is_triggered() -> bool:
	return is_triggered_

func to_dict() -> Dictionary:
	return {
		CLIENT_INPUT.INPUT_STATE: input_state_.to_dict(),
		CLIENT_INPUT.IS_TRIGGERED: is_triggered_
	}

static func from_dict(dict: Dictionary) -> ClientInput:
	return ClientInput.new(
		InputState.from_dict(dict[CLIENT_INPUT.INPUT_STATE]),
		dict[CLIENT_INPUT.IS_TRIGGERED]
	)

func _to_string() -> String:
	return "ClientInput<INPUT_STATE=%s, IS_TRIGGERED=%s>" % [
		input_state_,
		is_triggered_    
	]