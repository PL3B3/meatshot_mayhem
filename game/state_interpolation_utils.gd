class_name StateInterpolationUtils extends Object

static func interpolate_remote_state_snapshots(
	source_remote_state_snapshot: Dictionary, 
	target_remote_state_snapshot: Dictionary, 
	interp_fraction: float
) -> Dictionary:
	var interpolated_states := {}
	for remote_character_entity_id: int in target_remote_state_snapshot:
		var target_remote_character_state: CharacterTransformState = (
            target_remote_state_snapshot[remote_character_entity_id])
		if remote_character_entity_id in source_remote_state_snapshot:
			var source_remote_character_state: CharacterTransformState = (
                source_remote_state_snapshot[remote_character_entity_id])
			interpolated_states[remote_character_entity_id] = (
                StateInterpolationUtils.interpolate_character_transform_states(
                    source_remote_character_state,target_remote_character_state, interp_fraction))
		else:
			interpolated_states[remote_character_entity_id] = target_remote_character_state
	return interpolated_states

static func interpolate_character_transform_states(
    source_transform_state: CharacterTransformState,
    target_transform_state: CharacterTransformState, 
    interp_fraction: float
) -> CharacterTransformState:
	var source_view_rotation_in_euler_angles := Vector3(
        deg_to_rad(source_transform_state.pitch()), deg_to_rad(source_transform_state.yaw()), 0)
	var source_view_rotation_quaternion := Quaternion.from_euler(source_view_rotation_in_euler_angles)

	var target_view_rotation_in_euler_angles := Vector3(
		deg_to_rad(target_transform_state.pitch()), deg_to_rad(target_transform_state.yaw()), 0)
	var target_view_rotation_quaternion := Quaternion.from_euler(target_view_rotation_in_euler_angles)

	var interpolated_view_rotation := source_view_rotation_quaternion.slerp(
		target_view_rotation_quaternion, interp_fraction)
	return CharacterTransformState.new(
		source_transform_state.position().lerp(target_transform_state.position(), interp_fraction), 
		rad_to_deg(interpolated_view_rotation.get_euler().x),
		rad_to_deg(interpolated_view_rotation.get_euler().y))
