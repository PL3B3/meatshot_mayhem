extends Node

const EMPTY_PHYSICS_STATE = {}
const SPAWN_POINT_RANDOM_VARIATION = 5
const SPAWN_POINT = Vector3(0, -1.5, 0)
const OVERWRITE_EXISTING = true
const RESPAWN_TIME_IN_TICKS := 300
static var DEFAULT_PHYSICS_STATE := CharacterPhysicsState.new(SPAWN_POINT, Vector3.ZERO, false)
static var CLIENT_INPUT_BUFFER_FACTORY: Callable = func(x: int) -> OrderedInputBuffer: 
	return OrderedInputBuffer.new("sv_input_buf[%10d]" % x)
static var EMPTY_ABILITY_TRIGGER_STATE := CharacterAbilityTriggerState.new(0)

@onready var map_spawner: MultiplayerSpawner = $MapSpawner
@onready var entity_spawner_: EntitySpawner= $EntitySpawner
@onready var entity_creator_ := EntityCreator.new(entity_spawner_)

var network_message_bus_: NetworkMessageAndEventBus
var client_resources_per_peer_id_ := {}
var world_state_per_server_tick_ := {}
var world_state_ := {}
var tick_ := 0

func _ready() -> void:
	network_message_bus_ = NetworkMessageAndEventBus.new()
	network_message_bus_.received_client_input.connect(__handle_client_input)
	network_message_bus_.client_disconnected.connect(__on_client_disconnected)
	network_message_bus_.client_connected.connect(__on_client_connected)
	add_child(network_message_bus_)
	map_spawner.spawn(null)

func _physics_process(_delta: float) -> void:
	for client_id: int in client_resources_per_peer_id_:
		var client_resources: ClientResources = client_resources_per_peer_id_[client_id]
		var is_just_respawned := client_resources.advance_respawn_timer()
		if is_just_respawned:
			network_message_bus_.notify_client_of_respawn(client_id)

	var tracer_displayer := entity_spawner_.get_or_create_tracer_displayer()
	var debug_sphere_displayer := entity_spawner_.get_or_create_debug_sphere_displayer()
	var character_resource_per_client_id := __prepare_character_resource_per_client_id(
		client_resources_per_peer_id_, world_state_)
	var hitscan_results := __compute_hitscan_ability_results(
		world_state_, world_state_per_server_tick_, character_resource_per_client_id)
	var next_world_state := __compute_next_state_for_characters(character_resource_per_client_id, hitscan_results)
	var data_to_export_per_client := __compile_data_to_export_per_client(
		character_resource_per_client_id, next_world_state)

	__display_character_states(character_resource_per_client_id, next_world_state)
	__draw_bullet_tracers(tracer_displayer, hitscan_results)
	__draw_bullet_hits(debug_sphere_displayer, hitscan_results)

	for client_id: int in character_resource_per_client_id:
		var character_resource: ServerCharacterResource = character_resource_per_client_id[client_id]
		var character_entity_id := character_resource.character_entity_id
		var next_character_state: ServerCharacterState = next_world_state[character_entity_id]
		if next_character_state.health_state().health() <= 0:
			next_world_state.erase(next_character_state)
			var client_resources: ClientResources = client_resources_per_peer_id_[client_id]
			if client_resources != null:
				client_resources.despawn()
				network_message_bus_.notify_client_of_death(client_id)

	entity_spawner_.despawn_entities_not_in_server_snapshot(next_world_state)
	__replicate_ability_trigger_on_remote_characters(character_resource_per_client_id)
	__export_state_snapshots_to_clients(data_to_export_per_client)
	world_state_ = next_world_state
	
	world_state_per_server_tick_[tick_] = next_world_state
	__clear_old_world_states()
	tick_ += 1

func __clear_old_world_states() -> void:
	for old_tick: int in world_state_per_server_tick_.keys():
		if old_tick < tick_ - 100:
			world_state_per_server_tick_.erase(old_tick)

func __initialize_resources_for_new_client(client_id: int) -> void:
	var client_character_entity: CharacterEntity = entity_creator_.create_character_entity()
	var input_buffer_for_client: OrderedInputBuffer = CLIENT_INPUT_BUFFER_FACTORY.call(client_id)
	var client_resources: ClientResources = ClientResources.new(
		input_buffer_for_client, client_character_entity, entity_creator_)
	client_resources_per_peer_id_[client_id] = client_resources

func __replicate_ability_trigger_on_remote_characters(character_resource_per_client_id: Dictionary) -> void:
	for client_id: int in character_resource_per_client_id:
		var character_resource: ServerCharacterResource = character_resource_per_client_id[client_id]
		if character_resource.input.is_triggered():
			var character_components := character_resource.character_components
			var latest_input_state := character_resource.input.input_state()
			var character_transform_state := CharacterTransformState.new(
				character_resource.character_state.physics_state().position(), 
				latest_input_state.pitch(), 
				latest_input_state.yaw())
			var character_camera_transform: Transform3D = (
				character_components.first_person_display().compute_camera_transform(character_transform_state))
			network_message_bus_.trigger_ability_for_remote_character(
				character_resource.character_entity_id, character_camera_transform, tick_)

func __export_state_snapshots_to_clients(data_to_export_per_client: Dictionary) -> Dictionary:
	var state_snapshots_for_clients: Dictionary = {}
	for client_id: int in data_to_export_per_client:
		var client_snapshot_data: PerClientExportedData = data_to_export_per_client[client_id]
		var remote_character_state_per_entity: Dictionary = __extract_states_for_remote_characters(
			data_to_export_per_client, client_id)
		var client_own_character_state := ClientOwnCharacterState.new(
			client_snapshot_data.physics_state, 
			EMPTY_ABILITY_TRIGGER_STATE, 
			client_snapshot_data.health_state,
			InputState.DEFAULT)
		var state_snapshot_for_client := ServerToClientStateSnapshotMessage.new(
			client_snapshot_data.client_tick, 
			ClientStateSnapshot.new(client_own_character_state, remote_character_state_per_entity))
		network_message_bus_.send_state_snapshot_to_client(client_id, tick_, state_snapshot_for_client)
	return state_snapshots_for_clients

func __handle_client_input(client_id: int, input: ClientToServerInputMessage) -> void:
	if client_id in client_resources_per_peer_id_:
		var client_resources: ClientResources = client_resources_per_peer_id_[client_id]
		var input_buffer_for_client: OrderedInputBuffer = client_resources.input_buffer
		input_buffer_for_client.push(input.client_input(), input.client_tick())
	else:
		print("Cannot enqueue input %s from client %d. No input buffer initialized." % [input, client_id])

func __on_client_connected(id: int) -> void:
	__initialize_resources_for_new_client(id)
	network_message_bus_.resize_server_and_client_window_for_debugging(id)

func __on_client_disconnected(id: int) -> void:
	client_resources_per_peer_id_.erase(id)

static func __prepare_character_resource_per_client_id(
	client_resources_per_peer_id: Dictionary,
	server_character_state_per_entity_id: Dictionary
) -> Dictionary:
	var character_resource_per_client_id: Dictionary = {}
	for client_id: int in client_resources_per_peer_id:
		var client_input_buffer_and_character: ClientResources = client_resources_per_peer_id[client_id]
		var client_character_entity := client_input_buffer_and_character.get_or_spawn_character_entity_if_alive()
		if client_character_entity != null:
			var latest_client_input_with_tick: QueueItem = client_input_buffer_and_character.input_buffer.pop()
			var latest_client_input: ClientInput = latest_client_input_with_tick.value()
			var client_tick_for_input: int = latest_client_input_with_tick.tick()
			var character_state: ServerCharacterState = Utils.get_or_default(
				server_character_state_per_entity_id, 
				client_character_entity.entity_id, 
				client_character_entity.state_data)
			character_resource_per_client_id[client_id] = ServerCharacterResource.new(
				latest_client_input,
				client_tick_for_input,
				client_character_entity.entity_id,
				character_state,
				client_character_entity.components)
	return character_resource_per_client_id

static func __compute_next_state_for_characters(
	character_resource_per_client_id: Dictionary,
	hitscan_results: Array[HitscanResult]
) -> Dictionary:
	var next_world_state := {}
	for client_id: int in character_resource_per_client_id:
		var character_resource: ServerCharacterResource = character_resource_per_client_id[client_id]
		var character_entity_id := character_resource.character_entity_id
		var character_components := character_resource.character_components
		var latest_input_state := character_resource.input.input_state()
		var next_physics_state := character_components.movement_body().compute_next_physics_state(
				character_resource.character_state.physics_state(), latest_input_state)
		
		var current_health := character_resource.character_state.health_state().health()
		for hitscan_result: HitscanResult in hitscan_results:
			if hitscan_result.hit_entity_id == character_entity_id:
				current_health -= hitscan_result.damage
		var next_health_state := CharacterHealthState.new(current_health)
		
		next_world_state[character_entity_id] = ServerCharacterState.new(
			next_physics_state, next_health_state)
	return next_world_state

static func __display_character_states(
	character_resource_per_client_id: Dictionary,
	next_character_state_per_entity_id: Dictionary
) -> void:
	for client_id: int in character_resource_per_client_id:
		var character_resource: ServerCharacterResource = character_resource_per_client_id[client_id]
		var character_entity_id := character_resource.character_entity_id
		var next_character_state: ServerCharacterState = next_character_state_per_entity_id[character_entity_id]
		var character_components := character_resource.character_components
		var character_transform_state := __extract_transform_state(character_resource, next_character_state)
		character_components.third_person_display().display_character_transform(character_transform_state)
		character_components.first_person_display().display_character_state(
			character_transform_state, next_character_state.health_state().health())

static func __compile_data_to_export_per_client(
	character_resource_per_client_id: Dictionary,
	next_character_state_per_entity_id: Dictionary
) -> Dictionary:
	var data_to_export_per_client := {}
	for client_id: int in character_resource_per_client_id:
		var character_resource: ServerCharacterResource = character_resource_per_client_id[client_id]
		var character_entity_id := character_resource.character_entity_id
		var next_character_state: ServerCharacterState = next_character_state_per_entity_id[character_entity_id]
		var next_transform_state := __extract_transform_state(character_resource, next_character_state)
		data_to_export_per_client[client_id] = PerClientExportedData.new(
			character_resource.client_tick_for_input,
			next_character_state.physics_state(),
			next_character_state.health_state(),
			next_transform_state,
			character_entity_id)
	return data_to_export_per_client

static func __extract_transform_state(
	character_resource: ServerCharacterResource, 
	character_state: ServerCharacterState
) -> CharacterTransformState:
	return CharacterTransformState.new(
			character_state.physics_state().position(), 
			character_resource.input.input_state().pitch(), 
			character_resource.input.input_state().yaw())

static func __compute_hitscan_ability_results(
	current_world_state: Dictionary, 
	world_state_per_server_tick: Dictionary,
	character_resource_per_client_id: Dictionary
) -> Array[HitscanResult]:
	var hitscan_ability_results: Array[HitscanResult] = []
	for client_id: int in character_resource_per_client_id:
		var character_resource: ServerCharacterResource = character_resource_per_client_id[client_id]
		if character_resource.input.is_triggered():
			var character_entity_id := character_resource.character_entity_id
			var character_components := character_resource.character_components
			var latest_input_state := character_resource.input.input_state()
			var character_transform_state := CharacterTransformState.new(
				character_resource.character_state.physics_state().position(), 
				latest_input_state.pitch(), 
				latest_input_state.yaw())
			var server_tick_client_saw_at_time_of_trigger := (
				character_resource.input.displayed_server_tick_at_time_of_trigger())
			var lag_compensated_world_state: Dictionary = (
				world_state_per_server_tick[server_tick_client_saw_at_time_of_trigger])
			if lag_compensated_world_state == null:
				print("Cannot lag compensate hitscan ability against state with tick %d. Current tick: %d" % [
					server_tick_client_saw_at_time_of_trigger])
				lag_compensated_world_state = current_world_state
			var character_camera_transform: Transform3D = (
				character_components.first_person_display().compute_camera_transform(character_transform_state))
			var other_character_positions_during_current_tick := (
				__extract_positions_for_other_characters(lag_compensated_world_state, character_entity_id))
			var ability_result := character_components.ability_action().perform_ability(
				character_camera_transform, other_character_positions_during_current_tick)
			hitscan_ability_results.append_array(ability_result.hitscan_results)
	return hitscan_ability_results

static func __draw_bullet_tracers(tracer_displayer: TracerDisplayer, hitscan_results: Array[HitscanResult]) -> void:
	for hitscan_result: HitscanResult in hitscan_results:
		tracer_displayer.add_tracer(hitscan_result.origin, hitscan_result.hit_point)
	tracer_displayer.display_and_update_tracers()

static func __draw_bullet_hits(
	debug_sphere_displayer: DebugSphereDisplayer, 
	hitscan_results: Array[HitscanResult]
) -> void:
	for hitscan_result: HitscanResult in hitscan_results:
		debug_sphere_displayer.draw_debug_sphere(hitscan_result.hit_point)

static func __extract_states_for_remote_characters(
	data_to_export_per_client: Dictionary, 
	own_client_id: int
) -> Dictionary:
	var states_for_remote_characters := {}
	for client_id: int in data_to_export_per_client:
		if client_id != own_client_id:
			var client_snapshot_data: PerClientExportedData = data_to_export_per_client[client_id]
			var remote_character_entity_id: int = client_snapshot_data.character_entity_id
			states_for_remote_characters[remote_character_entity_id] = client_snapshot_data.transform_state
	return states_for_remote_characters

static func __extract_positions_for_other_characters(
	world_state: Dictionary, 
	own_character_entity_id: int
) -> Dictionary:
	var other_character_positions_per_entity_id: Dictionary = {}
	for character_entity_id: int in world_state:
		if character_entity_id != own_character_entity_id:
			var other_character_state: ServerCharacterState = world_state[character_entity_id]
			other_character_positions_per_entity_id[character_entity_id] = (
				other_character_state.physics_state().position())
	return other_character_positions_per_entity_id

static func __apply_debug_motion(physics_state: CharacterPhysicsState, input: InputState) -> CharacterPhysicsState:
	if input.is_slow_walking():
		return CharacterPhysicsState.new(
			physics_state.position() + Vector3(0.5, 0.0, 0),
			physics_state.velocity() + Vector3(0, 0.0, -2),
			physics_state.is_grounded())
	else:
		return physics_state

class ClientResources:
	const JUST_RESPAWNED := true
	const STILL_DEAD_OR_ALREADY_RESPAWNED := false

	var input_buffer: OrderedInputBuffer
	var character_entity: CharacterEntity
	var ticks_until_respawn: int
	var entity_creator: EntityCreator

	func _init(input_buffer: OrderedInputBuffer, character_entity: CharacterEntity, entity_creator: EntityCreator) -> void:
		self.input_buffer = input_buffer
		self.character_entity = character_entity
		self.entity_creator = entity_creator
		ticks_until_respawn = 0
	
	func advance_respawn_timer() -> bool:
		if ticks_until_respawn > 0:
			ticks_until_respawn -= 1
			if ticks_until_respawn == 0:
				return JUST_RESPAWNED
		return STILL_DEAD_OR_ALREADY_RESPAWNED
	
	func get_or_spawn_character_entity_if_alive() -> CharacterEntity:
		if ticks_until_respawn == 0:
			if character_entity == null:
				character_entity = entity_creator.create_character_entity()
			return character_entity
		else:
			return null
	
	func despawn() -> void:
		ticks_until_respawn = RESPAWN_TIME_IN_TICKS
		character_entity = null

class ServerCharacterResource:
	var input: ClientInput
	var client_tick_for_input: int
	var character_entity_id: int
	var character_state: ServerCharacterState
	var character_components: CharacterComponents

	func _init(
		input: ClientInput, 
		client_tick_for_input: int,
		character_entity_id: int,
		current_physics_state: ServerCharacterState,
		character_components: CharacterComponents
	) -> void:
		self.input = input
		self.client_tick_for_input = client_tick_for_input
		self.character_entity_id = character_entity_id
		self.character_state = current_physics_state
		self.character_components = character_components

class PerClientExportedData:
	var client_tick: int
	var physics_state: CharacterPhysicsState
	var health_state: CharacterHealthState
	var transform_state: CharacterTransformState
	var character_entity_id: int

	func _init(
		client_tick: int,
		physics_state: CharacterPhysicsState,
		health_state: CharacterHealthState,
		transform_state: CharacterTransformState,
		character_entity_id: int
	) -> void: 
		self.client_tick = client_tick
		self.physics_state = physics_state
		self.health_state = health_state
		self.transform_state = transform_state
		self.character_entity_id = character_entity_id

class EntityCreator:
	static var DEFAULT_PHYSICS_STATE := CharacterPhysicsState.new(SPAWN_POINT, Vector3.ZERO, false)
	static var DEFAULT_SERVER_CHARACTER_STATE := ServerCharacterState.new(
		DEFAULT_PHYSICS_STATE, CharacterHealthState.DEFAULT_HEALTH_STATE)

	var spawner_: EntitySpawner
	var next_entity_id_: int = 0

	func _init(spawner: EntitySpawner) -> void:
		spawner_ = spawner

	func create_character_entity() -> CharacterEntity:
		var character_entity_id := next_entity_id_
		var character_components := spawner_.get_or_spawn_character(
			character_entity_id, CONSTANTS.NetworkEntityMode.SERVER)
		next_entity_id_ += 1
		return CharacterEntity.new(DEFAULT_SERVER_CHARACTER_STATE, character_components, character_entity_id)

class Entity:
	var entity_id: int

	func _init(entity_id: int) -> void:
		self.entity_id = entity_id

class CharacterEntity extends Entity:
	var state_data: ServerCharacterState
	var components: CharacterComponents

	func _init(state_data: ServerCharacterState, components: CharacterComponents, entity_id: int) -> void:
		super(entity_id)
		self.state_data = state_data
		self.components = components
