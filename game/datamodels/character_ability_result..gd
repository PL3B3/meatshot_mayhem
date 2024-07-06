extends RefCounted
class_name CharacterAbilityResult

static var EMPTY_RESULT := CharacterAbilityResult.new([])

var hitscan_results: Array[HitscanResult]

func _init(hitscan_results: Array[HitscanResult]) -> void:
	self.hitscan_results = hitscan_results
