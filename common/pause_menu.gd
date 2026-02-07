extends CanvasLayer

var pre_mute_volume : float = 1.0 # Stores volume level before muting

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	# Add this check to prevent the "Already Connected" error
	var resume_btn = $CenterContainer/VBoxContainer/ResumeButton
	if not resume_btn.pressed.is_connected(toggle_pause):
		resume_btn.pressed.connect(toggle_pause)

func _input(event):
	if event.is_action_pressed("pause"):
		# 1. Don't pause if the Title Screen is active!
		if Global.isTitleShown:
			return

		# 2. Don't pause if we aren't in a level
		if Global.player == null:
			return

		# 3. Don't pause if the Game Over screen is already open!
		if get_tree().root.find_child("GameOver", true, false):
			return
		toggle_pause()

func toggle_pause():
	var new_pause_state = !get_tree().paused
	get_tree().paused = new_pause_state
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if new_pause_state:
		show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_mute_music_bus(true)
		if has_node("OpenSound"): $OpenSound.play() # Play a brief pop sound
		
		# SYNC SLIDER POSITION
		var bus_index = AudioServer.get_bus_index("Master")
		var current_db = AudioServer.get_bus_volume_db(bus_index)
		var linear_val = db_to_linear(current_db)
		
		$CenterContainer/VBoxContainer/VolumeSlider.value = linear_val
		
		# --- THE FIX: Store the current volume in memory when opening ---
		# Only update memory if the volume is actually above zero
		if linear_val > 0:
			pre_mute_volume = linear_val

		# SYNC MUTE BUTTON STATE
		$CenterContainer/VBoxContainer/MuteButton.button_pressed = AudioServer.is_bus_mute(bus_index)
		$CenterContainer/VBoxContainer/VolumeSlider.focus_neighbor_top = $CenterContainer/VBoxContainer/ResumeButton.get_path()
		$CenterContainer/VBoxContainer/VolumeSlider.focus_neighbor_bottom = $CenterContainer/VBoxContainer/MuteButton.get_path()

		# 1. First, handle the visibility of buttons
		# Check if the currently loaded level is the world map
		var level_container = get_tree().root.find_child("LevelContainer", true, false)
		var current_level = level_container.get_child(0) if level_container and level_container.get_child_count() > 0 else null

		var is_on_map = false
		if current_level:
			is_on_map = current_level.scene_file_path.contains("world_map")

		if is_on_map:
			$CenterContainer/VBoxContainer/MapButton.hide()
			$CenterContainer/VBoxContainer/RestartButton.hide()
		else:
			$CenterContainer/VBoxContainer/MapButton.show()
			$CenterContainer/VBoxContainer/RestartButton.show()
		
		# 3. FINALLY, grab focus on the Resume button 
		$CenterContainer/VBoxContainer/ResumeButton.grab_focus()
		
	else:
		hide()
		_mute_music_bus(false)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# --- BUTTON CONNECTIONS ---
# Make sure these are connected to the "pressed()" signal in the Node tab!

func _on_restart_button_pressed() -> void:
	_mute_music_bus(false)
	# 1. Unpause the game and hide the menu
	toggle_pause()
	
	# 2. Find the Main manager shell
	var main = get_tree().root.get_node_or_null("Main")
	
	# 3. Use the "Bookmarks" we just added to Global.gd
	if main and main.has_method("load_level"):
		if Global.current_level_path != "":
			main.load_level(Global.current_level_path, Global.last_spawn_pos)
		else:
			push_error("PauseMenu: No current_level_path found in Global!")

func _on_map_button_pressed() -> void:
	_mute_music_bus(false)
	# 1. Close the menu and unpause first
	toggle_pause() 
	
	# 2. Find the Main shell (the manager)
	var main = get_tree().root.get_node_or_null("Main")
	
	if main and main.has_method("load_level"):
		# 3. Use the manager's load_level function. 
		# This keeps Main (and Goma/HUD) alive!
		main.load_level("res://levels/world_map.tscn", Vector2(656, 318))
	else:
		# Fallback if Main isn't found
		get_tree().change_scene_to_file("res://levels/world_map.tscn")
	
func _on_save_button_pressed() -> void:
	SaveManager.save_game()
	_show_save_notification()

func _on_end_button_pressed() -> void:
	get_tree().quit()

# This handles the slider movement
func _on_volume_slider_value_changed(value: float) -> void:
	Global.set_volume(value)
	
	# Update the mute button checkbox visually if we hit 0
	$CenterContainer/VBoxContainer/MuteButton.button_pressed = (value <= 0)
	
	# IMPORTANT: If the user moves the slider manually while NOT muted,
	# update the memory so unmuting later feels natural.
	if value > 0:
		pre_mute_volume = value

# This handles the mute checkbox
func _on_mute_button_toggled(toggled_on: bool) -> void:
	var slider = $CenterContainer/VBoxContainer/VolumeSlider
	
	if toggled_on:
		# 1. SAVE the current volume before zeroing out
		pre_mute_volume = slider.value
		# 2. Update the Bus through Global
		Global.toggle_mute(true)
		# 3. Visually move the slider
		slider.value = 0
	else:
		# 1. RESTORE the volume from memory
		Global.toggle_mute(false)
		slider.value = pre_mute_volume
		# 2. Ensure the Bus volume is actually set back to the old value
		Global.set_volume(pre_mute_volume)
		
# Your existing resume logic
func _on_resume_pressed() -> void:
	get_tree().paused = false
	hide()

# --- VISUAL FEEDBACK ---

func _show_save_notification():
	if has_node("SaveLabel"):
		var label = $SaveLabel
		label.show()
		label.text = "Game Saved!"
		label.modulate.a = 1.0 # Reset opacity

		# Position Reset (Optional: starts slightly lower and floats up)
		var original_pos = label.position

		var tween = create_tween().set_parallel(true) # Run fade and move together

		# 1. Fade out after a 1 second delay
		tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(1.0)

		# 2. Subtle float upward
		tween.tween_property(label, "position:y", original_pos.y - 20, 1.0).set_delay(1.0)

		# 3. Cleanup: Reset position and hide when finished
		tween.chain().finished.connect(func(): 
			label.hide()
			label.position = original_pos
		)
		
func _mute_music_bus(should_mute: bool):
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx != -1:
		AudioServer.set_bus_mute(bus_idx, should_mute)

func _gui_input(event: InputEvent) -> void:
	# --- BLOCK SPACE BAR SELECTION ---
	# If the event is a Space Bar press, mark it as handled 
	# so it never triggers the focused button's "pressed" state.
	if event is InputEventKey and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
