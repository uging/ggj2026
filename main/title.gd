extends Node2D

signal start_game
signal load_game_pressed

@onready var start_button = $StartButton
@onready var load_button = $LoadButton
@onready var exit_button = $ExitButton

var active_tween: Tween
var can_play_audio := false

func _ready() -> void:
	# 1. IMMEDIATELY tell the manager to be silent
	GlobalAudioManager.mute_all_gui_sounds = true
	can_play_audio = false # Your internal script gate
	
	# 2. Wait for the engine to settle
	await get_tree().process_frame
	
	# 3. Setup visual appearance
	setup_button_colors()
	
	# 4. Define and connect buttons
	var button_logic = {
		start_button: _on_start_button_pressed,
		load_button: _on_load_button_pressed,
		exit_button: _on_exit_button_pressed
	}
	
	for button in button_logic.keys():
		if button == null: continue
		
		if not button.focus_entered.is_connected(_on_focus_or_hover):
			button.focus_entered.connect(_on_focus_or_hover.bind(button))
		if not button.mouse_entered.is_connected(_on_focus_or_hover):
			button.mouse_entered.connect(_on_focus_or_hover.bind(button))
		if not button.mouse_exited.is_connected(_on_mouse_left_menu):
			button.mouse_exited.connect(_on_mouse_left_menu)
			
		var target_function = button_logic[button]
		if not button.pressed.is_connected(target_function):
			button.pressed.connect(target_function)

	# 5. --- THE FIX: SILENT INITIALIZATION ---
	# We manually trigger the first focus while EVERYTHING is muted
	if start_button:
		# Triple protection: Block signals, Mute Manager, and Lock Script Gate
		start_button.set_block_signals(true)
		start_button.grab_focus()
		start_button.set_block_signals(false)
		
		_reset_button_scales()
		start_pulse_animation(start_button)
		
	# 6. Wait for all automated focus logic to finish before unmuting
	get_tree().create_timer(0.5).timeout.connect(func():
		GlobalAudioManager.mute_all_gui_sounds = false
		can_play_audio = true
	)

	# 7. Load Button Visual State
	if not FileAccess.file_exists("user://savegame.save"):
		load_button.modulate.a = 0.5

func setup_button_colors():
	var hover_green = Color(0.2, 0.8, 0.2)
	var hover_blue = Color(0.2, 0.5, 0.9) # Distinct color for Load
	var hover_red = Color(0.8, 0.2, 0.2)
	
	start_button.add_theme_color_override("font_hover_color", hover_green)
	start_button.add_theme_color_override("font_focus_color", hover_green)
	
	load_button.add_theme_color_override("font_hover_color", hover_blue)
	load_button.add_theme_color_override("font_focus_color", hover_blue)
	
	exit_button.add_theme_color_override("font_hover_color", hover_red)
	exit_button.add_theme_color_override("font_focus_color", hover_red)

func _on_focus_or_hover(button: Button) -> void:
	if not button.has_focus():
		button.grab_focus()

	_reset_button_scales()
	start_pulse_animation(button)

func _on_mouse_left_menu() -> void:
	await get_tree().create_timer(0.1).timeout
	# Check all three buttons now
	if not start_button.is_hovered() and not load_button.is_hovered() and not exit_button.is_hovered():
		return_to_default_focus()

func return_to_default_focus() -> void:
	if start_button:
		start_button.grab_focus()
		_reset_button_scales()
		start_pulse_animation(start_button)

func _reset_button_scales() -> void:
	if active_tween:
		active_tween.kill()
	start_button.scale = Vector2.ONE
	load_button.scale = Vector2.ONE
	exit_button.scale = Vector2.ONE

func start_pulse_animation(target_node: Control) -> void:
	target_node.pivot_offset = target_node.size / 2
	active_tween = create_tween().set_loops()
	active_tween.tween_property(target_node, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
	active_tween.tween_property(target_node, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)

func _on_start_button_pressed() -> void:
	start_game.emit()

func _on_load_button_pressed() -> void:
	if FileAccess.file_exists("user://savegame.save"):
		load_game_pressed.emit() # This tells Main.gd to start loading
	else:
		# PUNCHIER SHAKE: Feedback that the button is "locked"
		var original_x = load_button.position.x
		var shake = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		# 3 rapid cycles (Right -> Left -> Center)
		for i in range(3):
			shake.tween_property(load_button, "position:x", original_x + 8.0, 0.04)
			shake.tween_property(load_button, "position:x", original_x - 8.0, 0.04)
		
		shake.tween_property(load_button, "position:x", original_x, 0.04)
		
		# Optional: Play a buzzer/error sound
		GlobalAudioManager._play_sfx(GlobalAudioManager.hurt_sfx)

func _on_exit_button_pressed() -> void:
	get_tree().quit()
