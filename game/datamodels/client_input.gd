extends Object
class_name ClientInput

enum CLIENT_INPUT {
	INPUT_STATE,
	IS_TRIGGERED,
	DISPLAYED_SERVER_TICK_AT_TIME_OF_TRIGGER
}

var input_state_: InputState
var is_triggered_: bool
var displayed_server_tick_at_time_of_trigger_: int

func _init(input_state: InputState, is_triggered: bool, displayed_server_tick_at_time_of_trigger: int) -> void:
	input_state_ = input_state
	is_triggered_ = is_triggered
	displayed_server_tick_at_time_of_trigger_ = displayed_server_tick_at_time_of_trigger

func input_state() -> InputState:
	return input_state_

func is_triggered() -> bool:
	return is_triggered_

func displayed_server_tick_at_time_of_trigger() -> int:
	return displayed_server_tick_at_time_of_trigger_

func to_dict() -> Dictionary:
	return {
		CLIENT_INPUT.INPUT_STATE: input_state_.to_dict(),
		CLIENT_INPUT.IS_TRIGGERED: is_triggered_,
		CLIENT_INPUT.DISPLAYED_SERVER_TICK_AT_TIME_OF_TRIGGER: displayed_server_tick_at_time_of_trigger_
	}

static func from_dict(dict: Dictionary) -> ClientInput:
	return ClientInput.new(
		InputState.from_dict(dict[CLIENT_INPUT.INPUT_STATE]),
		dict[CLIENT_INPUT.IS_TRIGGERED],
		dict[CLIENT_INPUT.DISPLAYED_SERVER_TICK_AT_TIME_OF_TRIGGER]
	)

func _to_string() -> String:
	return "ClientInput<INPUT_STATE=%s, IS_TRIGGERED=%s, DISPLAYED_SERVER_TICK_AT_TIME_OF_TRIGGER=%s>" % [
		input_state_,
		is_triggered_,
		displayed_server_tick_at_time_of_trigger_
	]
