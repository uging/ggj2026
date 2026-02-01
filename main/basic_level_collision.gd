extends Area2D

@export var next_scene_path: String = "res://levels/basic_level.tscn"
var player_in_range: bool = false

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("Player"):  # Add player to "Player" group
		player_in_range = true

func _on_body_exited(body):
	if body.is_in_group("Player"):
		player_in_range = false

func _input(event):
	if event.is_action_pressed("ui_accept") and player_in_range:  # Enter key
		get_tree().change_scene_to_file(next_scene_path)
