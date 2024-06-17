extends Object
class_name RaycastUtils

const NO_ENTITY_HIT := -1
const ONLY_MAP_LAYER_COLLISION_MASK = 0xFFFFFFF1
const MAX_RAYCAST_DISTANCE: float = 1000
static var NO_INTERSECT_POINTS: Array[Vector3] = []

# static func compute_nearest_raycast_intersect(
# 		ray_origin: Vector3,
# 		normalized_ray_direction: Vector3,
# 		remote_character_positions: Array,
# 		direct_space_state: PhysicsDirectSpaceState3D) -> Vector3:
# 	var nearest_ray_intersect: Vector3 = __compute_point_where_ray_hits_map(
# 		ray_origin, normalized_ray_direction, direct_space_state)
# 	var nearest_intersect_distance: float = max(0, (nearest_ray_intersect - ray_origin).length())
# 	for remote_character_position: Vector3 in remote_character_positions:
# 		var ray_intersect_points_with_remote_character: Array[Vector3] = __compute_ray_sphere_intersect_points(
# 			ray_origin,
# 			normalized_ray_direction,
# 			remote_character_position,
# 			2.5)
# 		for intersect_point: Vector3 in ray_intersect_points_with_remote_character:
# 			var intersect_point_distance_from_ray_origin: float = (intersect_point - ray_origin).length()
# 			if intersect_point_distance_from_ray_origin < nearest_intersect_distance:
# 				nearest_intersect_distance = intersect_point_distance_from_ray_origin
# 				nearest_ray_intersect = intersect_point
# 	return nearest_ray_intersect

static func compute_nearest_raycast_intersect(
		ray_origin: Vector3,
		normalized_ray_direction: Vector3,
		remote_character_position_by_entity_id: Dictionary,
		direct_space_state: PhysicsDirectSpaceState3D) -> RaycastResult:
	var nearest_ray_intersect: Vector3 = __compute_point_where_ray_hits_map(
		ray_origin, normalized_ray_direction, direct_space_state)
	var nearest_intersect_distance: float = max(0, (nearest_ray_intersect - ray_origin).length())
	var nearest_intersect_entity_id := NO_ENTITY_HIT
	for remote_character_entity_id: int in remote_character_position_by_entity_id:
		var remote_character_position: Vector3 = remote_character_position_by_entity_id[remote_character_entity_id]
		var ray_intersect_points_with_remote_character: Array[Vector3] = __compute_ray_sphere_intersect_points(
			ray_origin,
			normalized_ray_direction,
			remote_character_position,
			2.5)
		for intersect_point: Vector3 in ray_intersect_points_with_remote_character:
			var intersect_point_distance_from_ray_origin: float = (intersect_point - ray_origin).length()
			if intersect_point_distance_from_ray_origin < nearest_intersect_distance:
				nearest_intersect_distance = intersect_point_distance_from_ray_origin
				nearest_ray_intersect = intersect_point
				nearest_intersect_entity_id = remote_character_entity_id
	return RaycastResult.new(nearest_ray_intersect, nearest_intersect_entity_id)

static func __compute_point_where_ray_hits_map(
		ray_origin: Vector3, 
		ray_direction: Vector3, 
		direct_space_state: PhysicsDirectSpaceState3D) -> Vector3:
	var ray_end: Vector3 = ray_origin + MAX_RAYCAST_DISTANCE * ray_direction
	var ray_query_params := PhysicsRayQueryParameters3D.create(ray_origin, ray_end, ONLY_MAP_LAYER_COLLISION_MASK)
	var ray_against_map_hit_result: Dictionary = direct_space_state.intersect_ray(ray_query_params)
	if ray_against_map_hit_result.is_empty():
		return ray_end
	else:
		return ray_against_map_hit_result.position

static func __compute_ray_sphere_intersect_points(
		ray_origin: Vector3, 
		ray_direction: Vector3, 
		sphere_origin: Vector3, 
		sphere_radius: float) -> Array[Vector3]:
	var normalized_direction := ray_direction.normalized()
	var vector_from_ray_origin_to_sphere_origin: Vector3 = sphere_origin - ray_origin
	var sphere_origin_projected_onto_ray_point: Vector3 = (
		ray_origin + ray_direction * ray_direction.dot(vector_from_ray_origin_to_sphere_origin))
	var sphere_to_ray_nearest_perpendicular_distance: float = (
		sphere_origin_projected_onto_ray_point - sphere_origin).length()
	if (sphere_to_ray_nearest_perpendicular_distance <= sphere_radius):
		var half_secant_distance: float = sqrt(
			pow(sphere_radius, 2) - pow(sphere_to_ray_nearest_perpendicular_distance, 2))
		var unfiltered_intersect_points: Array[Vector3] = [
			sphere_origin_projected_onto_ray_point + normalized_direction * half_secant_distance, 
			sphere_origin_projected_onto_ray_point - normalized_direction * half_secant_distance]
		return __filter_out_intersect_points_behind_ray(ray_origin, normalized_direction, unfiltered_intersect_points)
	else:
		return NO_INTERSECT_POINTS

static func __filter_out_intersect_points_behind_ray(
		ray_origin: Vector3, 
		ray_direction: Vector3, 
		intersect_points: Array[Vector3]) -> Array[Vector3]:
	var intersect_points_in_ray_direction: Array[Vector3] = []
	for intersect_point: Vector3 in intersect_points:
		if (intersect_point - ray_origin).dot(ray_direction) > 0:
			intersect_points_in_ray_direction.push_back(intersect_point)
	return intersect_points_in_ray_direction
