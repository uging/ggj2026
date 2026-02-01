extends Node2D
var player: Node2D = null

func _ready() -> void:
	print("Global _ready()")
	var path = "res://player.tscn"
	var player_scene = load(path)
	print("Player scene loaded: ", player_scene != null)
	if player_scene:
		player = player_scene.instantiate()
		print("Player instantiated: ", player)
		player.visible = false
	else:
		print("ERROR: ", path, " not found!")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
