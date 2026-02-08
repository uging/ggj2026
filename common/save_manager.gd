extends Node

const SAVE_PATH = "user://savegame.save"

# Local variables to help the Main script transition scenes after loading
var current_health = 3
var current_world = "res://scenes/worlds/world_1.tscn"
var unlocked_masks = {}

func save_game():
	# 1. GATHER DATA ONLY FROM GLOBAL
	var data = {
		"health": Global.current_health,
		"world": Global.current_level_path,
		"position_x": Global.player.global_position.x,
		"position_y": Global.player.global_position.y,
		"unlocked_masks": Global.unlocked_masks,
		"destroyed_enemies": Global.destroyed_enemies,
		"equipped_set": Global.current_equipped_set
	}
	
	# 2. WRITE TO DISK
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(data)
		file.store_line(json_string)

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_line()
	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result == OK:
		var data = json.get_data()
		Global.unlocked_masks = data.get("unlocked_masks", Global.unlocked_masks)
		Global.current_health = data.get("health", 3)
		
		# 1. Get the saved world path
		var saved_level = data.get("world", "res://levels/world_map.tscn")
		
		Global.current_equipped_set = data.get("equipped_set", 1)
		
		# 2. UPDATE: Use the saved coordinates instead of hardcoded values
		# We default to the World Map spawn (656, 318) if no position is found in the save
		var spawn_pos = Vector2(
			data.get("position_x", 656), 
			data.get("position_y", 318)
		)
		
		# 3. FIND MAIN and load
		var main = get_tree().root.get_node_or_null("Main")
		if main and main.has_method("load_level"):
			# Load the specific level at the specific saved position
			main.load_level(saved_level, spawn_pos)
