extends Node2D
@export var is_top_down_level := false
@export var level_gravity := 1600.0

func _ready() -> void:
	# 1. Start Music Silent
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), -80.0)
	
	await get_tree().process_frame
	
	# 2. Physics & Music Progression
	if is_instance_valid(Global.player):
		Global.player.is_top_down = is_top_down_level
		Global.player.gravity = level_gravity
	
	GlobalAudioManager.fade_music(0.0, 1.5)
	
	# 3. Vortex Pop-out
	var portal = get_node_or_null("StartPortal")
	if portal and is_instance_valid(Global.player):
		Global.player.reset_visuals_after_travel(portal.global_position, Global.last_spawn_pos, true)
		await get_tree().create_timer(0.4).timeout
		GlobalAudioManager._play_sfx(GlobalAudioManager.land_sfx, -2.0)
	
	# 4. Camera & HUD Setup
	if is_instance_valid(Global.player):
		var cam = Global.player.get_node_or_null("Camera2D")
		if cam:
			cam.make_current()
			cam.limit_left = -200
			cam.limit_right = 3200 
			cam.limit_top = -1500 
			cam.limit_bottom = 800 

	if is_instance_valid(Global.hud) and is_instance_valid(Global.player):
		if not Global.player.health_changed.is_connected(Global.hud._on_health_changed):
			Global.player.health_changed.connect(Global.hud._on_health_changed)
		if Global.hud.has_method("setup_health"):
			Global.hud.setup_health(Global.player)
