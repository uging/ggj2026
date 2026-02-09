extends Node2D
@export var is_top_down_level := false
@export var level_gravity := 1600.0

func _ready() -> void:	
	await get_tree().process_frame
	
	# Physics & Music Progression
	if is_instance_valid(Global.player):
		Global.player.is_top_down = is_top_down_level
		Global.player.gravity = level_gravity
		
	# Vortex Pop-out
	var portal = get_node_or_null("StartPortal")
	if portal and is_instance_valid(Global.player):
		Global.player.reset_visuals_after_travel(portal.global_position, Global.last_spawn_pos, true)
		await get_tree().create_timer(0.4).timeout
		GlobalAudioManager._play_sfx(GlobalAudioManager.land_sfx, -2.0)
	
	# Camera
	if is_instance_valid(Global.player):
		var cam = Global.player.get_node_or_null("Camera2D")
		if cam:
			cam.make_current()
			cam.limit_left = -200
			cam.limit_right = 3200 
			cam.limit_top = -1500 
			cam.limit_bottom = 800 
