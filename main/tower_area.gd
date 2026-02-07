extends Area2D

@export var next_scene_path: String = "res://levels/tower_level.tscn"

var player_in_range: bool = false
@onready var name_label: Label = $NameLabel

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

func _input(event):
	# 1. Block input if the menu is open or the game is paused
	if get_tree().paused or Global.isTitleShown:
		return
		
	# 2.  Check for the Enter key specifically
	# This prevents the Space bar from accidentally triggering level entry
	if event is InputEventKey and event.pressed and event.keycode == KEY_ENTER:
		if player_in_range and overlaps_body(Global.player):
			_trigger_vortex_sequence()

func _trigger_vortex_sequence():
	GlobalAudioManager.play_portal_travel()
	
	# --- VORTEX SUCK-IN ---
	var suck = create_tween().set_parallel(true)
	suck.tween_property(Global.player, "scale", Vector2.ZERO, 0.4)
	suck.tween_property(Global.player, "modulate:a", 0.0, 0.4)
	
	await get_tree().create_timer(0.4).timeout

	if owner.has_method("enter_level"):
		owner.enter_level(next_scene_path, Vector2(850, 450))
