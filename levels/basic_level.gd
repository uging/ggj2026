extends Node2D

func _ready() -> void:
	print("The Forest!")
	
	# 1. RESPOND TO RESPAWN: If Goma is missing (after death reload), make him
	if Global.player == null:
		spawn_player_manually()
	
	# 2. WAIT: Ensure they exist before we touch them
	while Global.player == null or Global.hud == null:
		await get_tree().process_frame
	
	var player = Global.player
	var hud = Global.hud

	# 3. RE-PARENT: Move Player and HUD into this scene safely
	if player.get_parent() != null:
		player.get_parent().remove_child(player)
	add_child(player)
	
	if hud.get_parent() != null:
		hud.get_parent().remove_child(hud)
	add_child(hud)
	hud.show()
	
	# 4. PLAYER STATE: Set position and physics
	player.is_top_down = false
	player.gravity = 1600
	player.global_position = Vector2(600, 400)
	
	# 5. CAMERA & HUD: Snap camera and sync health
	_reset_camera(player)
	if hud.has_method("setup_health"):
		hud.setup_health(player)
	
	# 6. CLEANUP COLLECTED MASKS
	_cleanup_pickups(player)

# Logic for cleaning up masks you already own
func _cleanup_pickups(player_node):
	for item in get_tree().get_nodes_in_group("pickups"):
		var item_name = item.name.to_lower()
		if "rock" in item_name and player_node.unlocked_masks["rock"]:
			item.queue_free()
		elif "gum" in item_name and player_node.unlocked_masks["gum"]:
			item.queue_free()
		elif "feather" in item_name and player_node.unlocked_masks["feather"]:
			item.queue_free()

# Same helper functions we used in the Pyramid
func spawn_player_manually():
	var p_scene = load("res://entities/player/player.tscn") # Update to your path
	var h_scene = load("res://hud.tscn")    # Update to your path
	Global.player = p_scene.instantiate()
	Global.hud = h_scene.instantiate()

func _reset_camera(target):
	var camera = target.get_node_or_null("Camera2D")
	if camera:
		camera.make_current()
		camera.global_position = target.global_position
		if camera.has_method("reset_smoothing"):
			camera.reset_smoothing()
