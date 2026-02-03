extends Node
var player: Node = null
var current_scene: Node = null

func _ready():
	current_scene = get_tree().root.get_child(-1)  # Last child is main scene

func goto_scene(path: String):
	call_deferred("_deferred_goto_scene", path)

func _deferred_goto_scene(path: String):
	if player and player.get_parent():
		player.get_parent().remove_child(player)
	
	current_scene.free()
	var s = load(path)
	current_scene = s.instantiate()
	get_tree().root.add_child(current_scene)

	if player:
		current_scene.add_child(player)
		player.global_position = Vector2(50, 50)
