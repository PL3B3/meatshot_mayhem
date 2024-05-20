extends Node

class_name NetworkMessenger

const SERVER_NETWORK_ID = 1
const SEND_INTERVAL_USEC = "send_interval_USEC"
const RECV_INTERVAL_USEC = "recv_interval_USEC"

signal received_server_message(message)
signal received_client_message(sender_id, message)

func _ready():
	LogsAndMetrics.add_client_stat(SEND_INTERVAL_USEC, 1000, true) 
	LogsAndMetrics.add_server_stat(RECV_INTERVAL_USEC, 1000, true)

@rpc("any_peer", "call_remote", "reliable")
func _handle_message_from_client(message):
	LogsAndMetrics.add_sample(RECV_INTERVAL_USEC, Time.get_ticks_usec())
	emit_signal("received_client_message", multiplayer.get_remote_sender_id(), message)

@rpc("authority", "call_remote", "reliable")
func _handle_message_from_server(message):
	emit_signal("received_server_message", message)

func send_message_to_client(client_network_id, message):
	_handle_message_from_server.rpc_id(client_network_id, message)

func send_message_to_server(message):
	LogsAndMetrics.add_sample(SEND_INTERVAL_USEC, Time.get_ticks_usec())
	_handle_message_from_client.rpc_id(SERVER_NETWORK_ID, message)
