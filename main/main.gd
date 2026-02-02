extends Node2D

@export var player_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 1. Title Screen Logic
	if Global.isTitleShown:
		var title_scene = preload("res://main/title.tscn")
		var title = title_scene.instantiate()
		
		# Give it a name so _on_start_button_pressed can find it to hide/free it
		title.name = "TitleNode" 
		add_child(title)
		
		# Connect the signal
		title.start_game.connect(_on_start_button_pressed)
		
		# Mark that we've shown the title so it doesn't loop forever
		Global.isTitleShown = false
	else:
		# 2. Death/Reload Logic
		# If we are here because Goma died, we use 'call_deferred'.
		# This tells Godot: "Wait until the current frame is 100% finished 
		# and the old player is fully deleted before starting the game again."
		call_deferred("_on_start_button_pressed")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_start_button_pressed() -> void:
	# 0. THE CRASH SHIELD: Clear old references first
	Global.player = null
	Global.hud = null

	# 1. Safely handle the Title Screen
	var title = get_node_or_null("TitleNode")
	if title:
		title.queue_free()
	
	# Show your key instructions
	if has_node("KeyLabel"):
		$KeyLabel.show()
	
	# 2. Create FRESH HUD first
	# We do this first so the HUD is ready to listen when the player is born
	var hud_scene = preload("res://hud.tscn")
	var new_hud = hud_scene.instantiate()
	add_child(new_hud)
	Global.hud = new_hud
	
	# 3. Create Player
	var new_player = player_scene.instantiate()
	new_player.add_to_group("player")
	add_child(new_player)
	Global.player = new_player 
	
	# 4. Setup Player Stats
	new_player.is_top_down = true
	new_player.velocity = Vector2.ZERO
	new_player.global_position = Vector2(600, 400)
	
	# 5. THE HANDSHAKE
	# Manually trigger the connection so we don't rely on timing/groups
	if new_hud.has_method("setup_health"):
		new_hud.setup_health(new_player)
