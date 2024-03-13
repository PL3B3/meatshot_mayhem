extends MultiplayerSpawner
class_name NetworkEntityRegistry

"""
Spawner and registrar of network entities
Cohesion is meh, but convenient b/c spawner auto "registers" nodes b/c they're children
Constructs the entity (it will automatically be added to scene)
Also tells each entity its network mode (OTHER_CLIENT, SERVER, OWN_CLIENT)
"""

var entity_id_to_owner_id_map_: Dictionary = {}
var next_entity_id_: int = 0

func _ready():
	spawn_function = _spawn_function

func spawn_entity(spawn_data: Dictionary) -> NetworkEntity:
	assert(multiplayer.is_server(), "Failed to spawn entity with data %s from client (id: %d). Only the server can spawn entities" % [
		spawn_data, multiplayer.get_unique_id()])
	spawn_data["entity_id"] = next_entity_id_
	next_entity_id_ += 1
	return spawn(spawn_data) as NetworkEntity

func _spawn_function(spawn_data: Dictionary) -> NetworkEntity:
	var entity_id: int = spawn_data["entity_id"]
	var entity_network_owner_id: int = spawn_data["entity_network_owner_id"]
	entity_id_to_owner_id_map_[entity_id] = entity_network_owner_id
	print("Spawning entity with id [%s] owned by [%s]. Self network id: %s." % [
		entity_id, entity_network_owner_id, multiplayer.get_unique_id()])
	var entity_network_mode = identify_network_mode(entity_network_owner_id)
	return CharacterNetworkEntity.new(entity_id, identify_network_mode(entity_network_owner_id))

func identify_network_mode(entity_network_owner_id: int):
	if (multiplayer.is_server()):
		return CONSTANTS.NetworkEntityMode.SERVER
	elif (entity_network_owner_id == multiplayer.get_unique_id()):
		return CONSTANTS.NetworkEntityMode.OWN_CLIENT
	else:
		return CONSTANTS.NetworkEntityMode.OTHER_CLIENT

func filter_out_unspawned_entities_from_world_state(world_state: Dictionary):
	var filtered_world_state = {}
	for entity_id in get_entity_ids():
		if entity_id in world_state:
			filtered_world_state[entity_id] = world_state[entity_id].duplicate(true)

func get_entity_ids() -> Array:
	var entity_ids = []
	for entity: NetworkEntity in get_children():
		entity_ids.append(entity.get_entity_id())
	return entity_ids

func get_entity_ids_for_mode(network_mode) -> Array:
	var entity_ids = []
	for entity: NetworkEntity in get_children():
		if entity.get_network_mode() == network_mode:
			entity_ids.append(entity.get_entity_id())
	return entity_ids

func get_entity(entity_id: int) -> NetworkEntity:
	return get_node(NodePath(str(entity_id)))

func get_network_owner_id_for_entity(entity_id: int) -> int:
	return Utils.get_or_default(
		entity_id_to_owner_id_map_, entity_id, Network.NO_NETWORK_OWNER_ID)
