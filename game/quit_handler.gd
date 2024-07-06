extends Node

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)

func _notification(notification_code: int) -> void:
	if notification_code == NOTIFICATION_WM_CLOSE_REQUEST:
		__disconnect_all_peers()
		get_tree().quit()

func __disconnect_all_peers() -> void:
	for connected_peer_id: int in multiplayer.get_peers():
		multiplayer.multiplayer_peer.disconnect_peer(connected_peer_id)
