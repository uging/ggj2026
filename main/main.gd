extends Node2D

@export var player_scene: PackedScene

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Global.isTitleShown:
		var title_scene = preload("res://main/title.tscn")
		var title = title_scene.instantiate()
		add_child(title)
		title.start_game.connect(_on_start_button_pressed)
		Global.isTitleShown = false
	else:
		_on_start_button_pressed()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_button_pressed() -> void:
	if $TitleNode:
		$TitleNode.hide()
	
	add_child(Global.player)
	Global.player.is_top_down = true
	Global.player.global_position = Vector2(600, 400)
	
	add_child(Global.hud)
	
	#var player = player_scene.instantiate()
	#player.is_top_down = true
	#add_child(player)
	#player.global_position = Vector2(600, 400) 
	#
	#player.add_to_group("Player")
