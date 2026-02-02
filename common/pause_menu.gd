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
	
	if new_pause_state:
		show()
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
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
		# Important: This returns control to Goma's movement
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

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

# --- VISUAL FEEDBACK ---

func _show_save_notification():
	# If you add a Label to your PauseMenu tree called 'SaveLabel'
	if has_node("SaveLabel"):
		var label = $SaveLabel
		label.show()
		label.text = "Game Saved!"
		label.modulate.a = 1.0
		
		var tween = create_tween()
		tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(1.0)
		tween.finished.connect(label.hide)
