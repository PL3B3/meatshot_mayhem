extends RefCounted
class_name ServerToClientStateSnapshotMessage

enum SERVER_TO_CLIENT_STATE_SNAPSHOT_MESSAGE {
	CLIENT_TICK,
	CLIENT_STATE_SNAPSHOT
}

var client_tick_: int
var client_state_snapshot_: ClientStateSnapshot

func _init(client_tick: int, client_state_snapshot: ClientStateSnapshot):
	client_tick_ = client_tick
	client_state_snapshot_ = client_state_snapshot

func client_tick() -> int:
	return client_tick_

func client_state_snapshot() -> ClientStateSnapshot:
	return client_state_snapshot_

func to_dict() -> Dictionary:
	return {
		SERVER_TO_CLIENT_STATE_SNAPSHOT_MESSAGE.CLIENT_TICK: client_tick_,
		SERVER_TO_CLIENT_STATE_SNAPSHOT_MESSAGE.CLIENT_STATE_SNAPSHOT: client_state_snapshot_.to_dict()
	}

static func from_dict(dict: Dictionary) -> ServerToClientStateSnapshotMessage:
	return ServerToClientStateSnapshotMessage.new(
		dict[SERVER_TO_CLIENT_STATE_SNAPSHOT_MESSAGE.CLIENT_TICK],
		ClientStateSnapshot.from_dict(dict[SERVER_TO_CLIENT_STATE_SNAPSHOT_MESSAGE.CLIENT_STATE_SNAPSHOT])
	)

func _to_string() -> String:
	return "ServerToClientStateSnapshotMessage<CLIENT_TICK=%s, CLIENT_STATE_SNAPSHOT=%s>" % [
		client_tick_,
		client_state_snapshot_    
	]
