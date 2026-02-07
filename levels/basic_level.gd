extends Node2D
@export var is_top_down_level := false
@export var level_gravity := 1600.0

func _ready() -> void:
	# 1. Wait for Main.gd to finish moving Goma into position 
	await get_tree().process_frame 
	
	# 2. Configure environment-specific physics
	# --- Portal Exit Animation ---
	# Look for a portal in this level to "spit" Goma out of
	var portal = get_node_or_null("StartPortal") 
	if portal and is_instance_valid(Global.player):
		if Global.player.has_method("reset_visuals_after_travel"):
			# Start at portal, end at the spawn position set in Main
			Global.player.reset_visuals_after_travel(portal.global_position, Global.last_spawn_pos)
			await get_tree().create_timer(0.4).timeout
			GlobalAudioManager._play_sfx(GlobalAudioManager.land_sfx, -2.0)
	
	# 2. Configure environment-specific physics
	if is_instance_valid(Global.player):
		Global.player.is_top_down = is_top_down_level
		Global.player.gravity = level_gravity
		
		# 3. Handle Goma's internal camera safely [cite: 14]
	var cam = Global.player.get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
		# --- ADD CAMERA LIMITS HERE ---
		# 0 is the far left of your level. 
		# 2750 (example) is the far right near your ExitNode.
		cam.limit_left = 0
		cam.limit_top = -500 # Adjust based on your sky height
		cam.limit_bottom = 700 # Adjust based on your pits
		cam.limit_right = 3000

	# 4. Final HUD Sync (Main.gd already called .show(), we just sync data) 
	if is_instance_valid(Global.hud) and is_instance_valid(Global.player):
		# Re-connect the health signal to the HUD's specific handler
		if not Global.player.health_changed.is_connected(Global.hud._on_health_changed):
			Global.player.health_changed.connect(Global.hud._on_health_changed)

		if Global.hud.has_method("setup_health"):
			Global.hud.setup_health(Global.player)
