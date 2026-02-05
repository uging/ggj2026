extends Node2D
@export var is_top_down_level := false
@export var level_gravity := 1600.0

func _ready() -> void:
	await get_tree().process_frame 
	
	if is_instance_valid(Global.player):
		Global.player.is_top_down = false
		
		var cam = Global.player.get_node_or_null("Camera2D")
		if cam:
			cam.make_current()
			# Allow the camera to pan left/right across the wide ground
			cam.limit_left = -200
			cam.limit_right = 3200 
			
			# IMPORTANT: The top limit must be negative to see the top of the pyramid
			cam.limit_top = -1500 
			
			# Keeps the grass/ground floor at the bottom of the screen
			cam.limit_bottom = 800 

	# HUD Sync & Signal Connection
	if is_instance_valid(Global.hud) and is_instance_valid(Global.player):
		if not Global.player.health_changed.is_connected(Global.hud._on_health_changed):
			Global.player.health_changed.connect(Global.hud._on_health_changed)
		
		if Global.hud.has_method("setup_health"):
			Global.hud.setup_health(Global.player)
