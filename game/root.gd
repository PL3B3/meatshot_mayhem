extends Control

func _ready():
	if start_server():
		# hacky: server already created, so create client instead
		get_tree().change_scene_to_file("res://game/client.tscn")
	else:
		get_tree().change_scene_to_file("res://game/server.tscn")

func start_server() -> bool:
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(Network.PORT)
	if error: 
		return true
	multiplayer.multiplayer_peer = peer
	return false

func _on_connected_ok():
	var peer_id = multiplayer.get_unique_id()

func _on_connected_fail():
	multiplayer.multiplayer_peer = null

func _on_server_disconnected():
	multiplayer.multiplayer_peer = null
