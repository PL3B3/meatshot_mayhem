extends Object
class_name HitscanResult

var origin: Vector3
var hit_point: Vector3

func _init(origin: Vector3, hit_point: Vector3) -> void:
    self.origin = origin
    self.hit_point = hit_point