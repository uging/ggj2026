extends Node2D

func _ready() -> void:
	print("The Tower!")
	
	# 1. RESPOND TO RESPAWN: If Goma is missing after a death reload, create him
	if Global.player == null:
		spawn_player_manually()
	
	# 2. WAIT: Ensure both exist before we try to parent them
	while Global.player == null or Global.hud == null:
		await get_tree().process_frame
	
	var player = Global.player
	var hud = Global.hud

	# 3. RE-PARENT: Safely move them into the Tower scene
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	add_child(player)
	
	if hud.get_parent() != null:
		hud.get_parent().remove_child(hud)
	add_child(hud)
	hud.show()

	# 4. TOWER STATE: Set position and physics
	# Note: Tower uses the same gravity as the other levels for consistency
	player.is_top_down = false
	player.gravity = 1600
	player.global_position = Vector2(700, 450) 
	
	# 5. SYNC: Link HUD and Snap Camera
	if hud.has_method("setup_health"):
		hud.setup_health(player)
		
	_reset_camera(player)

# HELPER: Spawn fresh nodes if Global is empty
func spawn_player_manually():
	var p_scene = load("res://player.tscn") 
	var h_scene = load("res://hud.tscn")
	Global.player = p_scene.instantiate()
	Global.hud = h_scene.instantiate()

# HELPER: Prevent the "looking at (0,0)" camera glitch
func _reset_camera(target):
	var camera = target.get_node_or_null("Camera2D")
	if camera:
		camera.make_current()
		camera.global_position = target.global_position
		if camera.has_method("reset_smoothing"):
			camera.reset_smoothing()
		print("Tower camera synced to Goma at: ", target.global_position)
