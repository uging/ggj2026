extends Node2D

@export var player_scene: PackedScene

func _ready() -> void:
	# If we are starting the game for the first time, show the title screen.
	# If we just switched scenes (via loading), skip the title and spawn the player.
	if Global.isTitleShown:
		_setup_title_screen()
		Global.isTitleShown = false
	else:
		# Use call_deferred to ensure the world geometry is ready before spawning player
		call_deferred("_on_start_button_pressed")

func _setup_title_screen() -> void:
	var title_scene = preload("res://main/title.tscn")
	var title = title_scene.instantiate()
	title.name = "TitleNode" 
	add_child(title)
	
	# Connect title screen signals
	title.start_game.connect(_on_start_button_pressed)
	title.load_game_pressed.connect(_on_load_button_pressed)

# --- LOADING LOGIC ---
func _on_load_button_pressed() -> void:
	SaveManager.load_game()

	# Check if we need to travel to a different level
	var saved_world = SaveManager.current_world
	var current_world = get_tree().current_scene.scene_file_path
	
	if saved_world != current_world:
		# This will destroy this Main node and load the one in the new scene
		get_tree().change_scene_to_file(saved_world)
	else:
		_on_start_button_pressed()

# --- CORE SPAWN LOGIC ---
func _on_start_button_pressed() -> void:
	# 1. Clean up references
	Global.player = null
	Global.hud = null

	# 2. Remove Title Menu if it exists
	var title = get_node_or_null("TitleNode")
	if title:
		title.queue_free()
	
	# Show help text if it exists in the scene
	if has_node("KeyLabel"):
		$KeyLabel.show()
	
	# 3. Setup HUD FIRST (So it's ready to listen for signals)
	var hud_scene = preload("res://ui/hud.tscn")
	var new_hud = hud_scene.instantiate()
	add_child(new_hud)
	Global.hud = new_hud
	
	# 4. Instantiate Player
	if not player_scene:
		push_error("Main.gd: Player Scene is not assigned in the Inspector!")
		return
		
	var new_player = player_scene.instantiate()
	
	# 5. INJECT SETTINGS BEFORE ADDING TO TREE
	# This ensures player._ready() uses the correct health and position
	new_player.is_top_down = true
	new_player.global_position = Vector2(600, 400) # Default spawn; adjust if needed
	new_player.current_health = Global.current_health
	
	# 6. CONNECT SIGNALS (The Bridge between Player and HUD)
	if new_hud.has_method("_on_health_changed"):
		new_player.health_changed.connect(new_hud._on_health_changed)
	
	if new_hud.has_method("_on_masks_updated"):
		new_player.masks_updated.connect(new_hud._on_masks_updated)

	# 7. Add Player to scene
	add_child(new_player)
	new_player.add_to_group("player")
	Global.player = new_player 
	
	# 8. Final Initial Sync
	# Force HUD to show the current health/masks immediately
	if new_hud.has_method("setup_health"):
		new_hud.setup_health(new_player)
