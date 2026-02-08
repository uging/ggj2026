extends Area2D

@export var next_scene_path: String = "res://levels/basic_level.tscn"

var player_in_range: bool = false
@onready var name_label: Label = $NameLabel  # Add Label child named "NameLabel"

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	name_label.visible = false

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		name_label.visible = true

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false
		name_label.visible = false

func _input(event: InputEvent) -> void:
	# 1. Block input if any menu (Pause or Title) is active
	if get_tree().paused or Global.isTitleShown:
		return
		
	if not is_instance_valid(Global.player): 
		return
		
	# 2. Only accept the Enter key specifically
	# This avoids the "Space Bar" bleed-through from UI buttons
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		# 3. Verify Goma is actually inside the Area2D before triggering
		if overlaps_body(Global.player):
			_trigger_portal_sequence()

func _trigger_portal_sequence() -> void:
	GlobalAudioManager.play_portal_travel()
	
	# --- VORTEX SUCK-IN ---
	var suck_tween = create_tween().set_parallel(true)
	suck_tween.tween_property(Global.player, "scale", Vector2.ZERO, 0.4)
	suck_tween.tween_property(Global.player, "modulate:a", 0.0, 0.4)

	# Wait a moment for the animation
	await get_tree().create_timer(0.4).timeout

	if owner.has_method("enter_level"):
		# Move to the level scene using the established coordinates
		owner.enter_level(next_scene_path, Vector2(250, 450))
