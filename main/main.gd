extends Node2D

@export var player_scene: PackedScene

func _ready() -> void:
	if Global.isTitleShown:
		var title_scene = preload("res://main/title.tscn")
		var title = title_scene.instantiate()
		title.name = "TitleNode" 
		add_child(title)
		
		# --- CONNECT LOAD SIGNAL ---
		title.start_game.connect(_on_start_button_pressed)
		title.load_game_pressed.connect(_on_load_button_pressed) # New connection
		
		Global.isTitleShown = false
	else:
		call_deferred("_on_start_button_pressed")

# --- FUNCTION FOR LOAD BUTTON ---
func _on_load_button_pressed() -> void:
	SaveManager.load_game()

	# If the saved world is different from the current one, change it
	if SaveManager.current_world != get_tree().current_scene.scene_file_path:
		get_tree().change_scene_to_file(SaveManager.current_world)
		# Note: After this, Main.gd will be re-instantiated in the new scene.
		# Ensure Main.gd is actually present in your world scenes or 
		# that it is a Global Autoload (Singleton).
	else:
		_on_start_button_pressed()

func _on_start_button_pressed() -> void:
	Global.player = null
	Global.hud = null

	# 1. Hide the UI layers
	var title = get_node_or_null("TitleNode")
	if title:
		title.queue_free() # Remove the menu
	
	if has_node("KeyLabel"):
		$KeyLabel.show()
	
	# 2. Setup HUD
	var hud_scene = preload("res://ui/hud.tscn")
	var new_hud = hud_scene.instantiate()
	add_child(new_hud) # Adds HUD to the Main scene
	Global.hud = new_hud
	
	# 3. Instantiate Player
	var new_player = player_scene.instantiate()
	new_player.add_to_group("player")
	
	# 4. INJECT DATA & POSITION
	new_player.current_health = Global.current_health
	new_player.is_top_down = true
	new_player.velocity = Vector2.ZERO
	new_player.global_position = Vector2(600, 400) 
	
	# 5. Add Player to the scene
	add_child(new_player)
	Global.player = new_player 
	
	# 6. Final Polish
	if new_hud.has_method("setup_health"):
		new_hud.setup_health(new_player)
