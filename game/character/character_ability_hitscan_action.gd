extends AbstractCharacterAbilityAction
class_name CharacterAbilityHitscanAction

const DEBUG_SPHERE_SCENE := preload("res://game/debug_sphere.tscn")
const DEBUG_SPHERE_SCALE := Vector3(0.5, 0.5, 0.5)
const DEBUG_SPHERE_LIFETIME := 5

func perform_ability(
		camera_transform: Transform3D,
		remote_character_positions: Array[Vector3]) -> void:
	var ray_origin := camera_transform.origin
	var ray_direction := (camera_transform.basis * Vector3.FORWARD).normalized()
	var closest_ray_hit := RaycastUtils.compute_nearest_raycast_intersect(
		ray_origin, ray_direction, remote_character_positions, get_world_3d().direct_space_state)
	__draw_temporary_debug_sphere(closest_ray_hit)

func __draw_temporary_debug_sphere(sphere_origin: Vector3) -> void:
	var debug_sphere: MeshInstance3D = DEBUG_SPHERE_SCENE.instantiate()
	debug_sphere.position = sphere_origin
	debug_sphere.scale = DEBUG_SPHERE_SCALE
	add_child(debug_sphere)
	get_tree().create_timer(DEBUG_SPHERE_LIFETIME).timeout.connect(
		func() -> void: debug_sphere.queue_free())
