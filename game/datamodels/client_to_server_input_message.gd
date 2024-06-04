extends Object
class_name ClientToServerInputMessage

enum CLIENT_TO_SERVER_INPUT_MESSAGE {
	CLIENT_TICK,
	INPUT_STATE
}

var client_tick_: int
var input_state_: InputState

func _init(client_tick: int, input_state: InputState) -> void:
	client_tick_ = client_tick
	input_state_ = input_state

func client_tick() -> int:
	return client_tick_

func input_state() -> InputState:
	return input_state_

func to_dict() -> Dictionary:
	return {
		CLIENT_TO_SERVER_INPUT_MESSAGE.CLIENT_TICK: client_tick_,
		CLIENT_TO_SERVER_INPUT_MESSAGE.INPUT_STATE: input_state_.to_dict()
	}

static func from_dict(dict: Dictionary) -> ClientToServerInputMessage:
	return ClientToServerInputMessage.new(
		dict[CLIENT_TO_SERVER_INPUT_MESSAGE.CLIENT_TICK],
		InputState.from_dict(dict[CLIENT_TO_SERVER_INPUT_MESSAGE.INPUT_STATE])
	)

func _to_string() -> String:
	return "ClientToServerInputMessage<CLIENT_TICK=%s, INPUT_STATE=%s>" % [
		client_tick_,
		input_state_
	]