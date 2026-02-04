extends Area2D

@export var next_scene_path: String = "res://levels/tower_level.tscn"

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

func _input(event):
	if event.is_action_pressed("interact") and player_in_range:
		# 1. Detach player from old scene FIRST
		if Global.player and Global.player.get_parent():
			Global.player.get_parent().remove_child(Global.player)
			
		if Global.hud and Global.hud.get_parent():
			Global.hud.get_parent().remove_child(Global.hud)
		
		# 2. Safe scene change
		get_tree().call_deferred("change_scene_to_file", next_scene_path)
