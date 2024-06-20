extends Node
class_name EntitySpawner

const DUMMY_DICTIONARY_VALUE := true
const TRACER_DISPLAYER_SCENE := preload("res://game/tracer_displayer.tscn")

var client_own_character_: CharacterComponents
var character_components_per_entity_id_ := {}
var tracer_displayer_: TracerDisplayer
var debug_sphere_displayer_: DebugSphereDisplayer

func get_or_spawn_client_own_character() -> CharacterComponents:
	if client_own_character_ != null:
		return client_own_character_
	else:
		var character_components := CharacterComponents.create_for_network_mode(CONSTANTS.NetworkEntityMode.OWN_CLIENT)
		add_child(character_components)
		client_own_character_ = character_components
		return character_components

func get_or_spawn_character(entity_id: int, network_mode: int) -> CharacterComponents:
	if entity_id in character_components_per_entity_id_:
		return character_components_per_entity_id_[entity_id]
	else:
		var character_components := CharacterComponents.create_for_network_mode(network_mode)
		add_child(character_components)
		character_components_per_entity_id_[entity_id] = character_components
		return character_components

func get_or_create_tracer_displayer() -> TracerDisplayer:
	if tracer_displayer_ == null:
		var tracer_displayer: TracerDisplayer = TRACER_DISPLAYER_SCENE.instantiate()
		add_child(tracer_displayer)
		tracer_displayer_ = tracer_displayer
	return tracer_displayer_

func get_or_create_debug_sphere_displayer() -> DebugSphereDisplayer:
	if debug_sphere_displayer_ == null:
		var debug_sphere_displayer: DebugSphereDisplayer = DebugSphereDisplayer.new()
		add_child(debug_sphere_displayer)
		debug_sphere_displayer_ = debug_sphere_displayer
	return debug_sphere_displayer_

func despawn_entities_not_in_client_snapshot(client_state_snapshot: ClientStateSnapshot) -> void:
	var entity_ids_in_snapshot: Dictionary = {}
	for remote_character_entity_id: int in client_state_snapshot.remote_character_states():
		entity_ids_in_snapshot[remote_character_entity_id] = DUMMY_DICTIONARY_VALUE
	__despawn_entities(entity_ids_in_snapshot)

func despawn_entities_not_in_server_snapshot(server_state_snapshot: Dictionary) -> void:
	var entity_ids_in_snapshot: Dictionary = {}
	for character_entity_id: int in server_state_snapshot.keys():
		entity_ids_in_snapshot[character_entity_id] = DUMMY_DICTIONARY_VALUE
	__despawn_entities(entity_ids_in_snapshot)

func __despawn_entities(entity_ids_in_latest_snapshot_set: Dictionary) -> void:
	# iterate over keys because it's dangerous to remove from a map while iterating over it
	for currently_spawned_character_entity_id: int in character_components_per_entity_id_.keys():
		if not currently_spawned_character_entity_id in entity_ids_in_latest_snapshot_set:
			var character_to_despawn: CharacterComponents = (
				character_components_per_entity_id_[currently_spawned_character_entity_id])
			character_components_per_entity_id_.erase(currently_spawned_character_entity_id)
			remove_child(character_to_despawn)
			character_to_despawn.queue_free()
