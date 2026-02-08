extends Node2D

# --- References ---
@export var player_scene: PackedScene 
@onready var level_container = $LevelContainer
@onready var player = $Player
@onready var hud = $UILayer/HUD
@onready var title_node = $UILayer/TitleNode
@onready var ui_layer = $UILayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Global.player = player
	Global.hud = hud
	
	# Load the map. If Global.isTitleShown is true, 
	# load_level will now automatically freeze Goma.
	load_level("res://levels/world_map.tscn", Vector2(656, 318))
	
	if Global.isTitleShown:
		show_title_screen()
	else:
		hide_title_screen()

# --- Menu Logic ---

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
	title_instance.load_game_pressed.connect(_on_load_button_pressed)

func _on_start_button_pressed() -> void:
	# --- CHANGE: Instead of loading level here, just hide the overlay ---
	hide_title_screen()
	
	# Reset Global state for a fresh start
	Global.current_health = 3
	if is_instance_valid(player):
		player.current_health = 3
		player.health_changed.emit(3)

func _on_load_button_pressed() -> void:
	# 1. Hide UI first to set Global.isTitleShown = false [KEEP]
	hide_title_screen() 
	
	# 2. Trigger the actual data load [KEEP]
	SaveManager.load_game()
	
	# 3. Sync player stats and visuals from the newly loaded Global data [UPDATE]
	if is_instance_valid(player):
		# Sync Health and emit signal for HUD [KEEP]
		player.current_health = Global.current_health
		player.health_changed.emit(player.current_health)
		
		# We use 'true' for the silent parameter to avoid the poof sound on load
		player.change_set(Global.current_equipped_set, true)
		
		# Force the movement mode check [KEEP]
		player.is_top_down = (Global.current_level_path.contains("world_map"))
		
# --- Level Management ---

func load_level(path: String, spawn_pos: Vector2):
	# 1. Clear old level [KEEP]
	for child in level_container.get_children():
		child.queue_free()
		
	# 2. Update Bookmarks [KEEP]
	Global.origin_level_path = Global.current_level_path
	Global.current_level_path = path
	Global.last_spawn_pos = spawn_pos

	# 3. Handle Movement Mode [KEEP]
	if is_instance_valid(player):
		player.is_top_down = (path.contains("world_map"))
		
	# 4. Instantiate New Level [UPDATE]
	var level_resource = load(path)
	if level_resource:
		var new_level = level_resource.instantiate()
		
		# --- DUPLICATE PROTECTION ---
		# This prevents the "Two Gomas" issue by removing any Goma 
		# that accidentally exists inside the level scene file.
		var extra_goma = new_level.find_child("Player", true, false)
		if not extra_goma:
			extra_goma = new_level.find_child("Goma", true, false)
			
		if extra_goma:
			extra_goma.queue_free() 
		# --- END DUPLICATE PROTECTION ---

		level_container.add_child(new_level)

		# 5. Handle Credits vs Gameplay [KEEP]
		var is_credits = path.contains("credits")

		if is_credits:
			player.hide()
			player.set_physics_process(false)
			player.set_process_input(false)
			hud.hide()
		else:
			# 6. Positioning [KEEP]
			player.global_position = spawn_pos
			player.z_index = 10
			player.is_dying = false
			
			# 7. Menu vs Gameplay State [UPDATE]
			if Global.isTitleShown:
				player.process_mode = Node.PROCESS_MODE_DISABLED
				player.hide()
			else:
				player.process_mode = Node.PROCESS_MODE_INHERIT
				player.show()
				hud.show()
				
				# Instead of setup_health, we use the signal to sync the hearts.
				if is_instance_valid(player):
					player.health_changed.emit(player.current_health)

			# 8. Re-confirm Movement Mode [KEEP]
			player.is_top_down = (path.contains("world_map"))

		get_tree().paused = false

# --- Global Access ---

func change_scene(path: String, spawn_pos: Vector2):
	call_deferred("load_level", path, spawn_pos)
	
func show_title_screen():
	title_node.show()
	_setup_title_screen()
	Global.isTitleShown = true

	if is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_DISABLED 
		player.hide()
		player.input_enabled = false
		
		# --- THE FIX: Disable Goma's Camera while in Menu ---
		var cam = player.get_node_or_null("Camera2D")
		if cam:
			cam.enabled = false

	if is_instance_valid(hud):
		hud.hide()

func hide_title_screen():
	title_node.hide()
	Global.isTitleShown = false
	
	# Re-enable GUI sounds now that the menu is gone
	GlobalAudioManager.mute_all_gui_sounds = false
	if is_instance_valid(player):
		player.process_mode = Node.PROCESS_MODE_INHERIT
		player.show()
		player.input_enabled = true
		
		# --- THE TRANSITION FADE ---
		# Find the music node inside the level_container
		var map_audio = level_container.find_child("AudioStreamPlayer", true, false)
		if map_audio:
			if not map_audio.playing: 
				map_audio.play()
			
			# 1. Quick "Dip" (to -20db) to create a 'swish' effect as the menu closes
			GlobalAudioManager.fade_music(-20.0, 0.4) 
			
			# 2. After 0.4s, smoothly "Rise" back to full 0dB volume
			get_tree().create_timer(0.4).timeout.connect(func():
				GlobalAudioManager.fade_music(0.0, 1.2)
			)

		# Re-enable the Camera
		var cam = player.get_node_or_null("Camera2D")
		if cam:
			cam.enabled = true
			cam.make_current()

	if is_instance_valid(hud):
		hud.show()
