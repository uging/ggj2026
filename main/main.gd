extends Node2D

# --- References ---
@export var player_scene: PackedScene # Linked to player.tscn in Inspector
@onready var level_container = $LevelContainer
@onready var player = $Player
@onready var hud = $UILayer/HUD
@onready var title_node = $UILayer/TitleNode
@onready var ui_layer = $UILayer

func _ready() -> void:
	# 1. Manager setup: Always process so we can handle menus while paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 2. Initial State: Gameplay is hidden, Title is shown
	player.hide()
	player.set_physics_process(false)
	hud.hide()
	
	# 3. Reference Sync: Let Global know where the permanent player is
	Global.player = player
	Global.hud = hud
	
	_setup_title_screen()

# --- Menu Logic ---

func _setup_title_screen() -> void:
	# Clear the placeholder just in case
	for child in title_node.get_children():
		child.queue_free()
		
	var title_scene = preload("res://main/title.tscn")
	var title_instance = title_scene.instantiate()
	
	# Add the title menu to our dedicated placeholder
	title_node.add_child(title_instance)
	
	# Connect signals from the title script
	title_instance.start_game.connect(_on_start_button_pressed)
	# If you want to use the load button:
	# title_instance.load_game_pressed.connect(func(): SaveManager.load_game())

func _on_start_button_pressed() -> void:
	# 1. Clean up the Title Menu
	title_node.hide()
	for child in title_node.get_children():
		child.queue_free()
	
	# 2. Reset Global state for a fresh start
	Global.current_health = 3
	Global.isTitleShown = false
	
	# 3. Load the Overworld/World Map first
	load_level("res://levels/world_map.tscn", Vector2(656, 318))

# --- Level Management ---

func load_level(path: String, spawn_pos: Vector2):
	# 1. Clear old level
	for child in level_container.get_children():
		child.queue_free()
		
	# SAVE THE BOOKMARK
	Global.last_level_path = path
	Global.last_spawn_pos = spawn_pos

	var level_resource = load(path)
	if level_resource:
		var new_level = level_resource.instantiate()
		level_container.add_child(new_level)

		# 2. FORCE Goma to appear
		player.global_position = spawn_pos
		player.z_index = 10 # Force him in front of the tiles
		player.show()
		player.modulate.a = 1.0 
		player.set_physics_process(true)
		player.set_process_input(true)
		player.is_dying = false

		# 3. Handle Movement Mode
		player.is_top_down = (path.contains("world_map"))

		# 4. FORCE HUD visibility
		hud.show()
		if hud.has_method("setup_health"):
			hud.setup_health(player)

		get_tree().paused = false
		print("Main: Player active at ", spawn_pos)

# --- Global Access ---
# This allows any area or door to request a level change
func change_scene(path: String, spawn_pos: Vector2):
	# Using call_deferred ensures physics calculations are finished before swapping
	call_deferred("load_level", path, spawn_pos)
