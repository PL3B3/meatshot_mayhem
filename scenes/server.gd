extends Node

const EMPTY_PHYSICS_STATE = {}
const SPAWN_POINT_RANDOM_VARIATION = 5
const SPAWN_POINT = Vector3(0, 2.5, 0)

@onready var messenger: NetworkMessenger = $NetworkMessenger
@onready var map_spawner: MultiplayerSpawner = $MapSpawner
@onready var character_spawner: MultiplayerSpawner = $CharacterSpawner
@onready var entity_spawner: NetworkEntityRegistry = $NetworkEntityRegistry
@onready var input_buffer: PlayerInputBuffer = PlayerInputBuffer.new(entity_spawner)

var test_scene = preload("res://scenes/test_spawn.tscn")

var rng = RandomNumberGenerator.new()
var client_character: CharacterMovementKinematicBody = null
var character_physics_state: Dictionary = {}
var client_id: int = -1
var client_inputs = []
var character_simulation_per_client: Dictionary = {}
var world_state_timeline_: WorldStateTimeline = WorldStateTimeline.new()

func _ready():
	resize_window()
	multiplayer.peer_connected.connect(_on_client_connected)
	multiplayer.peer_disconnected.connect(_on_client_disconnected)
	messenger.received_client_message.connect(_handle_client_message)
	LogsAndMetrics.add_server_stat("sv_buffer_size")
	map_spawner.spawn(null)
	#get_tree().create_timer(10).timeout.connect(despawn)

func despawn():
	for child_node in entity_spawner.get_children():
		entity_spawner.remove_child(child_node)

func _handle_client_message(id, message):
	input_buffer.buffer_input_for_client(id, InputState.from_dict(message["input"]))
	#character_simulation_per_client[id].add_client_message(message)

var last_phys_ts = 0
var initial_tick_diff = 0
func _physics_process(delta):
	for client_id in character_simulation_per_client:
		var simulation_for_client: CharacterSimulation = character_simulation_per_client[client_id]
		simulation_for_client.advance_state_and_notify_clients(character_simulation_per_client.keys())
	var next_state = {}
	for spawn_data in spawn_data_to_add:
		next_state.merge(spawn_data)
	world_state_timeline_.add_next_state(next_state)
	var client_inputs: Dictionary = input_buffer.get_latest_input_per_client(next_state)

func resize_window(index=0):
	var screen_size: Vector2 = DisplayServer.screen_get_size()
	get_window().size = Vector2(screen_size.x / 2, screen_size.y / 2)
	get_window().position = Vector2(screen_size.x / 2, index * (screen_size.y / 2))

#func _on_client_connected(id: int):
	#var spawn_point = SPAWN_POINT + SPAWN_POINT_RANDOM_VARIATION * Vector3(rng.randf_range(-1,1), 0, rng.randf_range(-1,1))
	#var client_connection_index = character_simulation_per_client.size()
	##var client_character = character_spawner.spawn({"id": id, "position": spawn_point})
	#
	#spawn_character_new(id, spawn_point)
	#
	##character_simulation_per_client[id] = CharacterSimulation.new(id, client_character, messenger)
	#messenger.send_message_to_client(id, { "resize": client_connection_index , "type": Network.MessageType.RESIZE })
	#resize_window(client_connection_index)
	#print("Client with id ", id, " connected")

func _on_client_connected(id: int):
	var spawn_point = SPAWN_POINT + SPAWN_POINT_RANDOM_VARIATION * Vector3(rng.randf_range(-1,1), 0, rng.randf_range(-1,1))
	spawn_character(id, spawn_point)
	var prior_peer_count = multiplayer.get_peers().size() - 1
	resize_window(prior_peer_count)
	messenger.send_message_to_client(
		id, { "resize": prior_peer_count , "type": Network.MessageType.RESIZE })

var spawn_data_to_add = []
func spawn_character(client_id: int, spawn_point: Vector3):
	var spawned_entity: Node = entity_spawner.spawn_entity({"entity_network_owner_id": client_id})
	var entity_id: int = int(str(spawned_entity.name))
	spawn_data_to_add.append({
		entity_id: {
			StateType.CHARACTER_PHYSICS: CharacterPhysicsState.new(spawn_point, Vector3.ZERO, false)
		}
	})

func _on_client_disconnected(id: int):
	print("Client with id ", id, " disconnected")

class PlayerInputBuffer:
	var entity_spawner_: NetworkEntityRegistry
	var input_buffer_per_client_id_: Dictionary = {}
	
	func _init(entity_spawner: NetworkEntityRegistry):
		entity_spawner_ = entity_spawner
	
	func buffer_input_for_client(client_peer_id: int, input: InputState):
		var queue_factory: Callable = func(x): 
			return RefillingQueue.new(true, "sv_input_buf_size[cl=%s]" % client_peer_id)
		var input_buffer_for_client: RefillingQueue = Utils.compute_if_absent(
			input_buffer_per_client_id_, client_peer_id, queue_factory)
		input_buffer_for_client.push(input)
	
	func get_latest_input_per_client(world_state: Dictionary) -> Dictionary:
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

class CharacterSimulation:
	const EMPTY_INPUT_FOR_BUFFERING = { "INPUT": "EMPTY" }
	const ARTIFICIAL_INPUT_BUFFER_AMOUNT = 6
	
	var client_id_: int
	var character_
	var messages_: Array = []
	var network_messenger_: NetworkMessenger
	var character_physics_state_: Dictionary
	var rng_ = RandomNumberGenerator.new()
	
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
		LogsAndMetrics.add_sample("sv_buffer_size", client_inputs.size())
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
