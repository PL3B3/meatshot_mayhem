class_name NetworkMessageAndEventBus extends Node

const SERVER_NETWORK_ID = 1

signal received_authoritative_state_snapshot(server_tick: int, snapshot: ServerToClientStateSnapshotMessage)
signal received_client_trigger(client_id: int, camera_transform: Transform3D, server_tick_displayed_on_client: int)
signal received_client_input(client_id: int, message: InputState)
signal triggered_remote_character_ability(
	remote_character_entity_id: int, 
	camera_transform: Transform3D,  
	server_tick: int)
signal client_disconnected(client_id: int)
signal client_connected(client_id: int)
signal server_disconnected()
signal respawned()
signal died()


func _ready() -> void:
	name = "NetworkBus"
	multiplayer.peer_connected.connect(__on_client_connected)
	multiplayer.peer_disconnected.connect(func(client_id: int) -> void: client_disconnected.emit(client_id))
	multiplayer.server_disconnected.connect(func() -> void: server_disconnected.emit())

func notify_client_of_death(client_id: int) -> void:
	__handle_death.rpc_id(client_id)

func notify_client_of_respawn(client_id: int) -> void:
	__handle_respawn.rpc_id(client_id)

func send_state_snapshot_to_client(client_id: int, tick: int, snapshot: ServerToClientStateSnapshotMessage) -> void:
	s2c.rpc_id(client_id, tick, snapshot.to_dict())

# Raw generic Array is used instead of Array[PackedByteArray] due to a strange static typing issue with RPCs
func send_inputs_to_server(input_messages: Array) -> void:
	c2s.rpc_id(SERVER_NETWORK_ID, input_messages)

func send_trigger_to_server(camera_transform: Transform3D, server_tick_displayed: int) -> void:
	ct2s.rpc_id(SERVER_NETWORK_ID, camera_transform, server_tick_displayed)

func trigger_remote_character_ability(
	remote_character_entity_id: int,
	camera_transform: Transform3D, 
	server_tick: int
) -> void:
	__trigger_remote_character_ability.rpc(remote_character_entity_id, camera_transform, server_tick)

func verify_is_connected_to_server() -> void:
	assert(multiplayer.get_peers().size() > 0, "Client is not connected to server.")

func get_unique_multiplayer_id() -> int:
	return multiplayer.get_unique_id()

func quit_to_client_menu() -> void:
	multiplayer.multiplayer_peer.disconnect_peer(1)
	get_tree().change_scene_to_file("res://game/main.tscn")

# Name is shortened to make the RPC packet size smaller
@rpc("any_peer", "call_remote", "unreliable")
func c2s(serialized_inputs: Array) -> void:
	for serialized_input: PackedByteArray in serialized_inputs:
		var client_input := InputState.deserialize(serialized_input)
		received_client_input.emit(multiplayer.get_remote_sender_id(), client_input)

# Name is shortened to make the RPC packet size smaller
@rpc("any_peer", "call_remote", "reliable")
func ct2s(camera_transform: Transform3D, server_tick_displayed: int) -> void:
	received_client_trigger.emit(multiplayer.get_remote_sender_id(), camera_transform, server_tick_displayed)

# Name is shortened to make the RPC packet size smaller
@rpc("authority", "call_remote", "unreliable")
func s2c(state_snapshot_server_tick: int, serialized_state_snapshot: Dictionary) -> void:
	var deserialized_state_snapshot := ServerToClientStateSnapshotMessage.from_dict(serialized_state_snapshot)
	received_authoritative_state_snapshot.emit(state_snapshot_server_tick, deserialized_state_snapshot)

@rpc("authority", "call_remote", "reliable")
func __handle_death() -> void:
	died.emit()

@rpc("authority", "call_remote", "reliable")
func __handle_respawn() -> void:
	respawned.emit()

@rpc("authority", "call_remote", "reliable")
func __trigger_remote_character_ability(
	remote_character_entity_id: int,
	camera_transform: Transform3D, 
	server_tick: int
) -> void:
	triggered_remote_character_ability.emit(remote_character_entity_id, camera_transform, server_tick)

@rpc("authority", "call_remote", "reliable")
func __resize_window_for_debugging(index: int = 0) -> void:
	if OS.is_debug_build():
		var screen_size: Vector2 = DisplayServer.screen_get_size()
		get_window().size = Vector2(screen_size.x / 2.01, screen_size.y / 2)
		get_window().position = Vector2(screen_size.x + (index * (screen_size.x * 0.5)), 0)

func __on_client_connected(client_id: int) -> void:
	if multiplayer.is_server():
		var prior_peer_count: int = multiplayer.get_peers().size() - 1
		__resize_window_for_debugging.rpc_id(client_id, prior_peer_count)
		__resize_server_window_for_debugging(prior_peer_count)
		client_connected.emit(client_id)

func __resize_server_window_for_debugging(index: int = 0)  -> void:
	if OS.is_debug_build():
		var screen_size: Vector2 = DisplayServer.screen_get_size()
		get_window().size = Vector2(screen_size.x / 2, screen_size.y / 2)
		get_window().position = Vector2(screen_size.x * 1.5, index * (screen_size.y / 2))
