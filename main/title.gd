extends Node2D

signal start_game

# Updated to match your actual node name "StartButton"
@onready var start_button = $StartButton

func _ready() -> void:
	# Give the UI a moment to calculate its size
	await get_tree().process_frame
	
	if start_button:
		start_pulse_animation()
		# This ensures the Enter key works immediately
		start_button.grab_focus()
	else:
		print("Error: Could not find node named 'StartButton'. Check your scene tree!")

func _input(event: InputEvent) -> void:
	# Trigger the game start when Enter or Space is pressed
	if event.is_action_pressed("ui_accept"):
		_on_start_button_pressed()

func start_pulse_animation() -> void:
	if not start_button: return
	
	# Set pivot to center so it pulses from the middle
	var b_size = start_button.size
	if b_size == Vector2.ZERO:
		b_size = Vector2(245, 115) # Fallback size if Godot reports 0
	
	start_button.pivot_offset = b_size / 2
	
	# Create the breathing/pulse effect
	var tween = create_tween().set_loops()
	tween.tween_property(start_button, "scale", Vector2(1.1, 1.1), 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(start_button, "scale", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_SINE)

func _on_start_button_pressed() -> void:
	# Tell main.gd to start the game
	start_game.emit()
