extends CharacterBody3D

class_name CharacterMovementActuator

const COLLISION_RADIUS = 2.5
const COLLISION_MARGIN = 0.005
const SPEED = COLLISION_RADIUS * 10
const GROUND_ACCEL = 10
const AIR_ACCEL = 4
const AIR_TURN_RATE = 3
const JUMP_HEIGHT: float = 2 * COLLISION_RADIUS
const JUMP_DURATION: float = 0.33
const GRAVITY: float = (2.0 * JUMP_HEIGHT) / (pow(JUMP_DURATION, 2))
const JUMP_FORCE: float = GRAVITY * JUMP_DURATION
const TOLERANCE:float = 0.01
const FULL_ROTATION_DEGREES = 360
const MOUSE_SENSITIVITY = 0.1
const SKIN_DEPTH = 0.01
const NO_POSITION_OFFSET_TO_ESCAPE_CREASE = Vector3.ZERO
const COLLIDE_AND_SLIDE_ITERATIONS = 4
const CONSTANT_DELTA = 1 / 60.0

const UP = Vector3.UP
const DOWN = -UP 
const FLOOR_CHECK_TOLERANCE:float = 0.01
const FLOOR_ANGLE:float = deg_to_rad(46)

@onready var debug_sphere = preload("res://scenes/debug_sphere.tscn")
@onready var camera = $Camera3D
@onready var last_position = global_position 
var yaw_: float = 0
var pitch_: float = 0
var game_tick_: int = 0
var enable_collision_logging_ = false
var collision_shape: SphereShape3D = SphereShape3D.new()
var smaller_collision_shape: SphereShape3D = SphereShape3D.new()

func _ready():
	collision_shape.radius = COLLISION_RADIUS
	smaller_collision_shape.radius = COLLISION_RADIUS - SKIN_DEPTH

func compute_next_physics_state(character_physics_state: CharacterPhysicsState, input_state: InputState):
	var delta = CONSTANT_DELTA
	var player_velocity = character_physics_state.velocity()
	var h_velocity = Vector3(player_velocity.x, 0, player_velocity.z)
	var facing_horizontal_direction_basis = Basis.IDENTITY.rotated(Vector3.UP, deg_to_rad(input_state.yaw()))
	var horizontal_move_direction = (facing_horizontal_direction_basis * Vector3(input_state.direction().x, 0, input_state.direction().y)).normalized()
	#if !physics_state["is_moving_along_floor"]:
		#cl_print(["NOT ALONG FLOOR"])
	var floor_check_distance = 1.0 if character_physics_state.is_grounded() else 0.01
	var floor_check = FloorCheck.new(get_world_3d().direct_space_state, COLLISION_RADIUS, player_velocity.normalized(), [self], multiplayer.is_server())
	var floor_contact = floor_check.find_floor(global_position, floor_check_distance)
	
	var is_grounded = false
	#cl_print([vtos(floor_contact.normal)])
	if is_floor(floor_contact.normal):
		var target_velocity = project_vector_onto_plane_along_direction(horizontal_move_direction * SPEED, floor_contact.normal, UP)
		player_velocity = player_velocity.lerp(target_velocity, GROUND_ACCEL * delta)
		if input_state.is_jumping():
			player_velocity.y = JUMP_FORCE
		else:
			global_position += compute_snap_motion(floor_contact.position, floor_contact.normal, global_position, player_velocity)
			is_grounded = true
	else:
		var turned_h_velocity = h_velocity
		if (horizontal_move_direction.dot(h_velocity.normalized()) > 0): # don't want to turn backwards
			var turn_direction = h_velocity.normalized().slerp(horizontal_move_direction, AIR_TURN_RATE * delta)
			turned_h_velocity = turn_direction * h_velocity.length()
		player_velocity = Vector3(turned_h_velocity.x, player_velocity.y, turned_h_velocity.z)
		if turned_h_velocity.dot(horizontal_move_direction) <= SPEED:
			player_velocity += (horizontal_move_direction * (SPEED - turned_h_velocity.dot(horizontal_move_direction))) * AIR_ACCEL * delta
		player_velocity.y -= GRAVITY * delta
	
	var velocity_after_move = move_and_slide_target_point(player_velocity, delta)
	#cl_print(["\tend position: ", global_position])
	return CharacterPhysicsState.new(global_position, velocity_after_move, is_grounded)

func compute_vertical_distance_from_floor(floor_contact: Dictionary, player_position: Vector3):
	# Skin depth just to be sure we don't apply snap gravity when super close to floor
	var implied_contact_point_on_player_collider: Vector3 = player_position - (floor_contact.normal * (COLLISION_RADIUS - SKIN_DEPTH))
	var distance_from_floor_along_normal = implied_contact_point_on_player_collider.distance_to(floor_contact.position)
	return distance_from_floor_along_normal / floor_contact.normal.dot(UP)

func compute_snap_motion(floor_point, floor_normal, player_position, current_velocity):
	var implied_position_based_on_floor_contact = (floor_point + (floor_normal * COLLISION_RADIUS))
	var implied_position_offset = implied_position_based_on_floor_contact - player_position
	if implied_position_offset.length() > 0.01 and implied_position_offset.normalized().dot(UP) < -TOLERANCE:
		var snap_magnitude = min(max(TOLERANCE, implied_position_offset.length()), 0.1)
		if enable_collision_logging_:
			cl_print(["snap motion: ", snap_magnitude * -floor_normal])
		return implied_position_offset * 0.99
	else:
		return Vector3.ZERO

func move_and_slide_target_point(vel:Vector3, delta:float) -> Vector3:
	var motion = vel * delta
	var last_normal: Vector3 = Vector3.ZERO
	var original_direction = motion.normalized() 
	var target_position = global_position + motion
	var position_before_move = global_position
	$CollisionShape3D.shape = collision_shape
	# resolve static collisions
	var resting_collision: KinematicCollision3D = move_and_collide(Vector3.ZERO, false, COLLISION_MARGIN, false, 1)
	$CollisionShape3D.shape = smaller_collision_shape
	for i in COLLIDE_AND_SLIDE_ITERATIONS:
		if motion == Vector3.ZERO:
			break
		var start_position = global_position
		var collision: KinematicCollision3D = move_and_collide(motion, false, COLLISION_MARGIN, false, 10)
		if not collision:
			break
		
		# correct for skin depth
		position += collision.get_normal() * collision.get_depth()
		# compute slide motion
		var slide_result = calculate_slide_motion(target_position, global_position, collision, last_normal)
		var slid_motion = slide_result[0]
		position += slide_result[1]
		#var remaining_travel_distance = collision.get_remainder().length()
		var direction_towards_target = (target_position - global_position).normalized()
		var next_motion_towards_target = target_position - global_position # direction_towards_target * remaining_travel_distance
		var raw_slid_motion = next_motion_towards_target.slide(collision.get_normal())
		if enable_collision_logging_:
			cl_print(["Collision: ", i,
				"\n\tstartpos: ", start_position, ", numcollisions: ", collision.get_collision_count(),
				"\n\tmotion: ", motion,
				"\n\tslid_motion: ", slid_motion,
				"\n\tnormal: ", collision.get_normal(), 
				"\n\tposition: ", collision.get_position(), 
				"\n\ttravel: ", collision.get_travel(),
				"\n\tdepth: ", collision.get_depth()])
		last_normal = collision.get_normal()
		if original_direction.dot(slid_motion.normalized()) < 0:
			#print("\t\tSTOPPING because slid motion opposite original")
			motion = Vector3.ZERO
#			motion = slid_motion - slid_motion.project(original_direction)
		elif original_direction.slide(collision.get_normal()).angle_to(slid_motion) >= (PI / 2) - 0.0001:
			#print("\t\tSTOPPING because original motion slid along last collision plane opposes the latest motion slide")
			motion = Vector3.ZERO
		else:
			motion = slid_motion
	var real_motion = global_position - position_before_move
	if enable_collision_logging_:
		cl_print(["end pos: ", global_position,
			"\n\treal motion: ", real_motion])
	return real_motion / delta

static func calculate_slide_motion(
	target_position: Vector3, 
	current_position: Vector3,
	current_collision: KinematicCollision3D, 
	last_normal: Vector3) -> Array:
	"""
	returns [slid motion, position offset to apply (ex, away from crease)]
	"""
	var next_motion_towards_target = target_position - current_position
	var direction_towards_target = next_motion_towards_target.normalized()
	var raw_slid_motion = next_motion_towards_target.slide(current_collision.get_normal())
	if last_normal == Vector3.ZERO:
		return [raw_slid_motion, NO_POSITION_OFFSET_TO_ESCAPE_CREASE]
	else:
		var is_slide_direction_against_last_normal = raw_slid_motion.normalized().dot(last_normal) < -0.0001
		var outwards_from_crease_normal: Vector3 = (last_normal + current_collision.get_normal()).normalized()
		var target_direction_slid_against_last_normal = direction_towards_target.slide(last_normal).normalized()
		var target_direction_slid_against_current_normal = direction_towards_target.slide(current_collision.get_normal()).normalized()
		var is_target_direction_towards_crease = (
			target_direction_slid_against_current_normal.dot(outwards_from_crease_normal) < 0 and
			target_direction_slid_against_last_normal.dot(outwards_from_crease_normal) < 0)
		if is_slide_direction_against_last_normal or is_target_direction_towards_crease:
			var crease_direction: Vector3 = last_normal.cross(current_collision.get_normal()).normalized()
			var position_correction_to_escape_crease = COLLISION_MARGIN * outwards_from_crease_normal
			var remaining_motion_slid_along_crease = current_collision.get_remainder().project(crease_direction)
			return [remaining_motion_slid_along_crease, position_correction_to_escape_crease]
		else:
			return [raw_slid_motion, NO_POSITION_OFFSET_TO_ESCAPE_CREASE]

func add_debug_sphere(location):
	var sphere_instance: MeshInstance3D = debug_sphere.instantiate()
	add_child(sphere_instance)
	sphere_instance.global_position = location

func cl_print(items: Array):
	var print_str = "CL:"
	for item in items:
		print_str = print_str + " " + str(item)
	if !multiplayer.is_server():
		print(print_str)

static func project_vector_onto_plane_along_direction(vector, plane_normal, direction):
	var distance_to_plane_from_vector_along_direction = -1.0 * (plane_normal.dot(vector) / plane_normal.dot(direction))
	var estimated_projected_vector = vector + direction * distance_to_plane_from_vector_along_direction
	var exact_projected_vector = Plane(plane_normal, 0).project(estimated_projected_vector)
	return exact_projected_vector

static func vtos(vector:Vector3):
	return "(%+.3f, %+.3f, %+.3f)" % [vector.x, vector.y, vector.z]

static func is_floor(normal:Vector3) -> bool:
	return (normal) and normal.angle_to(UP) <= FLOOR_ANGLE + FLOOR_CHECK_TOLERANCE

