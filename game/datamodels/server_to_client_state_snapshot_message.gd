extends RefCounted
class_name ServerToClientStateSnapshotMessage

var client_tick_: int
var client_state_snapshot_: ClientStateSnapshot

func _init(client_tick: int, client_state_snapshot: ClientStateSnapshot):
	client_tick_ = client_tick
	client_state_snapshot_ = client_state_snapshot

func client_tick() -> int:
	return client_tick_

func client_state_snapshot() -> ClientStateSnapshot:
	return client_state_snapshot_

func _to_string() -> String:
	return "ServerToClientStateSnapshotMessage<CLIENT_TICK=%s, CLIENT_STATE_SNAPSHOT=%s>" % [
		client_tick_,
		client_state_snapshot_    
	]
