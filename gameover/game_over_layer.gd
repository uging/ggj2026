extends CanvasLayer

signal restart_game

@onready var timer: Timer = $Timer
#@onready var menu_button: Button = $VBoxContainer/MainMenuButton

func _ready():
	timer.timeout.connect(_on_timer_timeout)
	#menu_button.pressed.connect(_on_menu_pressed)

func show_game_over(score: int):
	$VBoxContainer/ScoreLabel.text = "Final Score: %d" % score
	visible = true

func _on_timer_timeout():
	restart_game.emit()

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://main.tscn")
