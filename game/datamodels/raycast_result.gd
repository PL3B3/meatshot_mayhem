extends RefCounted
class_name RaycastResult

var hit_point: Vector3
var hit_entity_id: int

func _init( hit_point: Vector3, hit_entity_id: int) -> void:
	self.hit_point = hit_point
	self.hit_entity_id = hit_entity_id

func _to_string() -> String:
	return "RaycastResult{entity=%d, point=%s}" % [hit_entity_id, hit_point]
