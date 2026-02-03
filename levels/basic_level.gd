extends Node2D

func _ready() -> void:
	print("The Forest!")
	
	# 1. Check if we need to create the player
	if Global.player == null:
		spawn_player_manually()
	
	# 2. WAIT: Give the engine a frame to finish setup
	while Global.player == null or Global.hud == null:
		await get_tree().process_frame
	
	var player = Global.player
	var hud = Global.hud

	# 3. RE-PARENT: Move Player and HUD into this level
	# We use call_deferred for adding children to prevent "Busy" errors
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	add_child(player)
	
	if hud.get_parent() != null:
		hud.get_parent().remove_child(hud)
	add_child(hud)
	hud.show()
	
	# 4. PLAYER STATE: Setup physics and position
	player.is_top_down = false
	player.gravity = 1600
	player.global_position = Vector2(600, 400)
	
	# 5. CAMERA & HUD
	_reset_camera(player)
	if hud.has_method("setup_health"):
		hud.setup_health(player)

func spawn_player_manually():
	var p_scene = load("res://entities/player/player.tscn")
	var h_scene = load("res://ui/hud.tscn")
	var p_instance = p_scene.instantiate()
	p_instance.current_health = Global.current_health
	Global.player = p_instance
	Global.hud = h_scene.instantiate()

func _reset_camera(target):
	var camera = target.get_node_or_null("Camera2D")
	if camera:
		camera.make_current()
		# Use a small delay so the camera doesn't "snap" awkwardly
		await get_tree().process_frame
		camera.global_position = target.global_position
