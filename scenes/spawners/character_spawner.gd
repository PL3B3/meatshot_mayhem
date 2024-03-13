extends MultiplayerSpawner

var kinematic_character_scene = preload("res://scenes/movement/character_movement_kinematic_body.tscn")
var rigid_character_scene = preload("res://scenes/movement/character_movement_rigid_body_3d.tscn")
var ThirdPersonDisplayScene = preload("res://scenes/character/third_person_display.tscn")
var CharacterScene = preload("res://scenes/character/character.tscn")

func _ready():
	spawn_function = spawn_character

func spawn_character(data: Dictionary):
	var position = data["position"]
	var id = data["id"]
	print("Spawn id: %s. Self id: %s." % [id, multiplayer.get_unique_id()])
	var character: Node
	if (multiplayer.get_unique_id() != Network.SERVER_UNIQUE_ID and multiplayer.get_unique_id() != id):
		print("Spawning puppet")
		character = ThirdPersonDisplayScene.instantiate()
		character.position = position
	else:
		character = kinematic_character_scene.instantiate()
		character.position = position
	character.name = str(id)
	return character

func filter_out_unspawned_entities_from_world_state(world_state: Dictionary):
	var filtered_world_state = {}
	for entity_id in get_entity_ids():
		if entity_id in world_state:
			filtered_world_state[entity_id] = world_state[entity_id].duplicate(true)

func get_entity_ids() -> Dictionary:
	var entity_ids = []
	for child_node in get_children():
		entity_ids.append(child_node.name)
	return entity_ids
