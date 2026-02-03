extends Node

const SAVE_PATH = "user://savegame.save"

# Local variables to help the Main script transition scenes after loading
var current_health = 3
var current_world = "res://scenes/worlds/world_1.tscn"
var unlocked_masks = {}

func save_game():
	# 1. GATHER DATA ONLY FROM GLOBAL
	# We no longer check Global.player; we trust Global.current_health is up to date
	var data = {
		"health": Global.current_health,
		"world": get_tree().current_scene.scene_file_path,
		"unlocked_masks": Global.unlocked_masks,
		"destroyed_enemies": Global.destroyed_enemies,
		"equipped_set": Global.current_equipped_set
	}
	
	# 2. WRITE TO DISK
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(data)
		file.store_line(json_string)
		print("Data saved successfully to Disk!")

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_line()
	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result == OK:
		var data = json.get_data()

		# 1. Update Global source of truth
		# Using .get() ensures the game doesn't crash if a save file is missing a key
		Global.unlocked_masks = data.get("unlocked_masks", Global.unlocked_masks)
		Global.current_health = data.get("health", 3)
		Global.current_equipped_set = data.get("equipped_set", 1)

		# 2. Update local SaveManager vars for scene transitions
		current_health = Global.current_health
		current_world = data.get("world", "res://scenes/worlds/world_1.tscn")

		print("Data loaded: Health ", current_health, " | Mask ID: ", Global.current_equipped_set)
