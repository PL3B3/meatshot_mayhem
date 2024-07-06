extends RefCounted
class_name ClientToServerInputMessage

enum CLIENT_TO_SERVER_INPUT_MESSAGE {
	CLIENT_TICK,
	CLIENT_INPUT
}

var client_tick_: int
var client_input_: ClientInput

func _init(client_tick: int, client_input: ClientInput) -> void:
	client_tick_ = client_tick
	client_input_ = client_input

func client_tick() -> int:
	return client_tick_

func client_input() -> ClientInput:
	return client_input_

func to_dict() -> Dictionary:
	return {
		CLIENT_TO_SERVER_INPUT_MESSAGE.CLIENT_TICK: client_tick_,
		CLIENT_TO_SERVER_INPUT_MESSAGE.CLIENT_INPUT: client_input_.to_dict()
	}

static func from_dict(dict: Dictionary) -> ClientToServerInputMessage:
	return ClientToServerInputMessage.new(
		dict[CLIENT_TO_SERVER_INPUT_MESSAGE.CLIENT_TICK],
		ClientInput.from_dict(dict[CLIENT_TO_SERVER_INPUT_MESSAGE.CLIENT_INPUT])
	)

func _to_string() -> String:
	return "ClientToServerInputMessage<CLIENT_TICK=%s, CLIENT_INPUT=%s>" % [
		client_tick_,
		client_input_
	]
