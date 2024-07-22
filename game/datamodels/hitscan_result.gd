extends RefCounted
class_name HitscanResult

var origin: Vector3
var hit_point: Vector3
var hit_entity_id: int
var damage: int

func _init(origin: Vector3, hit_point: Vector3, hit_entity_id: int, damage: int) -> void:
	self.origin = origin
	self.hit_point = hit_point
	self.hit_entity_id = hit_entity_id
	self.damage = damage

func with_origin(new_origin: Vector3) -> HitscanResult:
	return HitscanResult.new(new_origin, hit_point, hit_entity_id, damage)

func _to_string():
	return "Hit<orig:%s, pt:%s, ent: %d>" % [origin, hit_point, hit_entity_id]
