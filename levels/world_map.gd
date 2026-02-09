extends Node2D

# --- References ---
@onready var help_label = $KeyLabel

func _ready() -> void:	
	if help_label:
		help_label.show()
	
	# Ensure physics is running
	get_tree().paused = false
	
	# Portal Exit Logic ---
	# Wait for Main.gd to finish moving Goma to the last_spawn_pos
	await get_tree().process_frame
	
	_handle_portal_arrival_animation()

func _handle_portal_arrival_animation() -> void:
	if not is_instance_valid(Global.player): return
	
	if not Global.isTitleShown:
		GlobalAudioManager._play_sfx(GlobalAudioManager.land_sfx, -2.0)
	# Find the specific AREA node Goma just exited from
	var source_node: Node2D = null
	
	# Match the path to the actual node names in your World Map tree
	# Check the ORIGIN level to find the correct exit point
	if Global.origin_level_path.contains("basic_level"):
		source_node = get_node_or_null("BasicLevel/BasicLevelArea")
	elif Global.origin_level_path.contains("pyramid"):
		source_node = get_node_or_null("PyramidLevel/PyramidArea")
	elif Global.origin_level_path.contains("tower"):
		source_node = get_node_or_null("TowerLevel/TowerArea")
	elif Global.origin_level_path.contains("castle"):
		source_node = get_node_or_null("CastleLevel/CastleArea")
		
	GlobalAudioManager._play_sfx(GlobalAudioManager.land_sfx, -2.0)
	
	if source_node and Global.player.has_method("reset_visuals_after_travel"):
		# Calculate arrival exactly 50 pixels below the chosen portal
		var arrival_point = source_node.global_position + Vector2(0, 50)
		Global.player.reset_visuals_after_travel(source_node.global_position, arrival_point, false)
	else:
		# Fallback for first-time login/title screen
		Global.player.reset_visuals_after_travel(Vector2.ZERO, Global.last_spawn_pos)

# --- Level Entry Bridge ---
func enter_level(level_path: String, spawn_point: Vector2):
	# REMOVED: reset_visuals_after_travel call here
	# (Because basic_level_area.gd handles the "suck-in" tween now)

	var main_node = get_tree().root.get_node_or_null("Main")
	
	if main_node and main_node.has_method("load_level"):
		main_node.load_level(level_path, spawn_point)
	else:
		push_warning("Main manager not found. Executing direct scene change.")
		get_tree().change_scene_to_file(level_path)

func _on_map_entered():
	if has_node("/root/SaveManager"):
		get_node("/root/SaveManager").save_game()
