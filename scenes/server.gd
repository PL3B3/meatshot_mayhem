extends Node

const EMPTY_PHYSICS_STATE = {}
const SPAWN_POINT_RANDOM_VARIATION = 5
const SPAWN_POINT = Vector3(0, 2.5, 0)
const OVERWRITE_EXISTING = true
static var DEFAULT_PHYSICS_STATE = CharacterPhysicsState.new(SPAWN_POINT, Vector3.ZERO, false)
static var CLIENT_INPUT_BUFFER_FACTORY: Callable = func(x): 
	return TickAwareQueue.new("sv_input_buf[%10d]" % x, InputState.DEFAULT)

@onready var messenger: NetworkMessenger = $NetworkMessenger
@onready var map_spawner: MultiplayerSpawner = $MapSpawner
@onready var entity_spawner: NetworkEntityRegistry = $NetworkEntityRegistry

var client_resources_per_peer_id_ := {}
var world_state_ := {}

func _ready():
	resize_window()
	multiplayer.peer_connected.connect(_on_client_connected)
	messenger.received_client_message.connect(_handle_client_message)
	map_spawner.spawn(null)

func _handle_client_message(client_id: int, message: Dictionary):
	if client_id in client_resources_per_peer_id_:
		var client_resources: InputBufferAndCharacterEntity = client_resources_per_peer_id_[client_id]
		var input_buffer_for_client: TickAwareQueue = client_resources.input_buffer
		var client_input: InputState = InputState.from_dict(message["input"])
		input_buffer_for_client.push(client_input, message["tick"])
	else:
		print("Cannot enqueue input message %s from client %d. No input buffer initialized." % [message, client_id])

func _on_client_connected(id: int):
	__initialize_resources_for_new_client(id)
	var prior_peer_count = multiplayer.get_peers().size() - 1
	resize_window.rpc_id(id, prior_peer_count)
	resize_window(prior_peer_count)

func _physics_process(_delta):
	var character_resource_per_client_id: Dictionary = {}
	for client_id in client_resources_per_peer_id_:
		var client_input_buffer_and_character: InputBufferAndCharacterEntity = client_resources_per_peer_id_[client_id]
		var latest_client_input_with_tick: QueueItem = client_input_buffer_and_character.input_buffer.pop()
		var latest_input: InputState = latest_client_input_with_tick.value()
		var client_tick_for_input: int = latest_client_input_with_tick.tick()
		var character_entity_id: int = client_input_buffer_and_character.character_entity.get_entity_id()
		var character_physics_state: CharacterPhysicsState = Utils.get_or_default(
			world_state_, character_entity_id, DEFAULT_PHYSICS_STATE)
		character_resource_per_client_id[client_id] = ServerCharacterResource.new(
			latest_input,
			client_tick_for_input,
			character_entity_id,
			character_physics_state,
			client_input_buffer_and_character.character_entity)
	
	var next_world_state := {}
	var data_to_export_per_client := {}
	for client_id in character_resource_per_client_id:
		var character_resource: ServerCharacterResource = character_resource_per_client_id[client_id]
		var character_entity_id := character_resource.character_entity_id
		var next_physics_state := character_resource.movement_calculator.compute_next_physics_state(
				character_resource.current_physics_state, character_resource.input)
		next_physics_state = __apply_debug_motion(next_physics_state, character_resource.input)
		var character_transform_state := CharacterTransformState.new(
			next_physics_state.position(), character_resource.input.pitch(), character_resource.input.yaw())
		character_resource.first_person_display.display_character_transform(character_transform_state)
		character_resource.third_person_display.display_character_transform(character_transform_state)

		next_world_state[character_entity_id] = next_physics_state
		data_to_export_per_client[client_id] = PerClientExportedData.new(
			character_resource.client_tick,
			next_physics_state,
			character_transform_state,
			character_entity_id)
	
	world_state_ = next_world_state
	__export_state_snapshots_to_clients(data_to_export_per_client)

@rpc("authority", "call_local", "reliable")
func resize_window(index=0):
	var screen_size: Vector2 = DisplayServer.screen_get_size()
	get_window().size = Vector2(screen_size.x / 2, screen_size.y / 2)
	get_window().position = Vector2(screen_size.x * 1.5, index * (screen_size.y / 2))

func __initialize_resources_for_new_client(client_id: int):
	var client_character_entity: NetworkEntity = entity_spawner.spawn_entity({"entity_network_owner_id": client_id})
	var input_buffer_for_client: TickAwareQueue = CLIENT_INPUT_BUFFER_FACTORY.call(client_id)
	var client_resources: InputBufferAndCharacterEntity = InputBufferAndCharacterEntity.new(
		input_buffer_for_client, client_character_entity)
	client_resources_per_peer_id_[client_id] = client_resources

func __export_state_snapshots_to_clients(data_to_export_per_client: Dictionary):
	var state_snapshots_for_clients := {}
	for client_id in data_to_export_per_client:
		var client_snapshot_data: PerClientExportedData = data_to_export_per_client[client_id]
		var remote_character_state_per_entity: Dictionary = __extract_states_for_remote_characters(
			data_to_export_per_client, client_id)
		var state_snapshot_for_client := ServerToClientStateSnapshotMessage.new(
			client_snapshot_data.client_tick, 
			ClientStateSnapshot.new(client_snapshot_data.physics_state, remote_character_state_per_entity))
		messenger.send_message_to_client(client_id, state_snapshot_for_client.to_dict())
	return state_snapshots_for_clients

static func __extract_states_for_remote_characters(
	data_to_export_per_client: Dictionary, 
	own_client_id: int) -> Dictionary:
	var states_for_remote_characters := {}
	for client_id in data_to_export_per_client:
		if client_id != own_client_id:
			var client_snapshot_data: PerClientExportedData = data_to_export_per_client[client_id]
			var remote_character_entity_id = client_snapshot_data.character_entity_id
			states_for_remote_characters[remote_character_entity_id] = client_snapshot_data.transform_state
	return states_for_remote_characters

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
	var character_entity: CharacterNetworkEntity

	func _init(input_buffer: TickAwareQueue, character_entity: CharacterNetworkEntity):
		self.input_buffer = input_buffer
		self.character_entity = character_entity

class ServerCharacterResource:
	var input: InputState
	var client_tick: int
	var character_entity_id: int
	var current_physics_state: CharacterPhysicsState
	var movement_calculator: CharacterMovementActuator
	var first_person_display: CharacterFirstPersonOutput
	var third_person_display: CharacterThirdPersonDisplay

	func _init(
		input: InputState, 
		client_tick: int,
		character_entity_id: int,
		current_physics_state: CharacterPhysicsState, 
		character_network_entity: CharacterNetworkEntity):
		self.input = input
		self.client_tick = client_tick
		self.character_entity_id = character_entity_id
		self.current_physics_state = current_physics_state
		self.movement_calculator = character_network_entity.get_movement_calculator()
		self.first_person_display = character_network_entity.get_first_person_display()
		self.third_person_display = character_network_entity.get_third_person_display()

class PerClientExportedData:
	var client_tick: int
	var physics_state: CharacterPhysicsState
	var transform_state: CharacterTransformState
	var character_entity_id: int

	func _init(
		client_tick: int,
		physics_state: CharacterPhysicsState,
		transform_state: CharacterTransformState,
		character_entity_id: int): 
		self.client_tick = client_tick
		self.physics_state = physics_state
		self.transform_state = transform_state
		self.character_entity_id = character_entity_id
