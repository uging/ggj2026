extends CanvasLayer

# Get references to the nodes we need to animate
@onready var character_anchor = $ColorRect/CenterContainer/VBoxContainer/CharacterControl/CharacterAnchor
@onready var restart_btn = $ColorRect/CenterContainer/VBoxContainer/RestartButton
@onready var menu_btn = $ColorRect/CenterContainer/VBoxContainer/MenuButton

func _ready():
	# 1. Sync Visuals: Match Goma's equipment before he is reset
	_sync_death_visuals()
	
	# 2. Allow this node to run while the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# 3. Start with the "Dead" look (tilted, dim)
	character_anchor.rotation_degrees = 90
	character_anchor.modulate = Color(0.5, 0.5, 0.5)
	
	# 4. GRAB FOCUS for arrow key navigation
	await get_tree().process_frame
	restart_btn.grab_focus()
	
func _sync_death_visuals():
	# Get the real player to see what they were wearing at time of death
	var real_player = Global.player
	if not is_instance_valid(real_player): return
	_mute_music_bus(false)
	
	# Retrieve the set data based on the current ID
	var current_id = real_player.current_set_id
	var data = real_player.set_data[current_id]
	
	# Update the decorative sprites in the GameOver UI
	var death_mask = character_anchor.get_node("Mask")
	var death_cape = character_anchor.get_node("Cape")
	
	death_mask.texture = data["mask"]
	death_mask.position = data["mask_pos"]
	death_mask.scale = data["mask_scale"]
	death_cape.texture = data["cape"]

func _on_restart_pressed():
	set_buttons_disabled(true)
	GlobalAudioManager.stop_all_loops()
	Global.reset_player_stats() 
	_mute_music_bus(false)
	
	# 1. Animate the UI character coming "Back to Life"
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(character_anchor, "rotation_degrees", 0, 0.5)
	tween.parallel().tween_property(character_anchor, "modulate", Color.WHITE, 0.3)
	
	await tween.finished
	
	var main = get_tree().root.get_node_or_null("Main")
	if main and main.has_method("load_level"):
		if Global.last_level_path != "":
			main.load_level(Global.last_level_path, Global.last_spawn_pos)
	
	queue_free()

func _on_menu_pressed():
	set_buttons_disabled(true)
	# Ensure music is unmuted for the title screen
	
	var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(character_anchor, "position:y", -100, 0.3).as_relative()
	tween.tween_property(character_anchor, "position:y", 500, 0.4).as_relative()
	
	await tween.finished
	
	Global.reset_player_stats()
	Global.isTitleShown = true 
	
	if is_instance_valid(Global.hud):
		Global.hud.hide()
	
	get_tree().paused = false
	menu_btn.release_focus()
	_mute_music_bus(false)
	get_tree().change_scene_to_file("res://main/main.tscn")
	queue_free()

func set_buttons_disabled(state: bool):
	restart_btn.disabled = state
	menu_btn.disabled = state

func _mute_music_bus(should_mute: bool):
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx != -1:
		AudioServer.set_bus_mute(bus_idx, should_mute)
