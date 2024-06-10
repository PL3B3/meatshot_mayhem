extends Node

const EMPTY_PHYSICS_STATE = {}
const SPAWN_POINT_RANDOM_VARIATION = 5
const SPAWN_POINT = Vector3(0, 2.5, 0)
const OVERWRITE_EXISTING = true
static var DEFAULT_PHYSICS_STATE := CharacterPhysicsState.new(SPAWN_POINT, Vector3.ZERO, false)
static var CLIENT_INPUT_BUFFER_FACTORY: Callable = func(x: int) -> TickAwareQueue: 
	return TickAwareQueue.new("sv_input_buf[%10d]" % x, ClientInput.new(InputState.DEFAULT, false))
static var EMPTY_ABILITY_TRIGGER_STATE := CharacterAbilityTriggerState.new(0)

@onready var messenger: NetworkMessenger = $NetworkMessenger
@onready var map_spawner: MultiplayerSpawner = $MapSpawner
@onready var entity_spawner_: EntitySpawner= $EntitySpawner
@onready var entity_creator_ := EntityCreator.new(entity_spawner_)

var client_resources_per_peer_id_ := {}
var world_state_ := {}

@rpc("authority", "call_local", "reliable")
func resize_window(index: int = 0)  -> void:
	var screen_size: Vector2 = DisplayServer.screen_get_size()
	get_window().size = Vector2(screen_size.x / 2, screen_size.y / 2)
	get_window().position = Vector2(screen_size.x * 1.5, index * (screen_size.y / 2))

@rpc("authority", "reliable")
func trigger_ability_for_remote_character(remote_character_entity_id: int): pass

func _ready() -> void:
	resize_window()
	multiplayer.peer_connected.connect(_on_client_connected)
	messenger.received_client_message.connect(_handle_client_message)
	map_spawner.spawn(null)

func _handle_client_message(client_id: int, serialized_message: Dictionary) -> void:
	var client_message := ClientToServerInputMessage.from_dict(serialized_message)
	if client_id in client_resources_per_peer_id_:
		var client_resources: InputBufferAndCharacterEntity = client_resources_per_peer_id_[client_id]
		var input_buffer_for_client: TickAwareQueue = client_resources.input_buffer
		var client_input := client_message.client_input()
		input_buffer_for_client.push(client_input, client_message.client_tick())
	else:
		print("Cannot enqueue input serialized_message %s from client %d. No input buffer initialized." % [serialized_message, client_id])

func _on_client_connected(id: int) -> void:
	__initialize_resources_for_new_client(id)
	var prior_peer_count: int = multiplayer.get_peers().size() - 1
	resize_window.rpc_id(id, prior_peer_count)
	resize_window(prior_peer_count)

func _physics_process(_delta: float) -> void:
	var character_resource_per_client_id: Dictionary = {}
	for client_id: int in client_resources_per_peer_id_:
		var client_input_buffer_and_character: InputBufferAndCharacterEntity = client_resources_per_peer_id_[client_id]
		var latest_client_input_with_tick: QueueItem = client_input_buffer_and_character.input_buffer.pop()
		var latest_client_input: ClientInput = latest_client_input_with_tick.value()
		var client_tick_for_input: int = latest_client_input_with_tick.tick()
		var character_entity_id: int = client_input_buffer_and_character.character_entity.entity_id
		var character_physics_state: CharacterPhysicsState = Utils.get_or_default(
			world_state_, character_entity_id, client_input_buffer_and_character.character_entity.state_data)
		character_resource_per_client_id[client_id] = ServerCharacterResource.new(
			latest_client_input,
			client_tick_for_input,
			character_entity_id,
			character_physics_state,
			client_input_buffer_and_character.character_entity.components)
	
	var next_world_state := {}
	var data_to_export_per_client := {}
	for client_id: int in character_resource_per_client_id:
		var character_resource: ServerCharacterResource = character_resource_per_client_id[client_id]
		var character_entity_id := character_resource.character_entity_id
		var character_components := character_resource.character_components
		var latest_input_state := character_resource.input.input_state()
		var next_physics_state := character_components.movement_body().compute_next_physics_state(
				character_resource.current_physics_state, latest_input_state)
		var character_transform_state := CharacterTransformState.new(
			next_physics_state.position(), latest_input_state.pitch(), latest_input_state.yaw())
		character_components.first_person_display().display_character_transform(character_transform_state)
		character_components.third_person_display().display_character_transform(character_transform_state)

		next_world_state[character_entity_id] = next_physics_state
		data_to_export_per_client[client_id] = PerClientExportedData.new(
			character_resource.client_tick,
			next_physics_state,
			character_transform_state,
			character_entity_id)
		
	__perform_character_abilities(world_state_, character_resource_per_client_id)

	world_state_ = next_world_state
	entity_spawner_.despawn_entities_not_in_server_snapshot(next_world_state)
	__export_state_snapshots_to_clients(data_to_export_per_client)

func __initialize_resources_for_new_client(client_id: int) -> void:
	var client_character_entity: CharacterEntity = entity_creator_.create_character_entity()
	var input_buffer_for_client: TickAwareQueue = CLIENT_INPUT_BUFFER_FACTORY.call(client_id)
	var client_resources: InputBufferAndCharacterEntity = InputBufferAndCharacterEntity.new(
		input_buffer_for_client, client_character_entity)
	client_resources_per_peer_id_[client_id] = client_resources

func __export_state_snapshots_to_clients(data_to_export_per_client: Dictionary) -> Dictionary:
	var state_snapshots_for_clients: Dictionary = {}
	for client_id: int in data_to_export_per_client:
		var client_snapshot_data: PerClientExportedData = data_to_export_per_client[client_id]
		var remote_character_state_per_entity: Dictionary = __extract_states_for_remote_characters(
			data_to_export_per_client, client_id)
		var client_own_character_state := ClientOwnCharacterState.new(
			client_snapshot_data.physics_state, EMPTY_ABILITY_TRIGGER_STATE)
		var state_snapshot_for_client := ServerToClientStateSnapshotMessage.new(
			client_snapshot_data.client_tick, 
			ClientStateSnapshot.new(client_own_character_state, remote_character_state_per_entity))
		messenger.send_message_to_client(client_id, state_snapshot_for_client.to_dict())
	return state_snapshots_for_clients

static func __perform_character_abilities(world_state: Dictionary, character_resource_per_client_id: Dictionary) -> void:
	for client_id: int in character_resource_per_client_id:
		var character_resource: ServerCharacterResource = character_resource_per_client_id[client_id]
		if character_resource.input.is_triggered():
			var character_entity_id := character_resource.character_entity_id
			var character_components := character_resource.character_components
			var latest_input_state := character_resource.input.input_state()
			var character_transform_state := CharacterTransformState.new(
				character_resource.current_physics_state.position(), 
				latest_input_state.pitch(), 
				latest_input_state.yaw())
			var character_camera_transform: Transform3D = (
				character_components.first_person_display().compute_camera_transform(character_transform_state))
			var other_character_positions_during_current_tick := (
				__extract_positions_for_other_characters(world_state, character_entity_id))
			character_components.ability_action().perform_ability(
				character_camera_transform, other_character_positions_during_current_tick)
			trigger_ability_for_remote_character.rpc(character_entity_id)

static func __extract_states_for_remote_characters(
	data_to_export_per_client: Dictionary, 
	own_client_id: int) -> Dictionary:
	var states_for_remote_characters := {}
	for client_id: int in data_to_export_per_client:
		if client_id != own_client_id:
			var client_snapshot_data: PerClientExportedData = data_to_export_per_client[client_id]
			var remote_character_entity_id: int = client_snapshot_data.character_entity_id
			states_for_remote_characters[remote_character_entity_id] = client_snapshot_data.transform_state
	return states_for_remote_characters

static func __extract_positions_for_other_characters(
		world_state: Dictionary, 
		own_character_entity_id: int) -> Array[Vector3]:
	var other_character_positions: Array[Vector3] = []
	for character_entity_id: int in world_state:
		if character_entity_id != own_character_entity_id:
			var other_character_state: CharacterPhysicsState = world_state[character_entity_id]
			other_character_positions.push_back(other_character_state.position())
	return other_character_positions

static func __apply_debug_motion(physics_state: CharacterPhysicsState, input: InputState) -> CharacterPhysicsState:
	if input.is_slow_walking():
		return CharacterPhysicsState.new(
			physics_state.position() + Vector3(0.5, 0.0, 0),
			physics_state.velocity() + Vector3(0, 0.0, -2),
			physics_state.is_grounded())
	else:
		return physics_state

class InputBufferAndCharacterEntity:
	var input_buffer: TickAwareQueue
	var character_entity: CharacterEntity

	func _init(input_buffer: TickAwareQueue, character_entity: CharacterEntity) -> void:
		self.input_buffer = input_buffer
		self.character_entity = character_entity

class ServerCharacterResource:
	var input: ClientInput
	var client_tick: int
	var character_entity_id: int
	var current_physics_state: CharacterPhysicsState
	var character_components: CharacterComponents

	func _init(
		input: ClientInput, 
		client_tick: int,
		character_entity_id: int,
		current_physics_state: CharacterPhysicsState,
		character_components: CharacterComponents) -> void:
		self.input = input
		self.client_tick = client_tick
		self.character_entity_id = character_entity_id
		self.current_physics_state = current_physics_state
		self.character_components = character_components

class PerClientExportedData:
	var client_tick: int
	var physics_state: CharacterPhysicsState
	var transform_state: CharacterTransformState
	var character_entity_id: int

	func _init(
		client_tick: int,
		physics_state: CharacterPhysicsState,
		transform_state: CharacterTransformState,
		character_entity_id: int) -> void: 
		self.client_tick = client_tick
		self.physics_state = physics_state
		self.transform_state = transform_state
		self.character_entity_id = character_entity_id

class EntityCreator:
	static var DEFAULT_PHYSICS_STATE := CharacterPhysicsState.new(SPAWN_POINT, Vector3.ZERO, false)

	var spawner_: EntitySpawner
	var next_entity_id_: int = 0

	func _init(spawner: EntitySpawner) -> void:
		spawner_ = spawner

	func create_character_entity() -> CharacterEntity:
		var character_entity_id := next_entity_id_
		var character_components := spawner_.get_or_spawn_character(
			character_entity_id, CONSTANTS.NetworkEntityMode.SERVER)
		var character_data: CharacterPhysicsState = DEFAULT_PHYSICS_STATE
		next_entity_id_ += 1
		return CharacterEntity.new(character_data, character_components, character_entity_id)

class Entity:
	var entity_id: int

	func _init(entity_id: int) -> void:
		self.entity_id = entity_id

class CharacterEntity extends Entity:
	var state_data: CharacterPhysicsState
	var components: CharacterComponents

	func _init(state_data: CharacterPhysicsState, components: CharacterComponents, entity_id: int) -> void:
		super(entity_id)
		self.state_data = state_data
		self.components = components
