extends Node
class_name Server

@onready var entity_spawner_: EntitySpawner = $EntitySpawner
@onready var client_input_subscribers_ := InputSubscriptionsForActiveClients.new()

var game_simulation_: ServerGameSimulation
var network_message_bus_: NetworkMessageAndEventBus
var authoritative_state_exporter_ := ServerToClientStateSnapshotExporter.new()

func _ready() -> void:
	network_message_bus_ = NetworkMessageAndEventBus.new()
	game_simulation_ = ServerGameSimulation.new(entity_spawner_, network_message_bus_)
	game_simulation_.simulation_state_advanced.connect(authoritative_state_exporter_.export_state_snapshots_to_clients)
	authoritative_state_exporter_.export_state_snapshot.connect(network_message_bus_.send_state_snapshot_to_client)
	network_message_bus_.received_client_trigger.connect(client_input_subscribers_.dispatch_input_trigger)
	network_message_bus_.received_client_input.connect(client_input_subscribers_.dispatch_input_message)
	network_message_bus_.client_disconnected.connect(client_input_subscribers_.remove_client_session)
	network_message_bus_.client_connected.connect(client_input_subscribers_.add_new_client_session)
	add_child(network_message_bus_)

func _physics_process(_delta: float) -> void:
	var latest_input_per_connected_client_id := client_input_subscribers_.get_latest_input_per_connected_client_id()
	game_simulation_.advance_simulation(latest_input_per_connected_client_id)

class ServerGameSimulation:
	signal simulation_state_advanced(tick: int, current_simulation_state: Dictionary)

	const OVERWRITE_EXISTING = true
	const RESPAWN_TIME_IN_TICKS := 300
	const ENTITY_ID_WILL_BE_SET_UPON_ADDING_TO_STATE_MAP := 0
	const SPAWN_POINT_HORIZONTAL_OFFSET := 40.0
	const SPAWN_POINT_VERTICAL_OFFSET := 15.0
	const SPAWN_POINTS := [
		Vector3(SPAWN_POINT_HORIZONTAL_OFFSET, SPAWN_POINT_VERTICAL_OFFSET, SPAWN_POINT_HORIZONTAL_OFFSET),
		Vector3(SPAWN_POINT_HORIZONTAL_OFFSET, SPAWN_POINT_VERTICAL_OFFSET, -SPAWN_POINT_HORIZONTAL_OFFSET),
		Vector3(-SPAWN_POINT_HORIZONTAL_OFFSET, SPAWN_POINT_VERTICAL_OFFSET, SPAWN_POINT_HORIZONTAL_OFFSET),
		Vector3(-SPAWN_POINT_HORIZONTAL_OFFSET, SPAWN_POINT_VERTICAL_OFFSET, -SPAWN_POINT_HORIZONTAL_OFFSET),
		Vector3(0, SPAWN_POINT_VERTICAL_OFFSET, SPAWN_POINT_HORIZONTAL_OFFSET),
		Vector3(0, SPAWN_POINT_VERTICAL_OFFSET, -SPAWN_POINT_HORIZONTAL_OFFSET),
		Vector3(-SPAWN_POINT_HORIZONTAL_OFFSET, SPAWN_POINT_VERTICAL_OFFSET, 0),
		Vector3(-SPAWN_POINT_HORIZONTAL_OFFSET, SPAWN_POINT_VERTICAL_OFFSET, 0)
	]

	var entity_spawner_: EntitySpawner
	var network_message_bus_: NetworkMessageAndEventBus
	var simulation_state_: SimulationState = SimulationState.new()
	var simulation_state_per_server_tick_ := {}
	var tick_ := 0

	func _init(entity_spawner: EntitySpawner, network_message_bus: NetworkMessageAndEventBus) -> void:
		entity_spawner_ = entity_spawner
		network_message_bus_ = network_message_bus

	func advance_simulation(latest_input_per_connected_client_id: Dictionary) -> void:
		var tracer_displayer := entity_spawner_.get_or_create_tracer_displayer()
		var debug_sphere_displayer := entity_spawner_.get_or_create_debug_sphere_displayer()
		
		__create_player_states_for_connected_clients_without_player(latest_input_per_connected_client_id.keys())
		__delete_player_states_for_disconnected_clients(latest_input_per_connected_client_id.keys())
		__advance_respawn_timers_for_players()
		__delete_character_states_without_corresponding_player()
		__delete_character_states_for_dead_players()
		__create_character_states_for_living_players_and_notify_clients()
		__populate_character_states_with_latest_input(latest_input_per_connected_client_id)
		var hitscan_results := __compute_hitscan_ability_results(
			simulation_state_, simulation_state_per_server_tick_, entity_spawner_)
		var next_character_state_per_client_id := __compute_next_state_for_characters(
			simulation_state_, hitscan_results, entity_spawner_)

		__display_character_states(next_character_state_per_client_id, entity_spawner_)
		__draw_bullet_tracers(tracer_displayer, hitscan_results)
		__draw_bullet_hits(debug_sphere_displayer, hitscan_results)

		for client_id: int in next_character_state_per_client_id:
			var next_character_state: ServerCharacterState = next_character_state_per_client_id[client_id]
			if next_character_state.health_state.health() <= 0:
				next_character_state_per_client_id.erase(client_id)
				simulation_state_.character_state_per_client_id.erase(client_id)
				simulation_state_.player_life_death_state_per_client_id[client_id] = (
					PlayerLifeDeathState.new(RESPAWN_TIME_IN_TICKS))
				network_message_bus_.notify_client_of_death(client_id)

		entity_spawner_.despawn_entities_not_in_server_snapshot(next_character_state_per_client_id)
		__replicate_ability_trigger_on_remote_characters(next_character_state_per_client_id)
		
		simulation_state_advanced.emit(tick_, next_character_state_per_client_id)
		simulation_state_.character_state_per_client_id = next_character_state_per_client_id
		
		simulation_state_per_server_tick_[tick_] = simulation_state_.deep_copy()
		__clear_stale_simulation_states()
		tick_ += 1

	func __create_player_states_for_connected_clients_without_player(connected_client_ids: Array) -> void:
		for connected_client_id: int in connected_client_ids:
			if not connected_client_id in simulation_state_.player_life_death_state_per_client_id:
				simulation_state_.player_life_death_state_per_client_id[connected_client_id] = PlayerLifeDeathState.new()

	func __delete_player_states_for_disconnected_clients(connected_client_ids: Array) -> void:
		for client_id_for_existing_player: int in simulation_state_.player_life_death_state_per_client_id:
			if not client_id_for_existing_player in connected_client_ids:
				simulation_state_.player_life_death_state_per_client_id.erase(client_id_for_existing_player)

	func __advance_respawn_timers_for_players() -> void:
		for client_id_for_existing_player: int in simulation_state_.player_life_death_state_per_client_id:
			var player_life_death_state: PlayerLifeDeathState = (
				simulation_state_.player_life_death_state_per_client_id[client_id_for_existing_player])
			player_life_death_state.ticks_until_respawn = max(0, player_life_death_state.ticks_until_respawn - 1)

	func __delete_character_states_without_corresponding_player() -> void:
		for client_id_for_existing_character: int in simulation_state_.character_state_per_client_id:
			if not client_id_for_existing_character in simulation_state_.player_life_death_state_per_client_id:
				simulation_state_.character_state_per_client_id.erase(client_id_for_existing_character)

	func __delete_character_states_for_dead_players() -> void:
		for client_id_for_existing_character: int in simulation_state_.character_state_per_client_id:
			if client_id_for_existing_character in simulation_state_.player_life_death_state_per_client_id:
				var player_life_death_state: PlayerLifeDeathState = (
					simulation_state_.player_life_death_state_per_client_id[client_id_for_existing_character])
				if player_life_death_state.ticks_until_respawn > 0:
					simulation_state_.character_state_per_client_id.erase(client_id_for_existing_character)

	func __create_character_states_for_living_players_and_notify_clients() -> void:
		var newly_respawned_client_ids := __create_character_states_for_living_players_without_character()
		__notify_clients_of_respawn(newly_respawned_client_ids)

	func __create_character_states_for_living_players_without_character() -> Array[int]:
		var newly_respawned_client_ids: Array[int] = []
		for client_id_for_existing_player: int in simulation_state_.player_life_death_state_per_client_id:
			var player_life_death_state: PlayerLifeDeathState = (
				simulation_state_.player_life_death_state_per_client_id[client_id_for_existing_player])
			var is_player_alive: = player_life_death_state.ticks_until_respawn == 0 
			var does_character_already_exist_for_player := (
				client_id_for_existing_player in simulation_state_.character_state_per_client_id)
			if is_player_alive and not does_character_already_exist_for_player:
				var character_state_at_spawn := __create_spawn_state_with_random_position()
				simulation_state_.create_character(client_id_for_existing_player, character_state_at_spawn)
				newly_respawned_client_ids.append(client_id_for_existing_player)
		return newly_respawned_client_ids

	func __notify_clients_of_respawn(newly_respawned_player_client_ids: Array[int]) -> void:
		for newly_respawned_client_id: int in newly_respawned_player_client_ids:
			network_message_bus_.notify_client_of_respawn(newly_respawned_client_id)

	func __populate_character_states_with_latest_input(latest_input_per_connected_client_id: Dictionary) -> void:
		for client_id_for_existing_character: int in simulation_state_.character_state_per_client_id:
			var character_state: ServerCharacterState = (
				simulation_state_.character_state_per_client_id[client_id_for_existing_character])
			var latest_client_input: InputStateAndTriggers = (
				latest_input_per_connected_client_id[client_id_for_existing_character])
			simulation_state_.character_state_per_client_id[client_id_for_existing_character] = (
				character_state.with_input(latest_client_input))

	func __clear_stale_simulation_states() -> void:
		for stale_tick: int in simulation_state_per_server_tick_.keys():
			if stale_tick < tick_ - 100:
				simulation_state_per_server_tick_.erase(stale_tick)

	func __replicate_ability_trigger_on_remote_characters(character_state_per_client_id: Dictionary) -> void:
		for client_id: int in character_state_per_client_id:
			var character_state: ServerCharacterState = character_state_per_client_id[client_id]
			for ability_trigger: InputTrigger in character_state.input.input_triggers:
				network_message_bus_.trigger_remote_character_ability(
					character_state.character_entity_id, ability_trigger.camera_transform, tick_)

	static func __create_spawn_state_with_random_position() -> ServerCharacterState:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var randomly_chosen_spawn_point: Vector3 = SPAWN_POINTS[rng.randi() % SPAWN_POINTS.size()]
		return ServerCharacterState.new(
			CharacterPhysicsState.new(randomly_chosen_spawn_point, Vector3.ZERO, false), 
			CharacterHealthState.DEFAULT_HEALTH_STATE,
			ENTITY_ID_WILL_BE_SET_UPON_ADDING_TO_STATE_MAP,
			InputStateAndTriggers.new(InputState.DEFAULT, []))

	static func __compute_next_state_for_characters(
		current_simulation_state: SimulationState,
		hitscan_results: Array[HitscanResult],
		entity_spawner: EntitySpawner
	) -> Dictionary:
		var next_world_state := {}
		for client_id: int in current_simulation_state.character_state_per_client_id:
			var character_state: ServerCharacterState = (
				current_simulation_state.character_state_per_client_id[client_id])
			var character_entity_id := character_state.character_entity_id
			var character_components := entity_spawner.get_or_spawn_server_character(character_entity_id)
			var next_physics_state := character_components.movement_body().compute_next_physics_state(
					character_state.physics_state, character_state.input.input_state)
			var current_health := character_state.health_state.health()
			for hitscan_result: HitscanResult in hitscan_results:
				if hitscan_result.hit_entity_id == character_entity_id:
					current_health -= hitscan_result.damage
			var next_health_state := CharacterHealthState.new(current_health)			
			next_world_state[client_id] = character_state.with_physics_and_health_state(
				next_physics_state, next_health_state)
		return next_world_state

	static func __display_character_states(
		next_character_state_per_client_id: Dictionary,
		entity_spawner: EntitySpawner
	) -> void:
		for client_id: int in next_character_state_per_client_id:
			var next_character_state: ServerCharacterState = next_character_state_per_client_id[client_id]
			var character_components := entity_spawner.get_or_spawn_server_character(
				next_character_state.character_entity_id)
			var character_transform_state := __extract_transform_state(next_character_state)
			character_components.third_person_display().display_character_transform(character_transform_state)
			character_components.first_person_display().display_character_state(
				character_transform_state, next_character_state.health_state.health())

	static func __extract_transform_state(character_state: ServerCharacterState) -> CharacterTransformState:
		return CharacterTransformState.new(
				character_state.physics_state.position(), 
				character_state.input.input_state.pitch(), 
				character_state.input.input_state.yaw())

	static func __compute_hitscan_ability_results(
		current_simulation_state: SimulationState,
		simulation_state_per_server_tick: Dictionary,
		entity_spawner: EntitySpawner
	) -> Array[HitscanResult]:
		var hitscan_ability_results: Array[HitscanResult] = []
		for client_id: int in current_simulation_state.character_state_per_client_id:
			var character_state: ServerCharacterState = (
				current_simulation_state.character_state_per_client_id[client_id])
			var character_entity_id := character_state.character_entity_id
			var character_components := entity_spawner.get_or_spawn_server_character(character_entity_id)
			for ability_trigger: InputTrigger in character_state.input.input_triggers:
				var simulation_state_at_time_of_trigger: SimulationState = (
					simulation_state_per_server_tick[ability_trigger.server_tick_displayed_on_client])
				var lag_compensated_world_state: Dictionary
				if simulation_state_at_time_of_trigger != null:
					lag_compensated_world_state = simulation_state_at_time_of_trigger.character_state_per_client_id
				else:
					print("Cannot lag compensate hitscan ability against state with tick %d. Current tick: %d" % [
						ability_trigger.server_tick_displayed_on_client])
					lag_compensated_world_state = current_simulation_state.character_state_per_client_id
				var other_character_positions_during_current_tick := (
					__extract_positions_for_other_characters(lag_compensated_world_state, character_entity_id))
				var ability_result := character_components.ability_action().perform_ability(
					ability_trigger.camera_transform, other_character_positions_during_current_tick)
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

	static func __extract_positions_for_other_characters(
		world_state: Dictionary, 
		own_character_entity_id: int
	) -> Dictionary:
		var other_character_positions_per_entity_id: Dictionary = {}
		for client_id: int in world_state:
			var character_state: ServerCharacterState = world_state[client_id]
			var character_entity_id := character_state.character_entity_id
			if character_entity_id != own_character_entity_id:
				other_character_positions_per_entity_id[character_entity_id] = (
					character_state.physics_state.position())
		return other_character_positions_per_entity_id

	class PlayerLifeDeathState:
		var ticks_until_respawn: int

		func _init(ticks_until_respawn: int = 0) -> void:
			self.ticks_until_respawn = ticks_until_respawn

	class SimulationState:
		var next_character_entity_id_: int = 0

		var player_life_death_state_per_client_id: Dictionary = {}
		var character_state_per_client_id: Dictionary = {}

		func _init(
			next_character_entity_id_: int = 0, 
			player_life_death_state_per_client_id: Dictionary = {}, 
			character_state_per_client_id: Dictionary = {}
		) -> void:
			self.next_character_entity_id_ = next_character_entity_id_
			self.player_life_death_state_per_client_id = player_life_death_state_per_client_id
			self.character_state_per_client_id = character_state_per_client_id

		func create_character(client_id: int, state: ServerCharacterState) -> void:
			assert(
				client_id not in character_state_per_client_id, 
				"Attempting to create character for client %d which already has character" % client_id)
			character_state_per_client_id[client_id] = state.with_entity_id(next_character_entity_id_)
			next_character_entity_id_ += 1
		
		func delete_character(client_id: int) -> void:
			character_state_per_client_id.erase(client_id)
		
		func deep_copy() -> SimulationState:
			return SimulationState.new(
				next_character_entity_id_, 
				player_life_death_state_per_client_id.duplicate(true), 
				character_state_per_client_id.duplicate(true))

class InputSubscriptionsForActiveClients:
	static var CLIENT_INPUT_BUFFER_FACTORY: Callable = func(x: int) -> OrderedInputBuffer: 
		return OrderedInputBuffer.new("sv_input_buf[%10d]" % x)
	
	var input_source_per_active_client_id_ := {}

	func add_new_client_session(client_id: int) -> void:
		var input_buffer_for_client: OrderedInputBuffer = CLIENT_INPUT_BUFFER_FACTORY.call(client_id)
		input_source_per_active_client_id_[client_id] = InputBufferAndPendingTriggers.new(input_buffer_for_client, [])

	func remove_client_session(client_id: int) -> void:
		input_source_per_active_client_id_.erase(client_id)

	func dispatch_input_message(client_id: int, input: InputState) -> void:
		if client_id in input_source_per_active_client_id_:
			var client_input_source: InputBufferAndPendingTriggers = input_source_per_active_client_id_[client_id]
			var input_buffer_for_client := client_input_source.input_buffer
			input_buffer_for_client.push(input)
		else:
			print("Cannot enqueue input %s from client %d. No input buffer initialized." % [input, client_id])
	
	func dispatch_input_trigger(
		client_id: int, 
		camera_transform: Transform3D, 
		server_tick_displayed_on_client: int
	) -> void:
		if client_id in input_source_per_active_client_id_:
			var client_input_source: InputBufferAndPendingTriggers = input_source_per_active_client_id_[client_id]
			var pending_triggers_for_client := client_input_source.pending_triggers
			pending_triggers_for_client.append(InputTrigger.new(server_tick_displayed_on_client, camera_transform))
		else:
			print("Cannot enqueue trigger from client %d. No input tracker active." % client_id)

	func get_latest_input_per_connected_client_id() -> Dictionary:
		var latest_input_per_client := {}
		for client_id: int in input_source_per_active_client_id_:
			var client_input_source: InputBufferAndPendingTriggers = input_source_per_active_client_id_[client_id]
			latest_input_per_client[client_id] = client_input_source.pop_latest_input_state_and_triggers()
		return latest_input_per_client

	class InputBufferAndPendingTriggers:
		var input_buffer: OrderedInputBuffer
		var pending_triggers: Array[InputTrigger]

		func _init(input_buffer: OrderedInputBuffer, pending_triggers: Array[InputTrigger]) -> void:
			self.input_buffer = input_buffer
			self.pending_triggers = pending_triggers
		
		func pop_latest_input_state_and_triggers() -> InputStateAndTriggers:
			var latest_input_state := input_buffer.pop()
			var triggers_to_return := pending_triggers.duplicate()
			pending_triggers.clear()
			return InputStateAndTriggers.new(latest_input_state, triggers_to_return)

class ServerToClientStateSnapshotExporter:
	signal export_state_snapshot(client_id: int, server_tick: int, snapshot: ServerToClientStateSnapshotMessage)

	static var EMPTY_ABILITY_TRIGGER_STATE := CharacterAbilityTriggerState.new(0)

	func export_state_snapshots_to_clients(server_tick: int, next_character_state_per_client_id: Dictionary) -> void:
		var data_to_export_per_client := __compile_data_to_export_per_client(next_character_state_per_client_id)
		for client_id: int in data_to_export_per_client:
			__export_state_snapshot_to_client(client_id, server_tick, data_to_export_per_client)
	
	func __export_state_snapshot_to_client(
		client_id: int, 
		server_tick: int, 
		data_to_export_per_client: Dictionary
	) -> void:
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
		export_state_snapshot.emit(client_id, server_tick, state_snapshot_for_client)

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
	
	static func __compile_data_to_export_per_client(next_character_state_per_client_id: Dictionary) -> Dictionary:
		var data_to_export_per_client := {}
		for client_id: int in next_character_state_per_client_id:
			var next_character_state: ServerCharacterState = next_character_state_per_client_id[client_id]
			var next_transform_state := __extract_transform_state(next_character_state)
			data_to_export_per_client[client_id] = PerClientExportedData.new(
				next_character_state.input.input_state.client_tick(),
				next_character_state.physics_state,
				next_character_state.health_state,
				next_transform_state,
				next_character_state.character_entity_id)
		return data_to_export_per_client
	
	static func __extract_transform_state(character_state: ServerCharacterState) -> CharacterTransformState:
		return CharacterTransformState.new(
				character_state.physics_state.position(), 
				character_state.input.input_state.pitch(), 
				character_state.input.input_state.yaw())
	
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

class ServerCharacterState:
	var physics_state: CharacterPhysicsState
	var health_state: CharacterHealthState
	var character_entity_id: int
	var input: InputStateAndTriggers

	func _init(
		physics_state: CharacterPhysicsState, 
		health_state: CharacterHealthState,
		character_entity_id: int,
		input: InputStateAndTriggers
	) -> void:
		self.physics_state = physics_state
		self.health_state = health_state
		self.character_entity_id = character_entity_id
		self.input = input
	
	func with_input(new_client_input: InputStateAndTriggers) -> ServerCharacterState:
		return ServerCharacterState.new(
			physics_state,
			health_state,
			character_entity_id,
			new_client_input)
	
	func with_entity_id(new_character_entity_id: int) -> ServerCharacterState:
		return ServerCharacterState.new(
			physics_state,
			health_state,
			new_character_entity_id,
			input)
	
	func with_physics_and_health_state(
		new_physics_state: CharacterPhysicsState, 
		new_health_state: CharacterHealthState
	) -> ServerCharacterState:
		return ServerCharacterState.new(
			new_physics_state, 
			new_health_state, 
			character_entity_id,
			input)

	func _to_string() -> String:
		return "ServerCharacterState<physics_state=%s, health_state=%s, client_tick_for_input=%s, " \
				+ "character_entity_id=%s, input=%s>" % [
			physics_state,
			health_state,
			character_entity_id,
			input
		]

class InputStateAndTriggers:
	var input_state: InputState
	var input_triggers: Array[InputTrigger]

	func _init(input_state: InputState, input_triggers: Array[InputTrigger]) -> void:
		self.input_state = input_state
		self.input_triggers = input_triggers

class InputTrigger:
	var server_tick_displayed_on_client: int
	var camera_transform: Transform3D

	func _init(server_tick_displayed_on_client: int, camera_transform: Transform3D) -> void:
		self.server_tick_displayed_on_client = server_tick_displayed_on_client
		self.camera_transform = camera_transform
