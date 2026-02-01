extends Node2D
var player: Node2D = null

func _ready() -> void:
	print("The Tower!")
	#await get_tree().root.child_entered_tree  # Wait tree ready
	
	add_child(Global.player)
	Global.player.is_top_down = false
	Global.player.global_position = Vector2(700, 450) 
	
	add_child(Global.hud)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
