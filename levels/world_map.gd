extends Node2D

# --- References ---
@onready var bg_music = $AudioStreamPlayer
@onready var help_label = $KeyLabel

func _ready() -> void:
	# 1. Initialize world map state
	if bg_music:
		bg_music.play()
	
	if help_label:
		help_label.show()
	
	# 2. Ensure physics is running if we arrived here from a paused state
	get_tree().paused = false
	print("World Map: Hub initialized and ready.")

# --- Level Entry Bridge ---
# This is called by your TowerArea, BasicLevelArea, and PyramidArea scripts.
func enter_level(level_path: String, spawn_point: Vector2):
	# Locate the permanent Main manager in the tree
	var main_node = get_tree().root.get_node_or_null("Main")
	
	if main_node and main_node.has_method("load_level"):
		# Hand off the transition to the Manager
		main_node.load_level(level_path, spawn_point)
	else:
		# Fallback: This allows you to run the world_map.tscn 
		# directly (F6) for testing without errors.
		push_warning("Main manager not found. Executing direct scene change.")
		get_tree().change_scene_to_file(level_path)

# --- Save/Load Bridge (Optional) ---
# If you want to save the game every time the player returns to the map
func _on_map_entered():
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").save_game()
