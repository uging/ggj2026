extends Node2D
@export var is_top_down_level := false
@export var level_gravity := 1600.0

func _ready() -> void:
	# 1. Wait for Main.gd to finish moving Goma into position 
	await get_tree().process_frame 
	
	# 2. Configure environment
	if is_instance_valid(Global.player):
		Global.player.is_top_down = is_top_down_level
		Global.player.gravity = level_gravity
		
		# 3. Handle Camera
		var cam = Global.player.get_node_or_null("Camera2D")
		if cam:
			cam.make_current()
			# Left limit stays at 0 to match the left edge of the tower
			cam.limit_left = 0
			# The building is tall! Set the top limit to -2200 to reach the roof
			cam.limit_top = -2200 
			# The building is narrow. Set right limit to ~1800
			cam.limit_right = 1800 
			# IMPORTANT: Set bottom limit to 950 to keep the dirt/grass visible
			# If this is too low, Goma will fall "out" before hitting the death plane.
			cam.limit_bottom = 950

	# 4. HUD Sync & Signal Connection
	if is_instance_valid(Global.hud) and is_instance_valid(Global.player):
		# Re-connect health signal specifically for this level load
		if not Global.player.health_changed.is_connected(Global.hud._on_health_changed):
			Global.player.health_changed.connect(Global.hud._on_health_changed)
		
		if Global.hud.has_method("setup_health"):
			Global.hud.setup_health(Global.player)
