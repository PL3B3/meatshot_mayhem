extends AbstractCharacterAbilityAction
class_name CharacterAbilityHitscanAction

const TRACER_DOWNWARD_OFFSET := 0.5
const HIT_DAMAGE := 100

func perform_ability(
		camera_transform: Transform3D,
		remote_character_position_by_entity_id: Dictionary) -> CharacterAbilityResult:
	var ray_origin := camera_transform.origin
	var ray_direction := (camera_transform.basis * Vector3.FORWARD).normalized()
	var closest_ray_hit := RaycastUtils.compute_nearest_raycast_intersect(
		ray_origin, ray_direction, remote_character_position_by_entity_id, get_world_3d().direct_space_state)
	var tracer_origin := __compute_ray_tracer_origin(ray_origin, camera_transform.basis)
	var hitscan_result := HitscanResult.new(
		tracer_origin, closest_ray_hit.hit_point, closest_ray_hit.hit_entity_id, HIT_DAMAGE)
	return CharacterAbilityResult.new([hitscan_result])

static func __compute_ray_tracer_origin(ray_origin: Vector3, camera_basis: Basis) -> Vector3:
	var camera_down_direction := (camera_basis * Vector3.DOWN).normalized()
	var tracer_origin := ray_origin + camera_down_direction * TRACER_DOWNWARD_OFFSET
	return tracer_origin
