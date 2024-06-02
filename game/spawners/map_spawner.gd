extends MultiplayerSpawner


func _ready():
	spawn_function = func(_data): return load("res://game/large_test_map.tscn").instantiate()
