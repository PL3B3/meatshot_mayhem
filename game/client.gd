extends Node
class_name Client

# _physics_process is called a bunch of times in quick succession on startup
# so it will flood the server with like 8 messages, creating a megabuffer
# set to 0 to disable, if you want the buffer
const WARMUP_TIME = 0.2
const RECONCILIATION_SNAP_IF_ABOVE = 11.0
const RECONCILIATION_SNAP_IF_BELOW = 0.001
const RECONCILIATION_POSITION_CORRECTION_SPEED_CAP_UNITS_PER_TICK = 0.2
const RECONCILIATION_POSITION_CORRECTION_LINEAR_FRACTION = 0.15
const RECONCILIATION_VELOCITY_CORRECTION_LINEAR_FRACTION = 0.5
const RECONCILIATION_MAX_TICKS_REPLAYED = 16
const TIME_BETWEEN_PROCESS_CALLS_STAT = "time_between_process_calls"
const ENABLE_LOGGING := false

@onready var input_handler_: ClientInputHandler = $ClientInputHandler
@onready var network_messenger_: NetworkMessenger = $NetworkMessenger
@onready var debug_label_: Label = $DebugLabel
@onready var entity_spawner_: EntitySpawner = $EntitySpawner
@onready var death_screen_: Control = $DeathScreen

var client_state_timeline_: ClientStateTimeline = ClientStateTimeline.new()
var client_state_buffer_: RefillingQueue
var pending_remote_character_triggers_: Array[int] = []
var recent_client_to_server_inputs_: Array[Dictionary] = []
var ticks_to_keep_running_after_death_ := 0
var is_alive_ := true
var warmed_up = false

@rpc("authority", "call_local", "reliable")
func resize_window(index=0):
	var screen_size: Vector2 = DisplayServer.screen_get_size()
	get_window().size = Vector2(screen_size.x / 2.01, screen_size.y / 2)
	get_window().position = Vector2(screen_size.x + (index * (screen_size.x * 0.5)), 0)

@rpc("authority", "reliable")
func trigger_ability_for_remote_character(remote_character_entity_id: int):
	pending_remote_character_triggers_.append(remote_character_entity_id)

@rpc("authority", "reliable")
func handle_death() -> void:
	death_screen_.show()
	is_alive_ = false
	ticks_to_keep_running_after_death_ = 1

@rpc("authority", "reliable")
func handle_respawn() -> void:
	entity_spawner_.despawn_all_entities()
	pending_remote_character_triggers_.clear()
	input_handler_.reset_view_angle()
	client_state_buffer_.clear_items()
	death_screen_.hide()
	is_alive_ = true

func _ready():
	resize_window()
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	network_messenger_.received_server_message.connect(_handle_server_message)
	get_tree().create_timer(WARMUP_TIME).timeout.connect(func(): warmed_up = true)
	LogsAndMetrics.add_client_stat("sim_error", 1000)
	LogsAndMetrics.add_client_stat(TIME_BETWEEN_PROCESS_CALLS_STAT, 1000, true)
	start_client()

func start_client():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(Network.DEFAULT_SERVER_IP, Network.PORT)
	if error: 
		return error
	multiplayer.multiplayer_peer = peer
	print("PEERS COUNT: ", multiplayer.get_peers().size())

func _handle_server_message(message: Dictionary):
	var server_snapshot := ServerToClientStateSnapshotMessage.from_dict(message)
	client_state_buffer_.push(server_snapshot)
	if !client_state_timeline_.has_states():
		client_state_timeline_.add_next_state(server_snapshot.client_state_snapshot())

func _on_peer_connected(id: int):
	print("Peer with id ", id, " connected")

func _on_peer_disconnected(id: int):
	print("Peer with id ", id, " disconnected")

func _on_connected_to_server():
	debug_label_.text = "CLIENT %d" % multiplayer.get_unique_id()
	client_state_buffer_ = RefillingQueue.new("cl_state_buf[%10d]" % multiplayer.get_unique_id(), true)

func _process(_delta):
	LogsAndMetrics.add_sample(TIME_BETWEEN_PROCESS_CALLS_STAT, Time.get_ticks_usec())
	if Input.is_action_just_pressed("toggle_window_mode"):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func __should_run_game_simulation() -> bool:
	return (
		warmed_up and
		client_state_timeline_.has_states() and
		(is_alive_ or ticks_to_keep_running_after_death_ > 0))

func _physics_process(_delta):
	if __should_run_game_simulation():
		run_game_simulation_tick()
	ticks_to_keep_running_after_death_ = max(0, ticks_to_keep_running_after_death_ - 1)

func run_game_simulation_tick() -> void:
	var current_state: ClientStateSnapshot = client_state_timeline_.get_current_state()
	var own_character_components: CharacterComponents = entity_spawner_.get_or_spawn_client_own_character()
	var latest_input: InputState = input_handler_.get_and_record_latest_input(client_state_timeline_.get_next_tick())
	var own_character_physics_state: CharacterPhysicsState = current_state.own_character_state().physics_state()
	var own_character_transform_state: CharacterTransformState = CharacterTransformState.new(
		own_character_physics_state.position(), latest_input.pitch(), latest_input.yaw())
	
	var latest_remote_character_state_per_entity_id: Dictionary
	var latest_own_character_health_state: CharacterHealthState
	var reconciliation_data: Optional
	var latest_server_snapshot_item: QueueItem = __get_latest_queued_authoritative_state_snapshot()
	if latest_server_snapshot_item.is_valid():
		var latest_server_state_snapshot: ServerToClientStateSnapshotMessage = latest_server_snapshot_item.value()
		latest_remote_character_state_per_entity_id = (
			latest_server_state_snapshot.client_state_snapshot().remote_character_states())
		latest_own_character_health_state = (
			latest_server_state_snapshot.client_state_snapshot().own_character_state().health_state())
		if latest_server_state_snapshot.client_tick() != Network.NO_TICK:
			reconciliation_data = Optional.of(
				ReconciliationData.from_server_to_client_snapshot(latest_server_state_snapshot))
		else:
			reconciliation_data = Optional.empty()
	else:
		latest_remote_character_state_per_entity_id = current_state.remote_character_states()
		latest_own_character_health_state = current_state.own_character_state().health_state()
		reconciliation_data = Optional.empty()
	
	var remote_character_resources: Array[RemoteCharacterResource] = []
	var remote_character_latest_position_per_entity_id: Dictionary = {}
	for remote_character_entity_id in latest_remote_character_state_per_entity_id:
		var remote_character_state: CharacterTransformState = (
			latest_remote_character_state_per_entity_id[remote_character_entity_id])
		var remote_character_components: CharacterComponents = (
			entity_spawner_.get_or_spawn_character(remote_character_entity_id, CONSTANTS.NetworkEntityMode.OTHER_CLIENT))
		var remote_character_resource: RemoteCharacterResource = RemoteCharacterResource.new(
			remote_character_state, remote_character_components.third_person_display())
		remote_character_resources.push_back(remote_character_resource)
		remote_character_latest_position_per_entity_id[remote_character_entity_id] = remote_character_state.position()

	var optionally_reconciled_own_character_physics_state: CharacterPhysicsState = (
		__reconcile_own_character_physics_state_with_authoritative_state(
			reconciliation_data, 
			own_character_physics_state, 
			own_character_components.movement_body(), 
			client_state_timeline_.get_current_tick()))
	
	__display_own_character(
		latest_own_character_health_state.health(),
		own_character_transform_state, 
		own_character_components.first_person_display())
	__display_remote_characters(remote_character_resources)
	var next_own_character_physics_state: CharacterPhysicsState = __compute_next_physics_state(
		optionally_reconciled_own_character_physics_state, 
		own_character_components.movement_body(), 
		latest_input)
	var hitscan_ability_results: Array[HitscanResult] = []
	var ability_trigger_result := own_character_components.ability_trigger_state_machine().compute_trigger_result(
		current_state.own_character_state().ability_trigger_state(), latest_input)
	if ability_trigger_result.is_triggered:
		var current_camera_transform := (
			own_character_components.first_person_display().compute_camera_transform(own_character_transform_state))
		var ability_result := own_character_components.ability_action().perform_ability(
			current_camera_transform, remote_character_latest_position_per_entity_id)
		hitscan_ability_results.append_array(ability_result.hitscan_results)
	
	var remote_character_hitscan_ability_results := __perform_remote_character_abilities(
		own_character_physics_state.position(), latest_remote_character_state_per_entity_id)
	hitscan_ability_results.append_array(remote_character_hitscan_ability_results)
	
	__draw_bullet_tracers(hitscan_ability_results)
	__draw_bullet_hits(hitscan_ability_results)

	var next_own_character_state := ClientOwnCharacterState.new(
		next_own_character_physics_state, 
		ability_trigger_result.next_trigger_state, 
		latest_own_character_health_state)
	var next_state: ClientStateSnapshot = ClientStateSnapshot.new(
		next_own_character_state, latest_remote_character_state_per_entity_id)
	client_state_timeline_.add_next_state(next_state)
	entity_spawner_.despawn_entities_not_in_client_snapshot(next_state)
	var tick_for_state_computed_using_latest_input = client_state_timeline_.get_current_tick()
	var input_message_to_export := ClientToServerInputMessage.new(
		tick_for_state_computed_using_latest_input, 
		ClientInput.new(latest_input, ability_trigger_result.is_triggered))
	__send_recent_inputs_to_server(input_message_to_export.to_dict())

func __perform_remote_character_abilities(
	own_character_position: Vector3, 
	latest_remote_character_state_per_entity_id: Dictionary
) -> Array[HitscanResult]:
	var remote_character_hitscan_ability_results: Array[HitscanResult] = []
	for remote_character_entity_id: int in pending_remote_character_triggers_:
		if remote_character_entity_id in latest_remote_character_state_per_entity_id:
			var remote_character_state: CharacterTransformState = (
				latest_remote_character_state_per_entity_id[remote_character_entity_id])
			var remote_character_components: CharacterComponents = entity_spawner_.get_or_spawn_character(
				remote_character_entity_id, CONSTANTS.NetworkEntityMode.OTHER_CLIENT)
			var remote_character_camera_rotation_in_euler_angles := Vector3(
				deg_to_rad(remote_character_state.pitch()), deg_to_rad(remote_character_state.yaw()), 0)
			var remote_character_camera_transform := Transform3D(
				Basis.from_euler(remote_character_camera_rotation_in_euler_angles),
				remote_character_state.position() + Vector3(0, 0.75, 0))
			var ability_result := remote_character_components.ability_action().perform_ability(
				remote_character_camera_transform, 
				__extract_positions_for_characters_except_remote_character(
					own_character_position,
					latest_remote_character_state_per_entity_id,
					remote_character_entity_id))
			remote_character_hitscan_ability_results.append_array(ability_result.hitscan_results)
	pending_remote_character_triggers_.clear()
	return remote_character_hitscan_ability_results

func __extract_positions_for_characters_except_remote_character(
	own_character_position: Vector3,
	latest_remote_character_state_per_entity_id: Dictionary,
	remote_character_entity_id_to_exclude: int
) -> Dictionary:
	var positions_for_all_but_specified_character: Dictionary = {}
	positions_for_all_but_specified_character[RaycastUtils.NO_ENTITY_HIT] = own_character_position
	for remote_character_entity_id: int in latest_remote_character_state_per_entity_id:
		if remote_character_entity_id != remote_character_entity_id_to_exclude:
			var remote_character_transform: CharacterTransformState = (
				latest_remote_character_state_per_entity_id[remote_character_entity_id])
			positions_for_all_but_specified_character[remote_character_entity_id] = (
				remote_character_transform.position())
	return positions_for_all_but_specified_character

func __draw_bullet_tracers(hitscan_results: Array[HitscanResult]) -> void:
	var tracer_displayer := entity_spawner_.get_or_create_tracer_displayer()
	for hitscan_result: HitscanResult in hitscan_results:
		tracer_displayer.add_tracer(hitscan_result.origin, hitscan_result.hit_point)
	tracer_displayer.display_and_update_tracers()

func __draw_bullet_hits(hitscan_results: Array[HitscanResult]) -> void:
	var debug_sphere_displayer := entity_spawner_.get_or_create_debug_sphere_displayer()
	for hitscan_result: HitscanResult in hitscan_results:
		debug_sphere_displayer.draw_debug_sphere(hitscan_result.hit_point)

func __get_latest_queued_authoritative_state_snapshot() -> QueueItem:
	if client_state_buffer_ == null:
		return QueueItem.DUMMY_ITEM
	return client_state_buffer_.pop()

func __reconcile_own_character_physics_state_with_authoritative_state(
	optional_reconciliation_data: Optional,
	predicted_player_physics_state: CharacterPhysicsState, 
	character_movement_calculator: CharacterMovementActuator,
	current_tick: int
) -> CharacterPhysicsState:
	if optional_reconciliation_data.is_present():
		var authoritative_physics_state_and_tick: ReconciliationData = optional_reconciliation_data.value()
		var reconciliation_replay_start_tick
		if authoritative_physics_state_and_tick.client_tick() < current_tick - RECONCILIATION_MAX_TICKS_REPLAYED:
			__log(
				"Server state with tick %d is too old to replay all inputs since. Replaying last %d inputs.", 
				[authoritative_physics_state_and_tick.client_tick(), RECONCILIATION_MAX_TICKS_REPLAYED])
			reconciliation_replay_start_tick = current_tick - RECONCILIATION_MAX_TICKS_REPLAYED
		else:
			reconciliation_replay_start_tick = authoritative_physics_state_and_tick.client_tick() + 1
		var simulated_authoritative_physics_state: CharacterPhysicsState = __replay_physics_computation_using_inputs(
			authoritative_physics_state_and_tick.physics_state(),
			input_handler_.get_inputs_since_tick(reconciliation_replay_start_tick),
			character_movement_calculator)
		var corrected_state = __correct_predicted_physics_state_towards_simulated_authoritative_state(
			predicted_player_physics_state, simulated_authoritative_physics_state)
		__log(
			"Reconciling with state %s for tick %d. inputs: %s", [
				authoritative_physics_state_and_tick.physics_state(), 
				reconciliation_replay_start_tick,
				input_handler_.get_inputs_since_tick(reconciliation_replay_start_tick)
			])
		__log(
			"Predicted state: %s.\nSimulated state: %s. Corrected state: %s",
			[predicted_player_physics_state, simulated_authoritative_physics_state, corrected_state])
		return corrected_state
	else:
		return predicted_player_physics_state

func __correct_predicted_physics_state_towards_simulated_authoritative_state(
	predicted_state: CharacterPhysicsState, 
	simulated_state: CharacterPhysicsState
) -> CharacterPhysicsState:
	var position_error: Vector3 = simulated_state.position() - predicted_state.position()
	var velocity_error: Vector3 = simulated_state.velocity() - predicted_state.velocity()
	__log(
		"position err: %+00.4f. velocity err: %+00.4f",
		[position_error.length(), velocity_error.length()])
	if (position_error.length() > RECONCILIATION_SNAP_IF_ABOVE 
		or position_error.length() < RECONCILIATION_SNAP_IF_BELOW):
		return simulated_state
	else:
		var position_correction_direction: Vector3 = position_error.normalized()
		var position_correction_magnitude: float = min(
			RECONCILIATION_POSITION_CORRECTION_SPEED_CAP_UNITS_PER_TICK,
			RECONCILIATION_POSITION_CORRECTION_LINEAR_FRACTION * position_error.length())
		var corrected_position: Vector3 = (
			predicted_state.position() + position_correction_magnitude * position_correction_direction)
		var corrected_velocity = predicted_state.velocity().lerp(
			simulated_state.velocity(), RECONCILIATION_VELOCITY_CORRECTION_LINEAR_FRACTION)
		return CharacterPhysicsState.new(corrected_position, corrected_velocity, simulated_state.is_grounded())

func __send_recent_inputs_to_server(latest_message: Dictionary) -> void:
	recent_client_to_server_inputs_.push_back(latest_message)
	while recent_client_to_server_inputs_.size() > 5:
		recent_client_to_server_inputs_.pop_front()
	var message := {
		"inputs": recent_client_to_server_inputs_.duplicate(true)
	}
	network_messenger_.send_message_to_server(message)

func __log(format_string: String, args: Array[Variant] = []) -> void:
	if ENABLE_LOGGING:
		print(format_string % args)

static func __compute_next_physics_state(
	current_physics_state: CharacterPhysicsState,
	movement_calculator: CharacterMovementActuator,
	player_input: InputState
) -> CharacterPhysicsState:
	return movement_calculator.compute_next_physics_state(current_physics_state, player_input)

static func __display_own_character(
	current_health: int,
	character_transform: CharacterTransformState,
	first_person_display: CharacterFirstPersonOutput) -> void:
	first_person_display.display_character_state(character_transform, current_health)

static func __display_remote_characters(remote_character_resources: Array[RemoteCharacterResource]):
	for remote_character_resource in remote_character_resources:
		remote_character_resource.third_person_display().display_character_transform(
			remote_character_resource.transform_state())

static func __replay_physics_computation_using_inputs(
	initial_player_state: CharacterPhysicsState,
	inputs_to_replay: Array[InputState],
	movement_calculator: CharacterMovementActuator
) -> CharacterPhysicsState:
	var simulation_state: CharacterPhysicsState = initial_player_state
	for simulation_input in inputs_to_replay:
		simulation_state = movement_calculator.compute_next_physics_state(simulation_state, simulation_input)
	return simulation_state

class ReconciliationData:
	var physics_state_: CharacterPhysicsState
	var client_tick_: int

	func _init(physics_state: CharacterPhysicsState, client_tick: int):
		physics_state_ = physics_state
		client_tick_ = client_tick
	
	static func from_server_to_client_snapshot(snapshot: ServerToClientStateSnapshotMessage) -> ReconciliationData:
		return ReconciliationData.new(
			snapshot.client_state_snapshot().own_character_state().physics_state(), 
			snapshot.client_tick())
	
	func physics_state() -> CharacterPhysicsState:
		return physics_state_
	
	func client_tick() -> int:
		return client_tick_

class RemoteCharacterResource:
	var transform_state_
	var third_person_display_

	func _init(transform_state, third_person_display):
		transform_state_ = transform_state
		third_person_display_ = third_person_display
	
	func transform_state() -> CharacterTransformState:
		return transform_state_
	
	func third_person_display() -> CharacterThirdPersonDisplay:
		return third_person_display_
