extends Node

var player = null
var hud = null

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var player_scene = preload("res://player.tscn")
	player = player_scene.instantiate()
	
	print("Global player created (persistent)!")
	
	var hud_scene = preload("res://hud.tscn")
	hud = hud_scene.instantiate()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
