extends Area2D

@export var next_scene_path: String = "res://gameover/game_over_layer.tscn"

var player_in_range: bool = false


func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = true
		# 1. Detach player from old scene FIRST
		if Global.player and Global.player.get_parent():
			Global.player.get_parent().remove_child(Global.player)
			
		if Global.hud and Global.hud.get_parent():
			Global.hud.get_parent().remove_child(Global.hud)
		#
		## 2. Safe scene change
		get_tree().call_deferred("change_scene_to_file", next_scene_path)
		#game_over.restart_game.connect(_on_game_restart)  # Handle restart

func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = false

func _input(event):
	if event.is_action_pressed("ui_accept") and player_in_range:
		pass
