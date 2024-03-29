extends Node3D

class_name FirstPersonDisplay

@onready var camera_ = $Camera3D

func display(states, latest_input):
	var last_position = states[-2].position
	var current_position = states[-1].position
	var frame_lerped_position = last_position.lerp(current_position, Engine.get_physics_interpolation_fraction())
	camera_.global_position = frame_lerped_position + Vector3(0, 0.75, 0)
	var rotation_in_euler_angles = Vector3(deg_to_rad(latest_input.pitch), deg_to_rad(latest_input.yaw), 0)
	var current_rotation_basis = Quaternion.from_euler(rotation_in_euler_angles)
	camera_.basis = Basis(Quaternion(camera_.basis).slerp(current_rotation_basis, 0.5))
