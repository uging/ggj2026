extends Node

const SAVE_PATH = "user://savegame.save"

# These will be overwritten by the Save/Load functions
var current_health = 3
var current_world = "res://scenes/worlds/world_1.tscn"
var unlocked_masks = {}

func save_game():
	# 1. GATHER DATA
	# Pull mask data from Global
	unlocked_masks = Global.unlocked_masks
	
	# Pull health from the player if they exist, otherwise use Global/Last known
	if Global.player:
		current_health = Global.player.current_health
	
	# 2. PREPARE DICTIONARY
	var data = {
		"health": current_health,
		"world": get_tree().current_scene.scene_file_path,
		"unlocked_masks": unlocked_masks
	}
	
	# 3. WRITE TO DISK
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	var json_string = JSON.stringify(data)
	file.store_line(json_string)
	print("Data saved successfully!")

func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		return
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_line()
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result == OK:
		var data = json.get_data()
		# Update Global variables so the game reflects the save
		Global.unlocked_masks = data["unlocked_masks"]
		current_health = data["health"]
		current_world = data["world"]
		
		# Change scene to the saved world
		get_tree().change_scene_to_file(current_world)
