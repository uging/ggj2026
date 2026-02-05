extends Node2D

# --- References ---
@export var player_scene: PackedScene 
@onready var level_container = $LevelContainer
@onready var player = $Player
@onready var hud = $UILayer/HUD
@onready var title_node = $UILayer/TitleNode
@onready var ui_layer = $UILayer

func _ready() -> void:
	# 1. Manager setup
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 2. Reference Sync
	Global.player = player
	Global.hud = hud
	
	# --- CHANGE: Load the map IMMEDIATELY behind the menu ---
	# This populates the background so the TitleNode overlay looks layered.
	load_level("res://levels/world_map.tscn", Vector2(656, 318))
	
	# --- CHANGE: Initial Visibility Logic ---
	if Global.isTitleShown:
		show_title_screen()
	else:
		hide_title_screen()

# --- Menu Logic ---

# main.gd

func _setup_title_screen() -> void:
	# 1. Clear the placeholder just in case
	for child in title_node.get_children():
		child.queue_free()
		
	var title_scene = preload("res://main/title.tscn")
	var title_instance = title_scene.instantiate()
	
	# 2. Add the title menu to our dedicated placeholder
	title_node.add_child(title_instance)
	
	# 3. Connect signals from the title script
	title_instance.start_game.connect(_on_start_button_pressed)
	
	# --- THE FIX: RESET FOCUS ---
	# Ensure the Start Button is the first thing Godot looks at.
	# We use a tiny delay or process_frame to ensure the scene is ready.
	await get_tree().process_frame
	var start_btn = title_instance.get_node_or_null("StartButton")
	if start_btn:
		start_btn.grab_focus()

func _on_start_button_pressed() -> void:
	# --- CHANGE: Instead of loading level here, just hide the overlay ---
	hide_title_screen()
	
	# Reset Global state for a fresh start
	Global.current_health = 3
	if is_instance_valid(player):
		player.current_health = 3
		player.health_changed.emit(3)

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

		# --- THE CRITICAL UPDATE FOR CREDITS ---
		var is_credits = path.contains("credits")

		if is_credits:
			# If it's the credits, keep the "Gameplay" versions invisible
			player.hide()
			player.set_physics_process(false)
			player.set_process_input(false)
			hud.hide()
		else:
			# Standard gameplay loading logic
			player.global_position = spawn_pos
			player.z_index = 10 
			player.show()
			player.set_physics_process(true)
			player.set_process_input(true)
			player.is_dying = false

			# 3. Handle Movement Mode
			player.is_top_down = (path.contains("world_map"))

			# 4. HUD Logic
			if not Global.isTitleShown:
				hud.show()
				if hud.has_method("setup_health"):
					hud.setup_health(player)
			else:
				hud.hide()

		get_tree().paused = false
		print("Main: Level loaded at ", path)

# --- Global Access ---

func change_scene(path: String, spawn_pos: Vector2):
	call_deferred("load_level", path, spawn_pos)
	
func show_title_screen():
	# 1. Logic for showing the overlay
	title_node.show()
	_setup_title_screen()
	Global.isTitleShown = true

	# 2. Disable Goma's input so he doesn't jump while clicking buttons
	if is_instance_valid(player):
		player.input_enabled = false
		player.set_physics_process(false) # ADDED: Keep him from falling while menu is up

	# 3. Hide Gameplay HUD
	if is_instance_valid(hud):
		hud.hide()

func hide_title_screen():
	# 1. Hide Menu
	title_node.hide()
	Global.isTitleShown = false

	# 2. Re-enable Goma and show HUD
	if is_instance_valid(player):
		player.input_enabled = true
		player.set_physics_process(true)

	if is_instance_valid(hud):
		hud.show()
