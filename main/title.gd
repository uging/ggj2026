extends Node2D

signal start_game

@onready var start_button = $StartButton
@onready var exit_button = $ExitButton

var active_tween: Tween

func _ready() -> void:
	await get_tree().process_frame
	setup_button_colors()
	
	# Initial state
	return_to_default_focus()
	
	# --- SAFE SIGNAL CONNECTIONS ---
	# We use .is_connected() to prevent the "Already Connected" error
	
	# Keyboard/Controller Focus
	if not start_button.focus_entered.is_connected(_on_focus_or_hover):
		start_button.focus_entered.connect(_on_focus_or_hover.bind(start_button))
	if not exit_button.focus_entered.is_connected(_on_focus_or_hover):
		exit_button.focus_entered.connect(_on_focus_or_hover.bind(exit_button))
	
	# Mouse Hover
	if not start_button.mouse_entered.is_connected(_on_focus_or_hover):
		start_button.mouse_entered.connect(_on_focus_or_hover.bind(start_button))
	if not exit_button.mouse_entered.is_connected(_on_focus_or_hover):
		exit_button.mouse_entered.connect(_on_focus_or_hover.bind(exit_button))
	
	# Mouse Exit
	if not start_button.mouse_exited.is_connected(_on_mouse_left_menu):
		start_button.mouse_exited.connect(_on_mouse_left_menu)
	if not exit_button.mouse_exited.is_connected(_on_mouse_left_menu):
		exit_button.mouse_exited.connect(_on_mouse_left_menu)

	# Pressed Logic
	if not start_button.pressed.is_connected(_on_start_button_pressed):
		start_button.pressed.connect(_on_start_button_pressed)
	if not exit_button.pressed.is_connected(_on_exit_button_pressed):
		exit_button.pressed.connect(_on_exit_button_pressed)

func setup_button_colors():
	var hover_green = Color(0.2, 0.8, 0.2)
	var hover_red = Color(0.8, 0.2, 0.2)
	
	start_button.add_theme_color_override("font_hover_color", hover_green)
	start_button.add_theme_color_override("font_focus_color", hover_green)
	
	exit_button.add_theme_color_override("font_hover_color", hover_red)
	exit_button.add_theme_color_override("font_focus_color", hover_red)

func _on_focus_or_hover(button: Button) -> void:
	if not button.has_focus():
		button.grab_focus()
	
	_reset_button_scales()
	start_pulse_animation(button)

func _on_mouse_left_menu() -> void:
	await get_tree().create_timer(0.1).timeout
	if not start_button.is_hovered() and not exit_button.is_hovered():
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
	exit_button.scale = Vector2.ONE

func start_pulse_animation(target_node: Control) -> void:
	target_node.pivot_offset = target_node.size / 2
	active_tween = create_tween().set_loops()
	active_tween.tween_property(target_node, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
	active_tween.tween_property(target_node, "scale", Vector2(1.0, 1.0), 0.6).set_trans(Tween.TRANS_SINE)

func _on_start_button_pressed() -> void:
	start_game.emit()

func _on_exit_button_pressed() -> void:
	get_tree().quit()
