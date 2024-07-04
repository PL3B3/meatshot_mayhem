extends Node

const CLIENT_CONNECT_TIMEOUT := 5

@onready var __ip_address_text_input: LineEdit = $VBoxContainer/IpAddressHBox/IpAddressTextInput
@onready var __invalid_ip_address_label: Label = $VBoxContainer/IpAddressHBox/InvalidIpAddressLabel
@onready var __connection_status_label: Label = $VBoxContainer/ConnectionStatusHBox/StatusLabel
@onready var __client_connect_button: Button = $VBoxContainer/ClientButton
@onready var __server_host_button: Button = $VBoxContainer/ServerButton

func _ready() -> void:
	__client_connect_button.pressed.connect(_on_client_connect_pressed)
	__server_host_button.pressed.connect(_on_host_server_pressed)
	__ip_address_text_input.text_changed.connect(_on_ip_text_input_changed)


func _on_ip_text_input_changed(new_ip_address_text: String) -> void:
	if new_ip_address_text.is_valid_ip_address():
		__client_connect_button.disabled = false
		__invalid_ip_address_label.hide()
	else:
		__client_connect_button.disabled = true
		__invalid_ip_address_label.show()

func _on_client_connect_pressed() -> void:
	__try_start_client()

func _on_host_server_pressed() -> void:
	__try_start_server()

func __try_start_server() -> bool:
	__disable_ui_interaction()
	var server_multiplayer_peer := ENetMultiplayerPeer.new()
	var create_server_result_status := server_multiplayer_peer.create_server(Network.PORT)
	if create_server_result_status == OK: 
		multiplayer.multiplayer_peer = server_multiplayer_peer
		__connection_status_label.text = "SUCCESSFULLY STARTED SERVER"
		get_tree().change_scene_to_file("res://game/server.tscn")
		return true
	else:
		__connection_status_label.text = "FAILED TO CREATE SERVER. ERROR CODE: %d" % create_server_result_status
		server_multiplayer_peer.close()
		__enable_ui_interaction()
		return false

func __try_start_client() -> bool:
	var server_ip := __ip_address_text_input.text
	assert(server_ip.is_valid_ip_address(), "Cannot connect to server with invalid IP %s" % server_ip)
	
	__disable_ui_interaction()
	var client_multiplayer_peer := ENetMultiplayerPeer.new()
	__connection_status_label.text = "ATTEMPTING TO CONNECT TO SERVER %s" % server_ip
	var connect_client_result_status := client_multiplayer_peer.create_client(server_ip, Network.PORT)
	if connect_client_result_status == OK: 
		multiplayer.multiplayer_peer = client_multiplayer_peer
		var connected_latch := TimeoutLatch.new(multiplayer.connected_to_server, get_tree(), CLIENT_CONNECT_TIMEOUT)
		var connected_successfully := await connected_latch.complete_or_timeout()
		if connected_successfully:
			__connection_status_label.text = "SUCCESSFULLY CONNECTED TO SERVER %s" % server_ip
			get_tree().change_scene_to_file("res://game/client.tscn")
			return true
		else:
			__connection_status_label.text = "TIMED OUT TRYING TO CONNECT TO SERVER %s" % server_ip
			multiplayer.multiplayer_peer = null
			client_multiplayer_peer.close()
			__enable_ui_interaction()
			return false
	else:
		__connection_status_label.text = "FAILED TO CONNECT TO SERVER %s. ERROR CODE: %d" % [
			server_ip, connect_client_result_status]
		client_multiplayer_peer.close()
		__enable_ui_interaction()
		return false

func __disable_ui_interaction() -> void:
	__ip_address_text_input.editable = false
	__client_connect_button.disabled = true
	__server_host_button.disabled = true

func __enable_ui_interaction() -> void:
	__ip_address_text_input.editable = true
	__client_connect_button.disabled = false
	__server_host_button.disabled = false

class TimeoutLatch:
	signal complete

	var __timed_out := false

	func _init(complete_signal: Signal, scene_tree: SceneTree, timeout: int) -> void:
		scene_tree.create_timer(timeout).timeout.connect(__timeout)
		complete_signal.connect(__complete)

	func complete_or_timeout() -> bool:
		await self.complete
		return !__timed_out

	func __complete() -> void:
		complete.emit()
	
	func __timeout() -> void:
		__timed_out = true
		complete.emit()
