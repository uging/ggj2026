extends CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	# Add this check to prevent the "Already Connected" error
	var resume_btn = $CenterContainer/VBoxContainer/ResumeButton
	if not resume_btn.pressed.is_connected(toggle_pause):
		resume_btn.pressed.connect(toggle_pause)

func _input(event):
	if event.is_action_pressed("pause"):
		# If the player isn't in the Global script yet, we aren't in a level!
		if Global.player == null:
			print("Ignoring pause: No player found in Global.")
			return

		print("ESC pressed! Pausing game...")
		toggle_pause()

func toggle_pause():
	var new_pause_state = !get_tree().paused
	get_tree().paused = new_pause_state
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if new_pause_state:
		show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
		# SYNC SLIDER POSITION
		var bus_index = AudioServer.get_bus_index("Master")
		var current_db = AudioServer.get_bus_volume_db(bus_index)
		# Convert decibels back to 0.0 - 1.0 for the slider
		$CenterContainer/VBoxContainer/VolumeSlider.value = db_to_linear(current_db)

		# SYNC MUTE BUTTON STATE
		$CenterContainer/VBoxContainer/MuteButton.button_pressed = AudioServer.is_bus_mute(bus_index)
		$CenterContainer/VBoxContainer/VolumeSlider.focus_neighbor_top = $CenterContainer/VBoxContainer/ResumeButton.get_path()
		$CenterContainer/VBoxContainer/VolumeSlider.focus_neighbor_bottom = $CenterContainer/VBoxContainer/MuteButton.get_path()

		# 1. First, handle the visibility of buttons
		var is_on_map = get_tree().current_scene.name == "Main"
		
		if is_on_map:
			$CenterContainer/VBoxContainer/MapButton.hide()
			$CenterContainer/VBoxContainer/RestartButton.hide()
		else:
			$CenterContainer/VBoxContainer/MapButton.show()
			$CenterContainer/VBoxContainer/RestartButton.show()
		
		# 2. Reset the Menu Containers (if you added the Settings page)
		# main_container.show()
		# settings_container.hide()

		# 3. FINALLY, grab focus on the Resume button 
		# This must be the LAST focus command in this function
		$CenterContainer/VBoxContainer/ResumeButton.grab_focus()
		
	else:
		hide()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# --- BUTTON CONNECTIONS ---
# Make sure these are connected to the "pressed()" signal in the Node tab!

func _on_restart_button_pressed() -> void:
	toggle_pause()
	get_tree().reload_current_scene()

func _on_map_button_pressed() -> void:
	toggle_pause()
	Global.isTitleShown = false
	get_tree().change_scene_to_file("res://main/main.tscn")
	
func _on_save_button_pressed() -> void:
	SaveManager.save_game()
	_show_save_notification()

func _on_end_button_pressed() -> void:
	get_tree().quit()

# This handles the slider movement
func _on_volume_slider_value_changed(value: float) -> void:
	# Use the global function we created earlier
	Global.set_volume(value)

# This handles the mute checkbox
func _on_mute_button_toggled(toggled_on: bool) -> void:
	Global.toggle_mute(toggled_on)

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
