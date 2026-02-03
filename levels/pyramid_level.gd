extends Node2D

func _ready() -> void:
	# 1. Check if Goma is missing (happens after death reload)
	if Global.player == null:
		spawn_player_manually()
	
	# 2. Wait for them to be ready
	while Global.player == null or Global.hud == null:
		await get_tree().process_frame
	
	var player = Global.player
	var hud = Global.hud

	# 3. Parent them to THIS level
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	add_child(player)
	
	if hud.get_parent() != null:
		hud.get_parent().remove_child(hud)
	add_child(hud)
	hud.show()

	# 4. Positioning & Camera
	player.is_top_down = false
	player.gravity = 1600
	
	# SAFETY: Check if SpawnPoint exists before using it
	if has_node("SpawnPoint"):
		player.global_position = $SpawnPoint.global_position
	else:
		print("Warning: SpawnPoint node missing in this level!")
		player.global_position = Vector2(100, 100) # Backup position
	
	if hud.has_method("setup_health"):
		hud.setup_health(player)

	_reset_camera(player)

# ADD THIS FUNCTION to pyramid_level.gd
func spawn_player_manually():
	# Update these paths to match your actual file locations!
	var p_scene = load("res://entities/player/player.tscn") 
	var h_scene = load("res://ui/hud.tscn")
	
	Global.player = p_scene.instantiate()
	Global.hud = h_scene.instantiate()

func _reset_camera(target):
	# 1. Find the camera
	var camera = target.get_node_or_null("Camera2D")

	if camera:
		# 2. Make it the boss of the screen immediately
		camera.make_current()

		# 3. CRITICAL: Force the camera's position to match Goma exactly
		# This prevents it from staying at (0,0)
		camera.global_position = target.global_position

		# 4. If you have 'Position Smoothing' on, reset it so it doesn't 
		# take 2 seconds to slide from the center of the screen to Goma
		if camera.has_method("reset_smoothing"):
			camera.reset_smoothing()

			print("Camera successfully snapped to Goma at: ", target.global_position)
