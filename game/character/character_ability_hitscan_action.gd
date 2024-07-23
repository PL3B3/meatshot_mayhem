extends AbstractCharacterAbilityAction
class_name CharacterAbilityHitscanAction

const TRACER_DOWNWARD_OFFSET := 0.5
const DAMAGE_FALLOFF_BEGIN_DISTANCE: float = 10
const DAMAGE_FALLOFF_MAX_DISTANCE: float = 50
const DAMAGE_AT_MAX_DISTANCE: int = 2
const DAMAGE_AT_MIN_DISTANCE: int = 10
const BULLET_SPREAD_ANGLE: float = 2.5
const FIRING_PATTERN_ANGLE_OFFSETS_DEG: Array[Vector2] = [
	Vector2(0,0), 
	Vector2(-BULLET_SPREAD_ANGLE,0), 
	Vector2(BULLET_SPREAD_ANGLE,0), 
	Vector2(0,BULLET_SPREAD_ANGLE), 
	Vector2(0,-BULLET_SPREAD_ANGLE)
]

func perform_ability(
		camera_transform: Transform3D,
		remote_character_position_by_entity_id: Dictionary) -> CharacterAbilityResult:
	var ray_origin := camera_transform.origin
	var hitscan_results: Array[HitscanResult] = []
	for angle_offsets: Vector2 in FIRING_PATTERN_ANGLE_OFFSETS_DEG:
		var ray_direction := __compute_ray_direction_from_angle_offsets(camera_transform, angle_offsets)
		var closest_ray_hit := RaycastUtils.compute_nearest_raycast_intersect(
			ray_origin, ray_direction, remote_character_position_by_entity_id, get_world_3d().direct_space_state)
		var tracer_origin := __compute_ray_tracer_origin(ray_origin, camera_transform.basis)
		var hit_distance_from_origin: float = (closest_ray_hit.hit_point - ray_origin).length()
		var hit_damage := __compute_bullet_damage(hit_distance_from_origin)
		hitscan_results.append(HitscanResult.new(
			tracer_origin, closest_ray_hit.hit_point, closest_ray_hit.hit_entity_id, hit_damage))
	return CharacterAbilityResult.new(hitscan_results)

static func __compute_bullet_damage(hit_distance: float) -> int:
	if hit_distance > DAMAGE_FALLOFF_MAX_DISTANCE:
		return DAMAGE_AT_MAX_DISTANCE
	elif hit_distance > DAMAGE_FALLOFF_BEGIN_DISTANCE:
		var distance_falloff_ratio: float = (
			(hit_distance - DAMAGE_FALLOFF_BEGIN_DISTANCE) / 
			(DAMAGE_FALLOFF_MAX_DISTANCE - DAMAGE_FALLOFF_BEGIN_DISTANCE))
		return floor(lerp(DAMAGE_AT_MIN_DISTANCE, DAMAGE_AT_MAX_DISTANCE, distance_falloff_ratio))
	else:
		return DAMAGE_AT_MIN_DISTANCE

static func __compute_ray_tracer_origin(ray_origin: Vector3, camera_basis: Basis) -> Vector3:
	var camera_down_direction := (camera_basis * Vector3.DOWN).normalized()
	var tracer_origin := ray_origin + camera_down_direction * TRACER_DOWNWARD_OFFSET
	return tracer_origin

static func __compute_ray_direction_from_angle_offsets(
	camera_transform: Transform3D, 
	angle_offsets_deg: Vector2
) -> Vector3:
	var camera_forward_direction := (camera_transform.basis * Vector3.FORWARD).normalized()
	var camera_right_direction := (camera_transform.basis * Vector3.RIGHT).normalized()
	var camera_up_direction := (camera_transform.basis * Vector3.UP).normalized()
	return camera_forward_direction.rotated(
		camera_up_direction, deg_to_rad(angle_offsets_deg.x)).rotated(
			camera_right_direction, deg_to_rad(angle_offsets_deg.y))
