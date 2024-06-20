class_name DebugSphereDisplayer extends Node

const DEBUG_SPHERE_SCENE := preload("res://game/debug_sphere.tscn")
const DEBUG_SPHERE_SCALE := Vector3(0.5, 0.5, 0.5)
const DEBUG_SPHERE_LIFETIME := 5

func draw_debug_sphere(sphere_origin: Vector3) -> void:
	var debug_sphere: MeshInstance3D = DEBUG_SPHERE_SCENE.instantiate()
	debug_sphere.position = sphere_origin
	debug_sphere.scale = DEBUG_SPHERE_SCALE
	add_child(debug_sphere)
	get_tree().create_timer(DEBUG_SPHERE_LIFETIME).timeout.connect(
		func() -> void: debug_sphere.queue_free())
