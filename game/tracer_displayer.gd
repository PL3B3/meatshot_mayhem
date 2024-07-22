extends MeshInstance3D
class_name TracerDisplayer

const TRACER_ORIGIN_POINT_THICKNESS: float = 0.15
const TRACER_HIT_POINT_THICKNESS: float = 1.5

var immediate_mesh_: ImmediateMesh = ImmediateMesh.new()
var active_tracers_: Array[Tracer] = []

func _ready() -> void:
	mesh = immediate_mesh_

func add_tracer(ray_origin_point: Vector3, ray_hit_point: Vector3) -> void:
	active_tracers_.push_back(Tracer.create_with_random_start_and_speed(ray_origin_point, ray_hit_point))

func display_and_update_tracers() -> void:
	__display_active_tracers_()
	__update_active_tracers_()

func __display_active_tracers_() -> void:
	immediate_mesh_.clear_surfaces()
	for tracer: Tracer in active_tracers_:
		__display_tracer(tracer.compute_current_start_point(), tracer.hit_point)

func __update_active_tracers_() -> void:
	var updated_tracers: Array[Tracer] = []
	for tracer: Tracer in active_tracers_:
		var updated_tracer: Tracer = tracer.with_additional_tick_of_travel()
		if updated_tracer.is_active():
			updated_tracers.push_back(updated_tracer)
	active_tracers_ = updated_tracers

func __display_tracer(origin_point: Vector3, hit_point: Vector3) -> void:
	__draw_horizontal_tracer(origin_point, hit_point)
	__draw_vertical_tracer(origin_point, hit_point)

func __draw_horizontal_tracer(origin_point: Vector3, hit_point: Vector3) -> void:
	var origin_to_hit_vector: Vector3 = hit_point - origin_point
	var horizontal_direction: Vector3 = Vector3.UP.cross(origin_to_hit_vector).normalized()
	immediate_mesh_.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	immediate_mesh_.surface_add_vertex(origin_point - horizontal_direction * TRACER_ORIGIN_POINT_THICKNESS / 2)
	immediate_mesh_.surface_add_vertex(origin_point + horizontal_direction * TRACER_ORIGIN_POINT_THICKNESS / 2)
	immediate_mesh_.surface_add_vertex(hit_point - horizontal_direction * TRACER_HIT_POINT_THICKNESS / 2)
	immediate_mesh_.surface_add_vertex(hit_point + horizontal_direction * TRACER_HIT_POINT_THICKNESS / 2)
	immediate_mesh_.surface_end()

func __draw_vertical_tracer(origin_point: Vector3, hit_point: Vector3) -> void:
	immediate_mesh_.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	immediate_mesh_.surface_add_vertex(origin_point - Vector3.UP * TRACER_ORIGIN_POINT_THICKNESS / 2)
	immediate_mesh_.surface_add_vertex(origin_point + Vector3.UP * TRACER_ORIGIN_POINT_THICKNESS / 2)
	immediate_mesh_.surface_add_vertex(hit_point - Vector3.UP * TRACER_HIT_POINT_THICKNESS / 2)
	immediate_mesh_.surface_add_vertex(hit_point + Vector3.UP * TRACER_HIT_POINT_THICKNESS / 2)
	immediate_mesh_.surface_end()

class Tracer:
	const START_AT_RAY_ORIGIN: float = 0.0
	const TRACER_SPEED_UNITS_PER_SECOND: float = 600
	const MAX_INITIAL_FRACTION_OF_TRAVEL_DISTANCE: float = 0.2
	const CHANCE_BULLET_STARTS_WITH_RANDOM_TRAVEL_DISTANCE: float = 0.4
	static var rng_ := RandomNumberGenerator.new()

	var origin_point: Vector3
	var hit_point: Vector3
	var travelled_distance: float
	var max_travel_distance: float
	var speed_per_tick: float

	func _init(
		origin_point: Vector3, 
		hit_point: Vector3, 
		travelled_distance: float, 
		speed_per_tick: float
	) -> void:
		self.origin_point = origin_point
		self.hit_point = hit_point
		self.travelled_distance = travelled_distance
		self.speed_per_tick = speed_per_tick
		max_travel_distance = (hit_point - origin_point).length()
	
	static func create_with_random_start_and_speed(origin_point: Vector3, hit_point: Vector3) -> Tracer:
		var total_ray_distance: float = (hit_point - origin_point).length()
		if rng_.randf() < CHANCE_BULLET_STARTS_WITH_RANDOM_TRAVEL_DISTANCE:
			var random_travel_fraction: float = rng_.randf_range(
				0, total_ray_distance * MAX_INITIAL_FRACTION_OF_TRAVEL_DISTANCE)
			var random_speed: float = (TRACER_SPEED_UNITS_PER_SECOND / 60) * rng_.randf_range(0.25, 1)
			return Tracer.new(origin_point, hit_point, random_travel_fraction, random_speed)
		else:
			return Tracer.new(origin_point, hit_point, START_AT_RAY_ORIGIN, TRACER_SPEED_UNITS_PER_SECOND)	
	
	func is_active() -> bool:
		return travelled_distance < max_travel_distance
	
	func with_additional_tick_of_travel() -> Tracer:
		return Tracer.new(origin_point, hit_point, travelled_distance + speed_per_tick, speed_per_tick)
	
	func compute_current_start_point() -> Vector3:
		return origin_point.move_toward(hit_point, travelled_distance)
