extends Node2D
@export var is_top_down_level := false
@export var level_gravity := 1600.0

func _ready() -> void:
	
	# Wait for the engine to settle and Main.gd to position the player
	await get_tree().process_frame 
	
	# PHYSICS & MUSIC PROGRESSION
	if is_instance_valid(Global.player):
		Global.player.is_top_down = is_top_down_level
		Global.player.gravity = level_gravity
			
	# VORTEX POP-OUT
	var portal = get_node_or_null("StartPortal") 
	if portal and is_instance_valid(Global.player):
		if Global.player.has_method("reset_visuals_after_travel"):
			# Reset visuals and force face right for the world level
			Global.player.reset_visuals_after_travel(portal.global_position, Global.last_spawn_pos, true)
			
			# Delay the landing sound to match the "pop-out" timing
			await get_tree().create_timer(0.4).timeout
			GlobalAudioManager._play_sfx(GlobalAudioManager.land_sfx, -2.0)
			
	# CAMERA CONFIGURATION
	var cam = Global.player.get_node_or_null("Camera2D")
	if cam:
		cam.make_current()
		cam.limit_left = 0
		cam.limit_top = -500
		cam.limit_bottom = 700
		cam.limit_right = 3000
