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
	# Load data from file into SaveManager variables first
	SaveManager.load_game()
	# Then trigger the normal start process
	_on_start_button_pressed()

func _on_start_button_pressed() -> void:
	Global.player = null
	Global.hud = null

	var title = get_node_or_null("TitleNode")
	if title:
		title.queue_free()
	
	if has_node("KeyLabel"):
		$KeyLabel.show()
	
	var hud_scene = preload("res://hud.tscn")
	var new_hud = hud_scene.instantiate()
	add_child(new_hud)
	Global.hud = new_hud
	
	var new_player = player_scene.instantiate()
	new_player.add_to_group("player")
	add_child(new_player)
	Global.player = new_player 
	
	new_player.is_top_down = true
	new_player.velocity = Vector2.ZERO
	new_player.global_position = Vector2(600, 400)
	
	# --- INJECT SAVED HEALTH ---
	# We override the player's default health with whatever SaveManager just loaded
	new_player.current_health = SaveManager.current_health
	
	if new_hud.has_method("setup_health"):
		new_hud.setup_health(new_player)
