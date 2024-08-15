class_name RemoteCharacterAbilityTrigger extends RefCounted

var remote_character_entity_id: int
var camera_transform: Transform3D
var server_tick: int

func _init(
    remote_character_entity_id: int, 
    camera_transform: Transform3D, 
    server_tick: int
) -> void:
    self.remote_character_entity_id = remote_character_entity_id
    self.camera_transform = camera_transform
    self.server_tick = server_tick

func serialize() -> PackedByteArray:
    var serialized_data_stream := StreamPeerBuffer.new()
    serialized_data_stream.put_u8(remote_character_entity_id)
    serialized_data_stream.put_var(camera_transform)
    serialized_data_stream.put_u8(server_tick)
    return serialized_data_stream.data_array

static func deserialize(serialized_data: PackedByteArray) -> RemoteCharacterAbilityTrigger:
    var serialized_data_stream := StreamPeerBuffer.new()
    serialized_data_stream.data_array = serialized_data
    return RemoteCharacterAbilityTrigger.new(
        serialized_data_stream.get_u8(),
        serialized_data_stream.get_var(),
        serialized_data_stream.get_u8())