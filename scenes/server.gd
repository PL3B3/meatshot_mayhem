extends Node

const EMPTY_PHYSICS_STATE = {}
const SPAWN_POINT_RANDOM_VARIATION = 5
const SPAWN_POINT = Vector3(0, 2.5, 0)
const OVERWRITE_EXISTING = true

@onready var messenger: NetworkMessenger = $NetworkMessenger
@onready var map_spawner: MultiplayerSpawner = $MapSpawner
@onready var character_spawner: MultiplayerSpawner = $CharacterSpawner
@onready var entity_spawner: NetworkEntityRegistry = $NetworkEntityRegistry
@onready var input_buffer: SimpleClientInputBuffers = SimpleClientInputBuffers.new(entity_spawner)
@onready var tick_aware_input_buffer: TickAwareClientInputBuffers = (
	TickAwareClientInputBuffers.new(entity_spawner))

var test_scene = preload("res://scenes/test_spawn.tscn")

var rng_ = RandomNumberGenerator.new()
var client_character: CharacterMovementKinematicBody = null
var character_physics_state: Dictionary = {}
# var client_id: int = -1
var client_inputs = []
var character_simulation_per_client: Dictionary = {}
var world_state_timeline_: WorldStateTimeline = WorldStateTimeline.new()

func _ready():
	resize_window()
	multiplayer.peer_connected.connect(_on_client_connected)
	multiplayer.peer_disconnected.connect(_on_client_disconnected)
	messenger.received_client_message.connect(_handle_client_message)
	#LogsAndMetrics.add_server_stat("sv_buffer_size")
	map_spawner.spawn(null)
	#get_tree().create_timer(10).timeout.connect(despawn)

func despawn():
	for child_node in entity_spawner.get_children():
		entity_spawner.remove_child(child_node)

func _handle_client_message(client_id: int, message: Dictionary):
	var client_input: InputState = InputState.from_dict(message["input"])
	#input_buffer.buffer_input_for_client(client_id, client_input)
	tick_aware_input_buffer.buffer_input_for_client(client_id, client_input, message["tick"])
	#character_simulation_per_client[id].add_client_message(message)

var last_phys_ts = 0
var initial_tick_diff = 0
func _physics_process(_delta):
	for client_id in character_simulation_per_client:
		var simulation_for_client: CharacterSimulation = character_simulation_per_client[client_id]
		simulation_for_client.advance_state_and_notify_clients(character_simulation_per_client.keys())
	var next_state = (
		world_state_timeline_.get_current_state().duplicate(true) 
		if world_state_timeline_.has_states() 
		else {})
	while not spawn_data_to_add.is_empty():
		next_state.merge(spawn_data_to_add.pop_back())
	#var input_per_player_entity: Dictionary = input_buffer.get_latest_input_per_player_entity(next_state)
	var latest_input_snapshot: ClientInputSnapshot = (
		tick_aware_input_buffer.get_latest_input_per_player_entity(next_state))
	var input_per_player_entity: Dictionary = latest_input_snapshot.input_per_player()
	var latest_tick_per_client: Dictionary = latest_input_snapshot.latest_tick_per_client()
	# --
	
	#var tick_aware_input_per_player_entity = (
		#tick_aware_input_buffer.get_latest_input_per_player_entity(next_state))
	#print(tick_aware_input_per_player_entity)
	
	# --
	var next_physics_states = compute_next_physics_states(
		world_state_timeline_, entity_spawner, input_per_player_entity)
	next_state.merge(next_physics_states, OVERWRITE_EXISTING)
	for client_id in multiplayer.get_peers():
		var client_state_snapshot = create_state_snapshot_for_client(next_state, latest_tick_per_client, client_id)
		var serialized_world_state = serialize_world_state(next_state, latest_tick_per_client, client_id)
		if client_state_snapshot != null:
			#print("sending message %s to client %d" % [client_state_snapshot, client_id])
			messenger.send_message_to_client(client_id, client_state_snapshot.to_dict())
	world_state_timeline_.add_next_state(next_state)

func _process(delta):
	display_players()

@rpc("authority", "call_local", "reliable")
func resize_window(index=0):
	var screen_size: Vector2 = DisplayServer.screen_get_size()
	get_window().size = Vector2(screen_size.x / 2, screen_size.y / 2)
	get_window().position = Vector2(screen_size.x * 1.5, index * (screen_size.y / 2))

func _on_client_connected(id: int):
	var spawn_point = SPAWN_POINT + SPAWN_POINT_RANDOM_VARIATION * Vector3(rng_.randf_range(-1,1), 0, rng_.randf_range(-1,1))
	spawn_character(id, spawn_point)
	var prior_peer_count = multiplayer.get_peers().size() - 1
	resize_window.rpc_id(id, prior_peer_count)
	resize_window(prior_peer_count)

var spawn_data_to_add = []
func spawn_character(client_id: int, spawn_point: Vector3):
	var spawned_entity: Node = entity_spawner.spawn_entity({"entity_network_owner_id": client_id})
	var entity_id: int = int(str(spawned_entity.name))
	spawn_data_to_add.append({
		entity_id: {
			StateType.CHARACTER_PHYSICS: CharacterPhysicsState.new(spawn_point, Vector3.ZERO, false),
			StateType.INPUT: InputState.DEFAULT
		}
	})

func _on_client_disconnected(id: int):
	tick_aware_input_buffer.remove_buffer_for_disconnected_client(id)
	print("Client with id ", id, " disconnected")

class SimpleClientInputBuffers:
	static var QUEUE_FACTORY: Callable = func(x): 
		return RefillingQueue.new("old_sv_input_buf[%10d]" % x, true)
	
	var entity_spawner_: NetworkEntityRegistry
	var input_buffer_per_client_id_: Dictionary = {}
	
	func _init(entity_spawner: NetworkEntityRegistry):
		entity_spawner_ = entity_spawner
	
	func buffer_input_for_client(client_peer_id: int, input: InputState):
		var input_buffer_for_client: RefillingQueue = Utils.compute_if_absent(
			input_buffer_per_client_id_, client_peer_id, QUEUE_FACTORY)
		input_buffer_for_client.push(input)
	
	func get_latest_input_per_player_entity(world_state: Dictionary) -> Dictionary:
		var latest_input_per_client: Dictionary = {}
		# for now assume the only entities are characters
		for character_entity_id in world_state:
			var client_id_for_character = (
				entity_spawner_.get_network_owner_id_for_entity(character_entity_id))
			if client_id_for_character in input_buffer_per_client_id_:
				var input_queue_for_client: RefillingQueue = (
					input_buffer_per_client_id_[client_id_for_character])
				var latest_client_input: QueueItem = input_queue_for_client.pop()
				if latest_client_input.is_valid():
					latest_input_per_client[character_entity_id] = latest_client_input.value()
		return latest_input_per_client
	
	func remove_unused_client_buffers(valid_client_ids: Array[int]):
		# TODO if no entity with this client id exists anymore, KILL
		pass

class TickAwareClientInputBuffers:
	static var QUEUE_FACTORY: Callable = func(x): 
		return TickAwareQueue.new("sv_input_buf[%10d]" % x)
	
	var entity_spawner_: NetworkEntityRegistry
	var input_buffer_per_client_id_: Dictionary = {}
	
	func _init(entity_spawner: NetworkEntityRegistry):
		entity_spawner_ = entity_spawner
	
	func buffer_input_for_client(client_peer_id: int, input: InputState, tick: int):
		var input_buffer_for_client: TickAwareQueue = Utils.compute_if_absent(
			input_buffer_per_client_id_, client_peer_id, QUEUE_FACTORY)
		input_buffer_for_client.push(input, tick)
	
	func get_latest_input_per_player_entity(world_state: Dictionary) -> ClientInputSnapshot:
		var input_per_player: Dictionary = {}
		var latest_tick_per_client: Dictionary = {}
		# for now assume the only entities are characters
		for character_entity_id in world_state:
			var client_id_for_character = (
				entity_spawner_.get_network_owner_id_for_entity(character_entity_id))
			if client_id_for_character in input_buffer_per_client_id_:
				var input_queue_for_client: TickAwareQueue = (
					input_buffer_per_client_id_[client_id_for_character])
				var latest_client_input: QueueItem = input_queue_for_client.pop()
				if latest_client_input.is_valid():
					input_per_player[character_entity_id] = latest_client_input.value()
					latest_tick_per_client[client_id_for_character] = latest_client_input.tick()
		return ClientInputSnapshot.new(input_per_player, latest_tick_per_client)
	
	func remove_buffer_for_disconnected_client(client_id: int):
		# maybe race condition if we get a message after disconnect
		input_buffer_per_client_id_.erase(client_id)

class ClientInputSnapshot:
	var input_per_player_: Dictionary
	var latest_tick_per_client_: Dictionary
	
	func _init(input_per_player, latest_tick_per_client):
		input_per_player_ = input_per_player
		latest_tick_per_client_ = latest_tick_per_client
	
	func input_per_player() -> Dictionary:
		return input_per_player_
	
	func latest_tick_per_client() -> Dictionary:
		return latest_tick_per_client_

static func serialize_world_state(
	world_state: Dictionary, 
	latest_tick_per_client: Dictionary, 
	client_id: int) -> Dictionary:
	var serialized_state: Dictionary = {}
	if client_id in latest_tick_per_client:
		serialized_state[Network.CLIENT_TICK] = latest_tick_per_client[client_id]
	for entity_id in world_state:
		for state_type in world_state[entity_id]:
			var entity_state_dict: Dictionary = Utils.default_dict_if_absent(serialized_state, entity_id)
			entity_state_dict[state_type] = world_state[entity_id][state_type].to_dict()
	return serialized_state

func create_state_snapshot_for_client(
	world_state: Dictionary, 
	latest_tick_per_client: Dictionary, 
	client_id: int) -> ServerToClientStateSnapshotMessage:
	var latest_client_input_tick: int = (
		latest_tick_per_client[client_id] if client_id in latest_tick_per_client else Network.NO_TICK)
	var client_own_character_state: CharacterPhysicsState
	var client_remote_character_states: Dictionary = {}
	for character_entity_id in world_state:
		var physics_state: CharacterPhysicsState = world_state[character_entity_id][StateType.CHARACTER_PHYSICS]
		var input_state: InputState = world_state[character_entity_id][StateType.INPUT]
		if entity_spawner.get_network_owner_id_for_entity(character_entity_id) == client_id:
			client_own_character_state = physics_state
		else:
			client_remote_character_states[character_entity_id] = CharacterTransformState.new(
				physics_state.position(),
				input_state.pitch(),
				input_state.yaw())
	if client_own_character_state == null:
		print("No character entity state for client id %s. Not sending snapshot." % client_id)
		return null
	else:
		return ServerToClientStateSnapshotMessage.new(
			latest_client_input_tick, 
			ClientStateSnapshot.new(client_own_character_state, client_remote_character_states))

static func compute_next_physics_states(
	world_state_timeline: WorldStateTimeline,
	entity_registry: NetworkEntityRegistry,
	input_per_player_entity_id: Dictionary) -> Dictionary:
	var next_physics_state_per_player: Dictionary = {}
	for player_entity_id in input_per_player_entity_id:
		var latest_player_state: Dictionary = world_state_timeline.get_current_entity_state(player_entity_id)
		if latest_player_state.is_empty():
			continue
		if not player_entity_id in input_per_player_entity_id:
			next_physics_state_per_player[player_entity_id] = latest_player_state
			continue
		var player_input: InputState = input_per_player_entity_id[player_entity_id]
		var current_physics_state: CharacterPhysicsState = latest_player_state[StateType.CHARACTER_PHYSICS]
		var player_entity := entity_registry.get_entity(player_entity_id) as CharacterNetworkEntity
		var movement_calculator: CharacterMovementActuator = player_entity.get_movement_calculator()
		var phys_state = movement_calculator.compute_next_physics_state(current_physics_state, player_input)
		if player_input.is_slow_walking():
			phys_state = CharacterPhysicsState.new(
				phys_state.position() + Vector3(0.5, 0.0, 0),
				phys_state.velocity(),
				phys_state.is_grounded())
		next_physics_state_per_player[player_entity_id] = {
			StateType.CHARACTER_PHYSICS: phys_state,
			StateType.INPUT: player_input
		}
		#Utils.default_if_absent(in_progress_next_state, own_player_id, {})[StateType.CHARACTER_PHYSICS] = (
			#movement_calculator.compute_next_physics_state(current_physics_state, player_input))
	return next_physics_state_per_player

#static func display_first_person(
	#world_state_timeline: WorldStateTimeline,
	#entity_registry: NetworkEntityRegistry):
	#var own_player_id: int = get_own_player_entity_id(entity_registry)
	#if own_player_id == Network.NO_ENTITY_ID:
		#return
	#var latest_player_state: Dictionary = world_state_timeline.get_current_entity_state(own_player_id)
	#if latest_player_state.is_empty():
		#return
	#var latest_physics_state: CharacterPhysicsState = latest_player_state[StateType.CHARACTER_PHYSICS]
	#var latest_input_state: InputState = latest_player_state[StateType.INPUT]
	#var own_player_entity := entity_registry.get_entity(own_player_id) as CharacterNetworkEntity
	#var first_person_display: CharacterFirstPersonOutput = own_player_entity.get_first_person_display()
	#first_person_display.display_character_state(
		#latest_physics_state.position(), 
		#latest_input_state.yaw(), 
		#latest_input_state.pitch())

func display_players():
	for player_id in entity_spawner.get_entity_ids_for_mode(CONSTANTS.NetworkEntityMode.SERVER):
		var latest_player_state: Dictionary = world_state_timeline_.get_current_entity_state(player_id)
		if latest_player_state.is_empty():
			continue
		var latest_physics_state: CharacterPhysicsState = latest_player_state[StateType.CHARACTER_PHYSICS]
		var latest_input_state: InputState = latest_player_state[StateType.INPUT]
		var player_entity := entity_spawner.get_entity(player_id) as CharacterNetworkEntity
		var first_person_display: CharacterFirstPersonOutput = player_entity.get_first_person_display()
		first_person_display.display_character_state(
			latest_physics_state.position(), 
			latest_input_state.yaw(), 
			latest_input_state.pitch())
		var third_person_display: CharacterThirdPersonDisplay = player_entity.get_third_person_display()
		third_person_display.display_character_state(
			latest_physics_state.position(), 
			latest_input_state.yaw(), 
			latest_input_state.pitch())

class CharacterSimulation:
	const EMPTY_INPUT_FOR_BUFFERING = { "INPUT": "EMPTY" }
	const ARTIFICIAL_INPUT_BUFFER_AMOUNT = 6
	
	var client_id_: int
	var character_
	var messages_: Array = []
	var network_messenger_: NetworkMessenger
	var character_physics_state_: Dictionary
	
	func _init(client_id, character, network_messenger):
		character_physics_state_ = character.starting_physics_state()
		character_ = character
		client_id_ = client_id
		network_messenger_ = network_messenger
	
	func add_client_message(message):
		if messages_.is_empty():
			for i in ARTIFICIAL_INPUT_BUFFER_AMOUNT:
				messages_.push_back(EMPTY_INPUT_FOR_BUFFERING)
		messages_.push_back(message)
	
	func advance_state_and_notify_clients(client_ids: Array):
		#print("buff size: %d" % messages_.size())
		if messages_.is_empty():
			#print(Time.get_unix_time_from_system(), " ---- NO CLIENT INPUTS")
			return
		
		var message_to_process = messages_.pop_front()
		if message_to_process != EMPTY_INPUT_FOR_BUFFERING:
			#character_physics_state_.position += compute_random_movement(message_to_process["tick"])
			var input_to_simulate = message_to_process["input"]
			character_physics_state_ = character_.compute_next_physics_state(character_physics_state_, input_to_simulate)
			var player_state_message = { 
				"type": Network.MessageType.PLAYER_STATE,
				"state": character_physics_state_, 
				"tick": message_to_process["tick"] 
			}
			network_messenger_.send_message_to_client(client_id_, player_state_message)
			for other_client_id in client_ids.filter(func(peer_id): return peer_id != client_id_):
				var puppet_state_message = { 
					"type": Network.MessageType.PUPPET_STATE,
					"position": character_physics_state_.position, 
					"tick": message_to_process["tick"],
					"pitch": input_to_simulate.pitch,
					"yaw": input_to_simulate.yaw,
					"puppet_id": client_id_
				}
				network_messenger_.send_message_to_client(other_client_id, puppet_state_message)
	
func compute_random_movement(tick):
	if tick % 60 == 0:
		var horizontal_component = 2 * Vector3.FORWARD.rotated(Vector3.UP, rng_.randf_range(0, 2 * PI))
		var vertical_component = Vector3(0, rng_.randf_range(0, 1), 0)
		return horizontal_component
	else:
		return Vector3.ZERO

func old_simulate():
	last_phys_ts = Time.get_ticks_usec()
	if client_character != null:
		$Label2.set_text(str(client_inputs.size()))
		#LogsAndMetrics.add_sample("sv_buffer_size", client_inputs.size())
		if client_inputs.is_empty():
			pass
			#print(Time.get_unix_time_from_system(), " ---- NO CLIENT INPUTS")
		else:
			#while client_inputs.size() > 1500:
				#print(Time.get_time_string_from_system(), " Too many queued inputs, popping")
				#client_inputs.pop_front()
			var input = client_inputs.pop_front()
			#if input != EMPTY_INPUT_FOR_BUFFERING:
				##print(Time.get_unix_time_from_system() - input["client_timestamp"])
				##print("usec diff: ", (Time.get_ticks_usec() - input["client_timestamp"]) - initial_tick_diff, " input buff: ", client_inputs.size())
				##if character_physics_state:
					##character_physics_state.position = character_physics_state.position + add_random_movement(input["tick"])
				#character_physics_state = client_character.compute_next_physics_state(character_physics_state, input["input"]) # client_character.handle_input_frame(input)
				#messenger.send_message_to_client(client_id, {"state": character_physics_state, "tick": input["tick"]})
